# AI Coach - User Access Control Documentation

## Overview
This document verifies and documents the user access control implementation in the AI Coach application. All data access is properly scoped to ensure teachers can only view and manage their own recordings, analyses, and chat conversations.

## Backend Access Control

### Database Layer (Repository)

#### User-Scoped Queries
All repository methods that retrieve user data include `user_id` filtering:

**Recordings:**
```go
// backend/internal/repository/recording.go
func (r *RecordingRepository) GetRecordingsByUserID(ctx context.Context, userID uuid.UUID) ([]models.Recording, error)
func (r *RecordingRepository) GetRecordingByID(ctx context.Context, id uuid.UUID, userID uuid.UUID) (*models.Recording, error)
```

**Analyses:**
```go
// backend/internal/repository/analysis.go
func (r *AnalysisRepository) GetAnalysesByUserID(ctx context.Context, userID uuid.UUID) ([]models.Analysis, error)
func (r *AnalysisRepository) GetAnalysisByID(ctx context.Context, id uuid.UUID, userID uuid.UUID) (*models.Analysis, error)
```

**Progress:**
```go
// backend/internal/repository/progress.go
func (r *ProgressRepository) GetProgressByUserID(ctx context.Context, userID uuid.UUID) (*models.Progress, error)
```

**Chat:**
```go
// backend/internal/repository/chat.go
func (r *ChatRepository) GetChatMessagesByAnalysisID(ctx context.Context, analysisID uuid.UUID, userID uuid.UUID) ([]models.ChatMessage, error)
```

### Handler Layer (API Endpoints)

#### Authentication Middleware
All API endpoints require JWT authentication:
```go
// backend/internal/handlers/middleware.go
func AuthMiddleware() gin.HandlerFunc {
    // Validates JWT token
    // Extracts user_id from token
    // Sets user_id in context
}
```

#### User ID Extraction
Handlers extract the authenticated user ID from the request context:
```go
userID, exists := c.Get("user_id")
if !exists {
    c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
    return
}
```

#### Ownership Verification Examples

**Recording Access:**
```go
// backend/internal/handlers/recording.go
func (h *RecordingHandler) GetRecording(c *gin.Context) {
    userID := c.GetString("user_id")
    recordingID := c.Param("id")
    
    // Repository method includes user_id check
    recording, err := h.repo.GetRecordingByID(ctx, recordingID, userID)
    // Returns 404 if not found OR not owned by user
}
```

**Analysis Access:**
```go
// backend/internal/handlers/analysis.go
func (h *AnalysisHandler) GetAnalysis(c *gin.Context) {
    userID := c.GetString("user_id")
    analysisID := c.Param("id")
    
    // Repository method includes user_id check
    analysis, err := h.repo.GetAnalysisByID(ctx, analysisID, userID)
    // Returns 404 if not found OR not owned by user
}
```

**Chat Access:**
```go
// backend/internal/handlers/chat.go
func (h *ChatHandler) GetChatMessages(c *gin.Context) {
    userID := c.GetString("user_id")
    analysisID := c.Param("analysis_id")
    
    // First verify user owns the analysis
    analysis, err := h.analysisRepo.GetAnalysisByID(ctx, analysisID, userID)
    if err != nil {
        c.JSON(http.StatusNotFound, gin.H{"error": "Analysis not found"})
        return
    }
    
    // Then get chat messages
    messages, err := h.repo.GetChatMessagesByAnalysisID(ctx, analysisID, userID)
}
```

## Frontend Access Control

### Authentication State
The Flutter app maintains authentication state via `AuthProvider`:
```dart
// flutter_app/lib/data/providers/auth_provider.dart
class AuthProvider extends ChangeNotifier {
  String? _token;
  User? _user;
  
  Future<String?> getToken() async {
    // Returns JWT token for API requests
  }
}
```

### API Requests
All API requests include the JWT token in headers:
```dart
// flutter_app/lib/data/services/api_service.dart
Future<Response> get(String endpoint) async {
  final token = await _authProvider.getToken();
  return _dio.get(
    endpoint,
    options: Options(headers: {'Authorization': 'Bearer $token'}),
  );
}
```

### Data Providers
Flutter providers automatically filter data by authenticated user:
```dart
// flutter_app/lib/data/providers/recording_provider.dart
Future<void> loadRecordings() async {
  // Backend automatically filters by user_id from JWT
  final recordings = await _apiService.getRecordings();
  _recordings = recordings;
}
```

## Database Schema Constraints

### Foreign Key Relationships
All user data tables include `user_id` foreign keys:

```sql
CREATE TABLE recordings (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    -- other fields
);

CREATE TABLE analyses (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    recording_id UUID NOT NULL REFERENCES recordings(id) ON DELETE CASCADE,
    -- other fields
);

CREATE TABLE chat_messages (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    analysis_id UUID NOT NULL REFERENCES analyses(id) ON DELETE CASCADE,
    -- other fields
);
```

### Cascade Deletion
When a user is deleted, all associated data is automatically removed via `ON DELETE CASCADE`.

## Security Best Practices

### ✅ Implemented
1. **JWT Authentication**: All API endpoints require valid JWT tokens
2. **User ID Scoping**: All queries filter by authenticated user ID
3. **Ownership Verification**: Handlers verify user owns requested resources
4. **Repository Layer Isolation**: Database queries enforce user boundaries
5. **Cascade Deletion**: User data is properly cleaned up on account deletion
6. **No Direct ID Access**: Users cannot access resources by guessing IDs

### ✅ Verified Scenarios
1. **User A cannot view User B's recordings**
   - Repository query filters by `user_id`
   - Returns empty list or 404 for unauthorized access

2. **User A cannot view User B's analyses**
   - Repository query filters by `user_id`
   - Returns empty list or 404 for unauthorized access

3. **User A cannot access User B's chat conversations**
   - Chat handler verifies analysis ownership before returning messages
   - Returns 404 if analysis not owned by user

4. **Unauthenticated users cannot access any data**
   - Middleware rejects requests without valid JWT
   - Returns 401 Unauthorized

## Testing Recommendations

### Manual Testing
1. **Create two test accounts** (User A and User B)
2. **Create recordings as User A**
3. **Attempt to access User A's recordings as User B** (should fail)
4. **Verify User B only sees their own data**

### Automated Testing (Future)
```go
// Example test case
func TestUserCannotAccessOtherUsersRecordings(t *testing.T) {
    userA := createTestUser("userA@test.com")
    userB := createTestUser("userB@test.com")
    
    recordingA := createRecording(userA.ID)
    
    // User B attempts to access User A's recording
    _, err := repo.GetRecordingByID(ctx, recordingA.ID, userB.ID)
    
    assert.Error(t, err) // Should return error
    assert.Equal(t, "recording not found", err.Error())
}
```

## Conclusion

The AI Coach application implements comprehensive user access control at multiple layers:
- **Database Layer**: User-scoped queries
- **Handler Layer**: Ownership verification
- **Frontend Layer**: Authenticated API requests
- **Schema Layer**: Foreign key constraints

**All data access is properly isolated by user ID, ensuring teachers can only view and manage their own data.**

---

**Last Updated:** 2026-02-09
**Verified By:** Implementation review and code analysis
