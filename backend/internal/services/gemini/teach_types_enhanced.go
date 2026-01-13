// teach_types_enhanced.go
package gemini

// Enhanced structures to capture all the detail from analysis

// TimeOnLearningSnapshot with evidence
// TimeOnLearningSnapshot with evidence
type TimeOnLearningSnapshot struct {
	TeacherActivity interface{} `json:"teacher_activity"` // Can be bool or string "N/A"
	StudentsOnTask  interface{} `json:"students_on_task"` // Can be string "H"/"M"/"L" or "N/A"
	Evidence        string      `json:"evidence"`
}

// BehaviorRating with detailed evidence
type BehaviorRating struct {
	Rating         string   `json:"rating"`
	Evidence       string   `json:"evidence"`
	Count          *int     `json:"count,omitempty"`           // For countable behaviors
	InstancesFound []string `json:"instances_found,omitempty"` // Specific quotes
	Limitations    string   `json:"limitations,omitempty"`     // What couldn't be assessed
	SubBehaviors   map[string]string `json:"sub_behaviors,omitempty"` // For 1.4a, 1.4b
}

// ElementAnalysis with limitations
type ElementAnalysis struct {
	Score           int                       `json:"score"`
	Behaviors       map[string]BehaviorRating `json:"behaviors"`
	Rationale       string                    `json:"rationale"`
	LimitationsNoted string                   `json:"limitations_noted,omitempty"`
}

// ConfidenceFactors for transparency
type ConfidenceFactors struct {
	AudioQuality         string   `json:"audio_quality"`
	RecordingLength      string   `json:"recording_length"`
	EvidenceCompleteness string   `json:"evidence_completeness"`
	Limitations          []string `json:"limitations"`
}

// TranscriptionSegment represents a segment of transcribed audio
type TranscriptionSegment struct {
	Start   float64 `json:"start"`
	End     float64 `json:"end"`
	Speaker string  `json:"speaker"`
	Text    string  `json:"text"`
}

// TranscriptionResult contains the full transcription
type TranscriptionResult struct {
	FullText         string                 `json:"full_text"`
	Segments         []TranscriptionSegment `json:"segments"`
	LanguageDetected string                 `json:"language_detected"`
	DurationSeconds  float64                `json:"duration_seconds"`
}

// TimeOnLearning contains all 3 snapshots
type TimeOnLearning struct {
	Snapshot4Min  TimeOnLearningSnapshot `json:"snapshot_4min"`
	Snapshot9Min  TimeOnLearningSnapshot `json:"snapshot_9min"`
	Snapshot14Min TimeOnLearningSnapshot `json:"snapshot_14min"`
}

// Recommendation represents an actionable recommendation
type Recommendation struct {
	Title       string `json:"title"`
	Description string `json:"description"`
	Example     string `json:"example"`
}

// QualitativeFeedback contains summary and recommendations
type QualitativeFeedback struct {
	Summary             string           `json:"summary"`
	Strengths           []string         `json:"strengths"`
	AreasForImprovement []string         `json:"areas_for_improvement"`
	Recommendations     []Recommendation `json:"recommendations"`
}

// TEACHAnalysisResult with all enhancements
type TEACHAnalysisResult struct {
	Transcription       TranscriptionResult        `json:"transcription"`
	TimeOnLearning      TimeOnLearning             `json:"time_on_learning"`
	Elements            map[string]ElementAnalysis `json:"elements"`
	QualitativeFeedback QualitativeFeedback        `json:"qualitative_feedback"`
	OverallScore        float64                    `json:"overall_score"`
	Confidence          float64                    `json:"confidence"`
	ConfidenceFactors   ConfidenceFactors          `json:"confidence_factors"`
}