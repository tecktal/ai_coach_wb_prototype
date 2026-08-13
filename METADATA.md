# AI Coach - Metadata Collection Documentation

## Overview
This document details all metadata collected by the AI Coach application, including what data is collected, why it's collected, how it's used, and where it's stored.

## User Data

### User Profile
**Fields Collected:**
- `id` (UUID): Unique identifier for the user
- `email` (string): User's email address for authentication
- `name` (string): User's full name
- `created_at` (timestamp): Account creation date
- `updated_at` (timestamp): Last profile update date

**Purpose:**
- Authentication and authorization
- Personalized user experience
- User-scoped data access control

**Storage:** PostgreSQL database, `users` table

---

## Recording Metadata

### Recording Information
**Fields Collected:**
- `id` (UUID): Unique identifier for the recording
- `user_id` (UUID): Foreign key linking to the user who created the recording
- `title` (string, optional): User-provided title for the lesson
- `file_url` (string): S3 storage path for the audio file
- `file_size` (integer): Size of the audio file in bytes
- `duration_seconds` (integer, optional): Length of the recording in seconds
- `status` (enum): Processing status (`pending`, `processing`, `completed`, `failed`)
- `created_at` (timestamp): When the recording was uploaded
- `updated_at` (timestamp): Last status update

**Purpose:**
- Track lesson recordings for analysis
- Manage audio file storage and retrieval
- Monitor processing pipeline status
- Enable user to review their lesson history

**Storage:**
- Metadata: PostgreSQL database, `recordings` table
- Audio files: AWS S3 bucket (or local storage in development)

---

## Analysis Metadata

### Analysis Results
**Fields Collected:**
- `id` (UUID): Unique identifier for the analysis
- `recording_id` (UUID): Foreign key linking to the analyzed recording
- `user_id` (UUID): Foreign key linking to the user (for access control)
- `overall_score` (float): Overall TEACH framework score (0-5)
- `confidence` (float): AI confidence level in the analysis (0-1)
- `processing_time_ms` (integer): Time taken to complete analysis
- `created_at` (timestamp): When the analysis was completed
- `updated_at` (timestamp): Last update to the analysis

**Detailed Analysis Data (JSON):**
- **Time on Learning**: Snapshots at 4min, 9min, 14min intervals
  - Teacher activity status
  - Student on-task rating
  - Evidence quotes with timestamps
  
- **TEACH Elements** (9 elements):
  - Element scores (1-5 or 0 for N/A)
  - Behavior ratings (H/M/L/N/A)
  - Evidence quotes
  - Rationale for scores
  
- **Science of Learning**:
  - Clarity and Cognitive Load analysis
  - Engagement and Retrieval Practice analysis
  - Feedback and Metacognition analysis
  
- **Qualitative Feedback**:
  - Summary
  - Strengths (list)
  - Areas for improvement (list)
  - Recommendations (list with titles, descriptions, examples)

**Purpose:**
- Provide actionable feedback to teachers
- Track teaching quality over time
- Enable progress monitoring
- Support coaching conversations

**Storage:** PostgreSQL database, `analyses` table (with JSONB fields for detailed data)

---

## Chat Metadata

### Coaching Conversations
**Fields Collected:**
- `id` (UUID): Unique identifier for the chat message
- `analysis_id` (UUID): Foreign key linking to the related analysis
- `user_id` (UUID): Foreign key linking to the user
- `role` (enum): Message sender (`user` or `assistant`)
- `content` (text): Message content
- `created_at` (timestamp): When the message was sent

**Purpose:**
- Enable AI coaching conversations
- Provide context-aware support
- Track user engagement with feedback

**Storage:** PostgreSQL database, `chat_messages` table

---

## Progress Tracking Metadata

### User Progress
**Fields Collected:**
- `user_id` (UUID): User identifier
- `total_recordings` (integer): Total number of recordings
- `total_analyses` (integer): Total number of completed analyses
- `average_score` (float): Average overall TEACH score
- `latest_score` (float): Most recent overall score
- `score_trend` (string): Trend indicator (`improving`, `stable`, `declining`)

**Purpose:**
- Show teacher progress over time
- Motivate continued use
- Identify areas needing support

**Storage:** Computed dynamically from `recordings` and `analyses` tables

---

## Technical Metadata

### System Logs
**Fields Collected:**
- Request timestamps
- Error messages
- Processing status updates
- API call durations

**Purpose:**
- Debugging and troubleshooting
- Performance monitoring
- System reliability

**Storage:** Application logs (not persisted in database)

---

## Data Privacy & Security

### Access Control
- **User Isolation**: All queries are scoped by `user_id` to ensure teachers only see their own data
- **Authentication**: JWT tokens required for all API requests
- **Authorization**: Backend verifies user ownership before returning data

### Data Retention
- **Recordings**: Retained indefinitely unless user deletes
- **Analyses**: Retained indefinitely unless user deletes
- **Chat History**: Retained indefinitely unless user deletes

### Data Deletion
Users can delete:
- Individual recordings (cascades to associated analyses)
- Individual analyses
- Chat conversations

---

## Third-Party Services

### Google Drive (Optional)
**Data Shared:**
- Audio file uploads (if user chooses to back up to Drive)
- File metadata (name, size, type)

**Purpose:**
- Optional cloud backup
- Cross-device access

### Google Gemini API
**Data Shared:**
- Audio file content (for analysis)
- No personally identifiable information

**Purpose:**
- AI-powered lesson analysis
- Coaching conversation generation

**Note:** Audio is sent via inline data and is not stored by Google beyond the API call duration.

---

## Future Considerations

### Planned Metadata (Not Yet Implemented)
- **Transcription Data**: Full text transcription of lessons (currently disabled due to API token limits)
- **School/District Information**: For institutional deployments
- **Student Count**: Number of students in the class
- **Grade Level**: Grade being taught
- **Subject Area**: Subject of the lesson

---

## Questions or Concerns
For questions about data collection, privacy, or security, please contact the development team.

**Last Updated:** 2026-02-09
