package googledrive

import (
	"context"
	"fmt"
	"io"

	"google.golang.org/api/drive/v3"
	"google.golang.org/api/option"
)

type DriveService struct {
	service  *drive.Service
	folderID string
}

func NewDriveService(jsonKeyPath string, folderID string) (*DriveService, error) {
	ctx := context.Background()

	// Authenticate with the service account
	// We need 'drive.DriveFileScope' for uploading files
	srv, err := drive.NewService(ctx, option.WithCredentialsFile(jsonKeyPath), option.WithScopes(drive.DriveFileScope))
	if err != nil {
		return nil, fmt.Errorf("unable to retrieve Drive client: %v", err)
	}

	return &DriveService{
		service:  srv,
		folderID: folderID,
	}, nil
}

// UploadFile uploads a file to Google Drive
// filename: the name the file will have in Drive
// content: the file content
// mimeType: the MIME type of the file (e.g., "audio/mp3")
// parentID: optional parent folder ID (empty string uses default configured folder)
// Returns: (webViewLink, error)
func (s *DriveService) UploadFile(ctx context.Context, content io.Reader, filename string, mimeType string, parentID string) (string, error) {
	// Use the configured folderID if no parent is specified
	if parentID == "" {
		parentID = s.folderID
	}

	// Create the file metadata
	f := &drive.File{
		Name:     filename,
		Parents:  []string{parentID}, // Parent folder ID
		MimeType: mimeType,
	}

	// Do the upload
	res, err := s.service.Files.Create(f).Media(content).Context(ctx).SupportsAllDrives(true).Do()
	if err != nil {
		return "", fmt.Errorf("unable to create file in drive: %v", err)
	}

	return res.WebViewLink, nil
}

// CreateFolder creates a new folder in Google Drive
// name: the name of the folder
// parentID: the parent folder ID (use empty string for root)
// Returns: (folderID, error)
func (s *DriveService) CreateFolder(ctx context.Context, name string, parentID string) (string, error) {
	// Use the configured folderID if no parent is specified
	if parentID == "" {
		parentID = s.folderID
	}

	folderMetadata := &drive.File{
		Name:     name,
		MimeType: "application/vnd.google-apps.folder",
		Parents:  []string{parentID},
	}

	folder, err := s.service.Files.Create(folderMetadata).Context(ctx).SupportsAllDrives(true).Do()
	if err != nil {
		return "", fmt.Errorf("unable to create folder in drive: %v", err)
	}

	return folder.Id, nil
}
