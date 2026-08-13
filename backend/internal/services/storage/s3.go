package storage

import (
	"context"
	"fmt"
	"io"
	"log"
	"path/filepath"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/google/uuid"
)

type S3Service struct {
	client *s3.Client
	bucket string
}

func NewS3Service(endpoint, bucket, accessKey, secretKey, region string, useSSL bool) (*S3Service, error) {
	ctx := context.Background()

	// Create custom endpoint resolver
	customResolver := aws.EndpointResolverWithOptionsFunc(func(service, region string, options ...interface{}) (aws.Endpoint, error) {
		if service == s3.ServiceID {
			protocol := "http"
			if useSSL {
				protocol = "https"
			}
			return aws.Endpoint{
				URL:               fmt.Sprintf("%s://%s", protocol, endpoint),
				HostnameImmutable: true,
			}, nil
		}
		return aws.Endpoint{}, fmt.Errorf("unknown endpoint requested")
	})

	// Load AWS config with custom credentials
	cfg, err := config.LoadDefaultConfig(ctx,
		config.WithRegion(region),
		config.WithEndpointResolverWithOptions(customResolver),
		config.WithCredentialsProvider(credentials.NewStaticCredentialsProvider(accessKey, secretKey, "")),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to load AWS config: %w", err)
	}

	// Create S3 client
	client := s3.NewFromConfig(cfg, func(o *s3.Options) {
		o.UsePathStyle = true // Required for MinIO
	})

	service := &S3Service{
		client: client,
		bucket: bucket,
	}

	// Ensure bucket exists
	if err := service.ensureBucket(ctx); err != nil {
		return nil, err
	}

	log.Printf("S3 service initialized with bucket: %s", bucket)

	return service, nil
}

func (s *S3Service) ensureBucket(ctx context.Context) error {
	// Check if bucket exists
	_, err := s.client.HeadBucket(ctx, &s3.HeadBucketInput{
		Bucket: aws.String(s.bucket),
	})
	if err == nil {
		return nil // Bucket exists
	}

	// Create bucket
	_, err = s.client.CreateBucket(ctx, &s3.CreateBucketInput{
		Bucket: aws.String(s.bucket),
	})
	if err != nil {
		return fmt.Errorf("failed to create bucket: %w", err)
	}

	log.Printf("Created S3 bucket: %s", s.bucket)
	return nil
}

// UploadFile uploads a file to S3 and returns the file URL
func (s *S3Service) UploadFile(ctx context.Context, file io.Reader, filename string, contentType string) (string, error) {
	// Generate unique key
	ext := filepath.Ext(filename)
	key := fmt.Sprintf("recordings/%s/%s%s", time.Now().Format("2006/01/02"), uuid.New().String(), ext)

	// Upload file
	_, err := s.client.PutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(s.bucket),
		Key:         aws.String(key),
		Body:        file,
		ContentType: aws.String(contentType),
	})
	if err != nil {
		return "", fmt.Errorf("failed to upload file: %w", err)
	}

	log.Printf("Uploaded file to S3: %s", key)

	return key, nil
}

// GetPresignedURL generates a presigned URL for downloading a file
func (s *S3Service) GetPresignedURL(ctx context.Context, key string, expiration time.Duration) (string, error) {
	presignClient := s3.NewPresignClient(s.client)

	req, err := presignClient.PresignGetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(key),
	}, func(opts *s3.PresignOptions) {
		opts.Expires = expiration
	})
	if err != nil {
		return "", fmt.Errorf("failed to generate presigned URL: %w", err)
	}

	return req.URL, nil
}

// DownloadFile downloads a file from S3 to a local path
func (s *S3Service) DownloadFile(ctx context.Context, key string, localPath string) error {
	result, err := s.client.GetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return fmt.Errorf("failed to download file: %w", err)
	}
	defer result.Body.Close()

	// This is a simplified version - in production, you'd write to a file
	// For now, we'll just read the body to ensure it works
	_, err = io.ReadAll(result.Body)
	if err != nil {
		return fmt.Errorf("failed to read file body: %w", err)
	}

	return nil
}

// GetFileStream returns a reader for the file content along with its content
// type, content length, and (for ranged requests) the S3 Content-Range header.
// The caller must forward Content-Range on a 206 response — browsers reject a
// 206 that lacks it, which breaks <audio>/<video> playback.
func (s *S3Service) GetFileStream(ctx context.Context, key string, rangeHeader string) (io.ReadCloser, string, int64, string, error) {
	input := &s3.GetObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(key),
	}

	if rangeHeader != "" {
		input.Range = aws.String(rangeHeader)
	}

	result, err := s.client.GetObject(ctx, input)
	if err != nil {
		return nil, "", 0, "", fmt.Errorf("failed to get file stream: %w", err)
	}

	contentType := "application/octet-stream"
	if result.ContentType != nil {
		contentType = *result.ContentType
	}

	contentLength := int64(0)
	if result.ContentLength != nil {
		contentLength = *result.ContentLength
	}

	contentRange := ""
	if result.ContentRange != nil {
		contentRange = *result.ContentRange
	}

	return result.Body, contentType, contentLength, contentRange, nil
}

// DeleteFile deletes a file from S3
func (s *S3Service) DeleteFile(ctx context.Context, key string) error {
	_, err := s.client.DeleteObject(ctx, &s3.DeleteObjectInput{
		Bucket: aws.String(s.bucket),
		Key:    aws.String(key),
	})
	if err != nil {
		return fmt.Errorf("failed to delete file: %w", err)
	}

	log.Printf("Deleted file from S3: %s", key)

	return nil
}

// GetFileURL returns the public URL for a file (for internal use)
func (s *S3Service) GetFileURL(key string) string {
	return fmt.Sprintf("s3://%s/%s", s.bucket, key)
}
