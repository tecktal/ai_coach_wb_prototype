# AI Teaching Coach - Testing Guide

## Quick Start

### 1. Start the Backend

```powershell
# Navigate to project directory
cd "c:\Users\HP\OneDrive\Documents\2- Surviving Tecktal\ai_coach"

# Start all services
.\start.ps1

# Or manually with docker-compose
docker-compose up -d
```

### 2. Verify Services are Running

```powershell
# Check service status
docker-compose ps

# Expected output:
# NAME                STATUS              PORTS
# ai_coach_backend_1  Up (healthy)        0.0.0.0:8080->8080/tcp
# ai_coach_db_1       Up (healthy)        0.0.0.0:5432->5432/tcp
# ai_coach_minio_1    Up (healthy)        0.0.0.0:9000-9001->9000-9001/tcp
```

### 3. Test API Health

Open browser or use curl:
```
http://localhost:8080/api/v1/health
```

Expected response:
```json
{
  "status": "healthy",
  "time": "2026-01-11T11:48:32Z"
}
```

## API Testing with PowerShell

### Test 1: User Registration

```powershell
$registerData = @{
    email = "teacher@test.com"
    password = "SecurePass123"
    first_name = "Jane"
    last_name = "Smith"
    school_name = "Demo Elementary School"
    country = "United States"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/auth/register" `
    -Method Post `
    -ContentType "application/json" `
    -Body $registerData

# Save the token
$token = $response.token
Write-Host "✅ User registered successfully!"
Write-Host "Token: $token"
Write-Host "User ID: $($response.user.id)"
```

### Test 2: User Login

```powershell
$loginData = @{
    email = "teacher@test.com"
    password = "SecurePass123"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/auth/login" `
    -Method Post `
    -ContentType "application/json" `
    -Body $loginData

$token = $response.token
Write-Host "✅ Login successful!"
Write-Host "Token: $token"
```

### Test 3: Get User Profile

```powershell
$headers = @{
    Authorization = "Bearer $token"
}

$response = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/auth/me" `
    -Method Get `
    -Headers $headers

Write-Host "✅ Profile retrieved!"
Write-Host "Name: $($response.first_name) $($response.last_name)"
Write-Host "Email: $($response.email)"
Write-Host "School: $($response.school_name)"
```

### Test 4: Upload Audio Recording

```powershell
# Create a test audio file (you'll need a real audio file)
# For this example, assume you have a file at: C:\temp\test_lesson.mp3

$audioPath = "C:\temp\test_lesson.mp3"

# Check if file exists
if (Test-Path $audioPath) {
    $headers = @{
        Authorization = "Bearer $token"
    }
    
    $form = @{
        audio = Get-Item -Path $audioPath
        title = "Math Lesson - Fractions"
        description = "Teaching fractions to 3rd grade"
        subject = "Mathematics"
        grade_level = "3rd Grade"
        language = "en"
    }
    
    $response = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/recordings" `
        -Method Post `
        -Headers $headers `
        -Form $form
    
    $recordingId = $response.id
    Write-Host "✅ Recording uploaded!"
    Write-Host "Recording ID: $recordingId"
} else {
    Write-Host "⚠️  Audio file not found at: $audioPath"
    Write-Host "Please create a test audio file first"
}
```

### Test 5: Trigger Analysis

```powershell
$headers = @{
    Authorization = "Bearer $token"
}

$response = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/recordings/$recordingId/analyze" `
    -Method Post `
    -Headers $headers

Write-Host "✅ Analysis started!"
Write-Host "Analysis ID: $($response.id)"
Write-Host "Overall Score: $($response.overall_score)"
Write-Host ""
Write-Host "Element Scores:"
Write-Host "  Supportive Environment: $($response.supportive_environment_score)/5"
Write-Host "  Positive Expectations: $($response.positive_expectations_score)/5"
Write-Host "  Lesson Facilitation: $($response.lesson_facilitation_score)/5"
Write-Host "  Checks Understanding: $($response.checks_understanding_score)/5"
Write-Host "  Feedback: $($response.feedback_score)/5"
Write-Host "  Critical Thinking: $($response.critical_thinking_score)/5"
Write-Host "  Autonomy: $($response.autonomy_score)/5"
Write-Host "  Perseverance: $($response.perseverance_score)/5"
Write-Host "  Social & Collaborative: $($response.social_collaborative_score)/5"
```

### Test 6: Create Chat Session

```powershell
$headers = @{
    Authorization = "Bearer $token"
}

$chatData = @{
    analysis_id = $response.id
} | ConvertTo-Json

$chatSession = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/chat/sessions" `
    -Method Post `
    -Headers $headers `
    -ContentType "application/json" `
    -Body $chatData

$sessionId = $chatSession.id
Write-Host "✅ Chat session created!"
Write-Host "Session ID: $sessionId"
```

### Test 7: Send Chat Message

```powershell
$headers = @{
    Authorization = "Bearer $token"
}

$messageData = @{
    content = "What are some specific ways I can improve critical thinking in my lessons?"
} | ConvertTo-Json

$response = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/chat/sessions/$sessionId/messages" `
    -Method Post `
    -Headers $headers `
    -ContentType "application/json" `
    -Body $messageData

Write-Host "✅ Message sent!"
Write-Host ""
Write-Host "You: $($response.user_message.content)"
Write-Host ""
Write-Host "AI Coach: $($response.assistant_message.content)"
```

### Test 8: Get Progress Trends

```powershell
$headers = @{
    Authorization = "Bearer $token"
}

$response = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/progress/trends" `
    -Method Get `
    -Headers $headers

Write-Host "✅ Progress retrieved!"
Write-Host "Total Analyses: $($response.total_analyses)"
Write-Host ""
Write-Host "Trend Data:"
foreach ($trend in $response.trends) {
    Write-Host "  Date: $($trend.date)"
    Write-Host "  Overall Score: $($trend.overall_score)"
}
```

## Database Inspection

### Connect to PostgreSQL

```powershell
# Connect to database
docker-compose exec db psql -U postgres -d ai_coach
```

### Useful SQL Queries

```sql
-- View all users
SELECT id, email, first_name, last_name, school_name FROM users;

-- View all recordings
SELECT id, title, status, created_at FROM recordings;

-- View all analyses with scores
SELECT 
    id, 
    recording_id, 
    overall_score,
    supportive_environment_score,
    critical_thinking_score,
    created_at 
FROM analyses;

-- View chat messages
SELECT 
    cm.role, 
    cm.content, 
    cm.created_at 
FROM chat_messages cm
JOIN chat_sessions cs ON cm.session_id = cs.id
ORDER BY cm.created_at;

-- Exit
\q
```

## MinIO (S3) Inspection

1. Open browser: http://localhost:9001
2. Login: `minioadmin` / `minioadmin`
3. Navigate to bucket: `ai-coach-recordings`
4. View uploaded audio files

## Troubleshooting

### Services Won't Start

```powershell
# Stop all services
docker-compose down

# Remove volumes (WARNING: deletes all data)
docker-compose down -v

# Rebuild and start
docker-compose up -d --build
```

### View Logs

```powershell
# All services
docker-compose logs

# Specific service
docker-compose logs backend
docker-compose logs db
docker-compose logs minio

# Follow logs (live)
docker-compose logs -f backend
```

### Backend Connection Errors

1. Check if backend is running:
   ```powershell
   docker-compose ps backend
   ```

2. Check backend logs:
   ```powershell
   docker-compose logs backend
   ```

3. Verify environment variables:
   ```powershell
   docker-compose exec backend env | grep GEMINI
   ```

### Database Connection Errors

1. Check if database is healthy:
   ```powershell
   docker-compose ps db
   ```

2. Test connection:
   ```powershell
   docker-compose exec db pg_isready -U postgres
   ```

### Gemini API Errors

1. Verify API key is set:
   ```powershell
   # Check in docker-compose.yml
   # Should be: GEMINI_API_KEY=your-gemini-api-key-here
   ```

2. Check Gemini API quota:
   - Visit: https://aistudio.google.com/
   - Check rate limits and usage

### Audio Upload Errors

1. Verify file format is supported:
   - WAV, MP3, M4A, AAC, OGG, FLAC

2. Check file size (should be reasonable for ~15 min audio)

3. Verify MinIO is running:
   ```powershell
   docker-compose ps minio
   ```

## Complete Test Script

Save this as `test-api.ps1`:

```powershell
# Complete API Test Script
Write-Host "🧪 AI Teaching Coach - API Testing" -ForegroundColor Cyan
Write-Host ""

# 1. Health Check
Write-Host "1️⃣  Testing Health Endpoint..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/health"
    Write-Host "   ✅ Backend is healthy!" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Backend is not responding!" -ForegroundColor Red
    exit 1
}

# 2. Register User
Write-Host "2️⃣  Registering Test User..." -ForegroundColor Yellow
$registerData = @{
    email = "test_$(Get-Random)@example.com"
    password = "TestPass123"
    first_name = "Test"
    last_name = "Teacher"
    school_name = "Test School"
    country = "USA"
} | ConvertTo-Json

try {
    $response = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/auth/register" `
        -Method Post `
        -ContentType "application/json" `
        -Body $registerData
    
    $token = $response.token
    $userId = $response.user.id
    Write-Host "   ✅ User registered! ID: $userId" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Registration failed: $_" -ForegroundColor Red
    exit 1
}

# 3. Get Profile
Write-Host "3️⃣  Getting User Profile..." -ForegroundColor Yellow
$headers = @{ Authorization = "Bearer $token" }

try {
    $profile = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/auth/me" `
        -Method Get `
        -Headers $headers
    
    Write-Host "   ✅ Profile retrieved: $($profile.first_name) $($profile.last_name)" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Profile retrieval failed: $_" -ForegroundColor Red
}

# 4. List Recordings (should be empty)
Write-Host "4️⃣  Listing Recordings..." -ForegroundColor Yellow
try {
    $recordings = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/recordings" `
        -Method Get `
        -Headers $headers
    
    Write-Host "   ✅ Found $($recordings.Count) recordings" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Failed to list recordings: $_" -ForegroundColor Red
}

# 5. Get Progress
Write-Host "5️⃣  Getting Progress..." -ForegroundColor Yellow
try {
    $progress = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/progress" `
        -Method Get `
        -Headers $headers
    
    Write-Host "   ✅ Progress retrieved: $($progress.total_recordings) total recordings" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Failed to get progress: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "✨ All tests completed!" -ForegroundColor Cyan
Write-Host ""
Write-Host "📝 Next Steps:" -ForegroundColor Yellow
Write-Host "   1. Upload an audio file to test analysis"
Write-Host "   2. Trigger TEACH analysis"
Write-Host "   3. Test chat functionality"
Write-Host "   4. Build Flutter app to test full flow"
```

Run with:
```powershell
.\test-api.ps1
```

## Performance Testing

### Test Analysis Speed

```powershell
# Measure time for analysis
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# Trigger analysis (use your recording ID)
$response = Invoke-RestMethod -Uri "http://localhost:8080/api/v1/recordings/$recordingId/analyze" `
    -Method Post `
    -Headers @{ Authorization = "Bearer $token" }

$stopwatch.Stop()
Write-Host "Analysis completed in: $($stopwatch.Elapsed.TotalSeconds) seconds"
```

## Security Testing

### Test Invalid Token

```powershell
$headers = @{ Authorization = "Bearer invalid-token" }

try {
    Invoke-RestMethod -Uri "http://localhost:8080/api/v1/auth/me" `
        -Method Get `
        -Headers $headers
} catch {
    Write-Host "✅ Correctly rejected invalid token" -ForegroundColor Green
}
```

### Test Unauthorized Access

```powershell
# Try to access protected endpoint without token
try {
    Invoke-RestMethod -Uri "http://localhost:8080/api/v1/recordings" `
        -Method Get
} catch {
    Write-Host "✅ Correctly requires authentication" -ForegroundColor Green
}
```

## Cleanup

### Stop Services

```powershell
docker-compose down
```

### Remove All Data

```powershell
# WARNING: This deletes all data!
docker-compose down -v
```

### Remove Docker Images

```powershell
docker-compose down --rmi all -v
```

---

**Ready to test!** Start with the Quick Start section and work through the API tests.
