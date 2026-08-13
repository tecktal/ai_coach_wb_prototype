// teach_types_enhanced.go
package gemini

import "strings"

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
	Rating         string            `json:"rating"`
	Evidence       string            `json:"evidence"`
	Count          *int              `json:"count,omitempty"`           // For countable behaviors
	InstancesFound []string          `json:"instances_found,omitempty"` // Specific quotes
	Limitations    string            `json:"limitations,omitempty"`     // What couldn't be assessed
	SubBehaviors   map[string]string `json:"sub_behaviors,omitempty"`   // For 1.4a, 1.4b
}

// ElementAnalysis with limitations
type ElementAnalysis struct {
	Score            int                       `json:"score"`
	Behaviors        map[string]BehaviorRating `json:"behaviors"`
	Rationale        string                    `json:"rationale"`
	LimitationsNoted string                    `json:"limitations_noted,omitempty"`
}

// ---------------------------------------------------------------------------
// Feedback audience
// ---------------------------------------------------------------------------

// Who the generated feedback is written for. This changes the voice only — the
// scoring, evidence and framework analysis are identical either way.
const (
	// AudienceTeacher addresses the teacher directly ("You used clear
	// language..."). The original behaviour and the default.
	AudienceTeacher = "teacher"

	// AudienceCoordinator writes about the teacher in the third person, for a
	// pedagogy coach who reads it to lead a conversation with her. Requested by
	// the Mato Grosso (Brazil) TEACH coordinators.
	AudienceCoordinator = "coordinator"
)

// NormalizeAudience maps a stored value onto a known audience, falling back to
// AudienceTeacher. Unknown values must never reach a prompt.
func NormalizeAudience(audience string) string {
	if audience == AudienceCoordinator {
		return AudienceCoordinator
	}
	return AudienceTeacher
}

// ---------------------------------------------------------------------------
// Element key resolution
// ---------------------------------------------------------------------------

// CanonicalElements is the authoritative naming and ordering of the nine TEACH
// elements. These names match the `analyses` table columns, the Excel exporter
// (services/exporter/excel.go) and the monitoring dashboard (src/lib/teach.ts),
// so they are the names everything else in the system already agrees on.
var CanonicalElements = []string{
	"supportive_environment",
	"positive_expectations",
	"lesson_facilitation",
	"checks_understanding",
	"feedback",
	"critical_thinking",
	"autonomy",
	"perseverance",
	"social_collaborative",
}

// elementAliases maps key variants the model has been observed to emit onto the
// canonical key. The prompt asks for canonical names, but the model does not
// reliably echo them — a silent mismatch here previously caused three of the
// nine elements to be dropped on every analysis, so this stays as a safety net.
var elementAliases = map[string]string{
	"positive_behavioral_expectations":  "positive_expectations",
	"positive_behavioural_expectations": "positive_expectations",
	"behavioral_expectations":           "positive_expectations",
	"checks_for_understanding":          "checks_understanding",
	"check_for_understanding":           "checks_understanding",
	"checking_for_understanding":        "checks_understanding",
	"social_collaborative_skills":       "social_collaborative",
	"social_and_collaborative_skills":   "social_collaborative",
	"social_and_collaborative":          "social_collaborative",
}

// normalizeElementKey lowercases and strips separators so that cosmetic
// variations ("Checks Understanding", "checks-understanding") compare equal.
// It deliberately does not do fuzzy or partial matching: over-matching would
// reintroduce the same class of silent wrong answer this function exists to
// prevent.
func normalizeElementKey(key string) string {
	var b strings.Builder
	for _, r := range strings.ToLower(key) {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
		}
	}
	return b.String()
}

// ResolveElement looks up one canonical element in the model's `elements` map,
// accepting known aliases and cosmetic key variations.
//
// found=false means the model omitted the element entirely. Callers must treat
// that as "not scored" (NULL) — never as a score — and should log it, because a
// miss means either the model drifted from the requested schema or a new alias
// needs adding here.
func ResolveElement(elements map[string]ElementAnalysis, canonical string) (ElementAnalysis, bool) {
	if len(elements) == 0 {
		return ElementAnalysis{}, false
	}

	// 1. Exact match on the canonical key.
	if el, ok := elements[canonical]; ok {
		return el, true
	}

	// 2. Exact match on a known alias.
	for alias, target := range elementAliases {
		if target != canonical {
			continue
		}
		if el, ok := elements[alias]; ok {
			return el, true
		}
	}

	// 3. Normalized comparison, against both the canonical key and its aliases.
	wanted := map[string]bool{normalizeElementKey(canonical): true}
	for alias, target := range elementAliases {
		if target == canonical {
			wanted[normalizeElementKey(alias)] = true
		}
	}
	for key, el := range elements {
		if wanted[normalizeElementKey(key)] {
			return el, true
		}
	}

	return ElementAnalysis{}, false
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

// ScienceOfLearningArea represents one of the 3 areas
type ScienceOfLearningArea struct {
	Pros     string `json:"pros"`
	Cons     string `json:"cons"`
	Feedback string `json:"feedback"`
}

// ScienceOfLearning holds the coaching section, keyed by area.
//
// A map rather than named fields because which areas get generated is
// per-deployment configuration — see programme.go. The default three keys
// produce byte-identical JSON to the previous struct, so stored analyses and
// every consumer are unaffected.
type ScienceOfLearning map[string]ScienceOfLearningArea

// QualitativeFeedback contains summary and recommendations
type QualitativeFeedback struct {
	Summary             string           `json:"summary"`
	Strengths           []string         `json:"strengths"`
	AreasForImprovement []string         `json:"areas_for_improvement"`
	Recommendations     []Recommendation `json:"recommendations"`
}

// ContentWarning is included in a successful analysis when the audio had
// limited content. The analysis proceeds but scores may be incomplete.
type ContentWarning struct {
	// Type is one of: "too_short" | "limited_teaching" | "poor_audio"
	Type            string `json:"type"`
	Message         string `json:"message"`
	DetectedSeconds int    `json:"detected_seconds,omitempty"`
}

// TEACHAnalysisResult with all enhancements (transcription removed to save tokens)
type TEACHAnalysisResult struct {
	// Hard-failure fields — set ONLY when audio is completely unusable.
	// When these are set the analysis stops and no other fields are populated.
	Error            string `json:"error,omitempty"`
	Message          string `json:"message,omitempty"`
	DetectedDuration int    `json:"detected_duration,omitempty"`

	// Soft-warning — set when analysis proceeds but content was limited.
	// The full analysis is still present; scores reflect what was observable.
	ContentWarning *ContentWarning `json:"content_warning,omitempty"`

	TimeOnLearning      TimeOnLearning             `json:"time_on_learning"`
	Elements            map[string]ElementAnalysis `json:"elements"`
	QualitativeFeedback QualitativeFeedback        `json:"qualitative_feedback"`
	OverallScore        float64                    `json:"overall_score"`
	Confidence          float64                    `json:"confidence"`
	ConfidenceFactors   ConfidenceFactors          `json:"confidence_factors"`
	ScienceOfLearning   ScienceOfLearning          `json:"science_of_learning"`
}
