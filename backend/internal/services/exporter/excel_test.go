package exporter

import (
	"strings"
	"testing"

	"github.com/worldbank/ai-coach/backend/internal/models"
	"github.com/xuri/excelize/v2"
)

func strPtr(s string) *string { return &s }
func intPtr(i int) *int       { return &i }

func testUser(country string) *models.User {
	return &models.User{
		FirstName: "Birhanu",
		LastName:  "Mamo",
		Country:   strPtr(country),
	}
}

func testRecording() *models.Recording {
	return &models.Recording{
		Title:      strPtr("Transitive and intransitive verbs"),
		Subject:    strPtr("English"),
		GradeLevel: strPtr("10E"),
	}
}

// marker builds a per-area probe string for one field.
//
// Spaces, not underscores: the export runs text through stripMarkdown, which
// treats _like this_ as markdown italics and removes the underscores. Real
// prose is unaffected, but underscore-laden test data would be mangled and the
// assertions would fail for the wrong reason.
func marker(field, key string) string {
	return field + " " + strings.ReplaceAll(key, "_", " ")
}

// analysisWithSOL builds an analysis whose science_of_learning carries the given
// area keys, shaped exactly as the column stores them.
func analysisWithSOL(keys ...string) *models.Analysis {
	sol := models.JSONB{}
	for _, k := range keys {
		sol[k] = map[string]interface{}{
			"pros":     marker("PROS", k),
			"cons":     marker("CONS", k),
			"feedback": marker("FEEDBACK", k),
		}
	}
	score := 2.0
	return &models.Analysis{
		OverallScore:               &score,
		SupportiveEnvironmentScore: intPtr(2),
		Summary:                    strPtr("A summary."),
		ScienceOfLearning:          sol,
	}
}

// readSheet returns every cell of a sheet joined into one string, which is all
// these assertions need.
func readSheet(t *testing.T, data []byte, sheet string) string {
	t.Helper()
	f, err := excelize.OpenReader(strings.NewReader(string(data)))
	if err != nil {
		t.Fatalf("generated file is not readable as xlsx: %v", err)
	}
	defer f.Close()

	rows, err := f.GetRows(sheet)
	if err != nil {
		t.Fatalf("sheet %q not readable: %v", sheet, err)
	}
	var b strings.Builder
	for _, row := range rows {
		b.WriteString(strings.Join(row, "\t"))
		b.WriteString("\n")
	}
	return b.String()
}

// TestAnalysisExportIncludesScienceOfLearning is the reported bug: the section
// renders on the dashboard but was absent from the Excel the pedagogical experts
// score from.
func TestAnalysisExportIncludesScienceOfLearning(t *testing.T) {
	analysis := analysisWithSOL(
		"clarity_and_cognitive_load",
		"student_engagement_and_retrieval_practice",
		"feedback_and_metacognition",
	)

	buf, err := GenerateAnalysisExcel(analysis, testUser("Ethiopia"), testRecording(), nil)
	if err != nil {
		t.Fatalf("export failed: %v", err)
	}
	sheet := readSheet(t, buf.Bytes(), "AI Analysis Report")

	if !strings.Contains(sheet, "Science of Learning") {
		t.Error("export is missing the Science of Learning section heading")
	}

	for _, want := range []string{
		"Clarity & Cognitive Load",
		"Engagement & Retrieval",
		"Feedback & Metacognition",
	} {
		if !strings.Contains(sheet, want) {
			t.Errorf("export is missing area %q", want)
		}
	}

	// Every field of every area must survive — pros, cons and feedback.
	for _, key := range []string{
		"clarity_and_cognitive_load",
		"student_engagement_and_retrieval_practice",
		"feedback_and_metacognition",
	} {
		for _, prefix := range []string{"PROS", "CONS", "FEEDBACK"} {
			if !strings.Contains(sheet, marker(prefix, key)) {
				t.Errorf("export dropped %s", marker(prefix, key))
			}
		}
	}

	// Labels must match what the dashboard shows, so an expert reading both is
	// reading the same words.
	for _, label := range []string{"Strengths:", "Watch-outs:", "Coach feedback:"} {
		if !strings.Contains(sheet, label) {
			t.Errorf("export is missing the %q label", label)
		}
	}
}

// A Brazilian analysis carries the two priority skills instead of the default
// three (see gemini/programme.go). The export must follow the data, not a
// hardcoded list.
func TestAnalysisExportHandlesConfiguredAreas(t *testing.T) {
	analysis := analysisWithSOL("checks_understanding", "feedback")

	buf, err := GenerateAnalysisExcel(analysis, testUser("Brazil"), testRecording(), nil)
	if err != nil {
		t.Fatalf("export failed: %v", err)
	}
	sheet := readSheet(t, buf.Bytes(), "AI Analysis Report")

	for _, want := range []string{
		"Checking for Understanding", "Giving Feedback",
		marker("PROS", "checks_understanding"), marker("FEEDBACK", "feedback"),
	} {
		if !strings.Contains(sheet, want) {
			t.Errorf("export is missing %q", want)
		}
	}
}

// An area the configuration doesn't know about must still be exported rather
// than silently dropped — otherwise a config change loses data from the record.
func TestAnalysisExportKeepsUnknownAreas(t *testing.T) {
	analysis := analysisWithSOL("clarity_and_cognitive_load", "some_future_area")

	buf, err := GenerateAnalysisExcel(analysis, testUser("Ethiopia"), testRecording(), nil)
	if err != nil {
		t.Fatalf("export failed: %v", err)
	}
	sheet := readSheet(t, buf.Bytes(), "AI Analysis Report")

	if !strings.Contains(sheet, "Some Future Area") {
		t.Error("unknown area was not de-slugified into a readable label")
	}
	if !strings.Contains(sheet, marker("PROS", "some_future_area")) {
		t.Error("unknown area's content was dropped")
	}
}

// An analysis with no coaching section must not emit an empty heading.
func TestAnalysisExportOmitsEmptyScienceOfLearning(t *testing.T) {
	analysis := analysisWithSOL()

	buf, err := GenerateAnalysisExcel(analysis, testUser("Ethiopia"), testRecording(), nil)
	if err != nil {
		t.Fatalf("export failed: %v", err)
	}
	sheet := readSheet(t, buf.Bytes(), "AI Analysis Report")

	if strings.Contains(sheet, "Science of Learning") {
		t.Error("empty analysis should not emit a Science of Learning heading")
	}
}

// withContentWarning attaches a recording-quality caveat, stored the way the
// analysis handler stores it — nested inside time_on_learning.
func withContentWarning(a *models.Analysis, warningType, message string, seconds float64) *models.Analysis {
	a.TimeOnLearning = models.JSONB{
		"content_warning": map[string]interface{}{
			"type":             warningType,
			"message":          message,
			"detected_seconds": seconds,
		},
	}
	return a
}

// A reviewer scoring the AI's output must be told when the recording itself
// limited what the AI could assess — otherwise the model is marked down for a
// shallow analysis of shallow audio.
func TestAnalysisExportIncludesContentWarning(t *testing.T) {
	analysis := withContentWarning(
		analysisWithSOL("clarity_and_cognitive_load"),
		"too_short",
		"This recording is only a few seconds long.",
		18,
	)

	buf, err := GenerateAnalysisExcel(analysis, testUser("Ethiopia"), testRecording(), nil)
	if err != nil {
		t.Fatalf("export failed: %v", err)
	}
	sheet := readSheet(t, buf.Bytes(), "AI Analysis Report")

	for _, want := range []string{
		"Recording quality caveat",
		"Recording too short for a full analysis",
		"18 seconds",
		"This recording is only a few seconds long.",
	} {
		if !strings.Contains(sheet, want) {
			t.Errorf("export is missing %q", want)
		}
	}
}

func TestContentWarningLabels(t *testing.T) {
	cases := map[string]string{
		"too_short":        "Recording too short for a full analysis",
		"limited_teaching": "Limited teaching activity detected",
		"poor_audio":       "Audio quality too low to assess most behaviours",
	}
	for warningType, wantLabel := range cases {
		a := withContentWarning(analysisWithSOL(), warningType, "msg", 0)
		got, ok := contentWarning(a)
		if !ok {
			t.Fatalf("%s: warning not detected", warningType)
		}
		if got.label != wantLabel {
			t.Errorf("%s: label = %q, want %q", warningType, got.label, wantLabel)
		}
	}
}

// The overwhelming majority of lessons have no caveat; those exports must not
// carry an empty warning block.
func TestAnalysisExportOmitsAbsentContentWarning(t *testing.T) {
	analysis := analysisWithSOL("clarity_and_cognitive_load")

	buf, err := GenerateAnalysisExcel(analysis, testUser("Ethiopia"), testRecording(), nil)
	if err != nil {
		t.Fatalf("export failed: %v", err)
	}
	sheet := readSheet(t, buf.Bytes(), "AI Analysis Report")

	if strings.Contains(sheet, "Recording quality caveat") {
		t.Error("a clean analysis should not carry a quality caveat")
	}
}

// A malformed or partial warning must not panic or emit a half-filled block.
func TestContentWarningIgnoresMalformedData(t *testing.T) {
	a := analysisWithSOL()
	a.TimeOnLearning = models.JSONB{"content_warning": "not a map"}
	if _, ok := contentWarning(a); ok {
		t.Error("a non-object content_warning should be ignored")
	}

	a.TimeOnLearning = models.JSONB{"content_warning": map[string]interface{}{}}
	if _, ok := contentWarning(a); ok {
		t.Error("an empty content_warning should be ignored")
	}

	a.TimeOnLearning = nil
	if _, ok := contentWarning(a); ok {
		t.Error("a nil time_on_learning should be ignored")
	}
}

// The model writes a concrete classroom example for every recommendation; the
// export used to drop it.
func TestAnalysisExportIncludesRecommendationExample(t *testing.T) {
	analysis := analysisWithSOL("clarity_and_cognitive_load")
	analysis.Recommendations = models.JSONBArray{
		map[string]interface{}{
			"title":       "Use wait time",
			"description": "Pause after asking a question.",
			"example":     "Count to five silently before calling on anyone.",
		},
	}

	buf, err := GenerateAnalysisExcel(analysis, testUser("Ethiopia"), testRecording(), nil)
	if err != nil {
		t.Fatalf("export failed: %v", err)
	}
	sheet := readSheet(t, buf.Bytes(), "AI Analysis Report")

	for _, want := range []string{
		"Use wait time",
		"Pause after asking a question.",
		"Count to five silently before calling on anyone.",
	} {
		if !strings.Contains(sheet, want) {
			t.Errorf("export is missing recommendation content: %q", want)
		}
	}
}
