package exporter

import (
	"bytes"
	"fmt"
	"regexp"
	"sort"
	"strings"

	"github.com/worldbank/ai-coach/backend/internal/models"
	"github.com/worldbank/ai-coach/backend/internal/services/gemini"
	"github.com/xuri/excelize/v2"
)

// GenerateAnalysisExcel creates an Excel workbook with three sheets:
// 1. Analysis Report - Complete AI analysis with all scores and feedback
// 2. Manual Scoring Template - manual scoring sheet, pre-filled from `manual`
// 3. Comparison - Side-by-side comparison of AI vs Human scores
//
// `manual` is optional: pass nil for a blank template (e.g. the teacher-app Drive
// upload), or a saved coach score to pre-fill the template and comparison sheets.
func GenerateAnalysisExcel(analysis *models.Analysis, user *models.User, recording *models.Recording, manual *models.ManualScore) (*bytes.Buffer, error) {
	f := excelize.NewFile()
	defer f.Close()

	// Create three sheets
	sheet1 := "AI Analysis Report"
	sheet2 := "Manual Scoring Template"
	sheet3 := "AI vs Human Comparison"

	// Rename default sheet to sheet1
	f.SetSheetName("Sheet1", sheet1)
	f.NewSheet(sheet2)
	f.NewSheet(sheet3)

	// Generate each sheet
	if err := generateAnalysisSheet(f, sheet1, analysis, user, recording); err != nil {
		return nil, fmt.Errorf("failed to generate analysis sheet: %v", err)
	}

	if err := generateBlankTemplateSheet(f, sheet2, user, recording, manual); err != nil {
		return nil, fmt.Errorf("failed to generate template sheet: %v", err)
	}

	if err := generateComparisonSheet(f, sheet3, analysis, user, recording, manual); err != nil {
		return nil, fmt.Errorf("failed to generate comparison sheet: %v", err)
	}

	// Write to buffer
	buf := new(bytes.Buffer)
	if err := f.Write(buf); err != nil {
		return nil, fmt.Errorf("failed to write excel to buffer: %v", err)
	}

	return buf, nil
}

// generateAnalysisSheet creates the AI Analysis Report sheet
func generateAnalysisSheet(f *excelize.File, sheetName string, analysis *models.Analysis, user *models.User, recording *models.Recording) error {
	// Header styling
	headerStyle, _ := f.NewStyle(&excelize.Style{
		Font:      &excelize.Font{Bold: true, Size: 14, Color: "FFFFFF"},
		Fill:      excelize.Fill{Type: "pattern", Color: []string{"4472C4"}, Pattern: 1},
		Alignment: &excelize.Alignment{Horizontal: "center", Vertical: "center"},
	})

	sectionStyle, _ := f.NewStyle(&excelize.Style{
		Font: &excelize.Font{Bold: true, Size: 12},
		Fill: excelize.Fill{Type: "pattern", Color: []string{"D9E1F2"}, Pattern: 1},
	})

	labelStyle, _ := f.NewStyle(&excelize.Style{
		Font: &excelize.Font{Bold: true},
	})

	// Title
	f.SetCellValue(sheetName, "A1", "TEACH Framework Analysis Report")
	f.SetCellStyle(sheetName, "A1", "D1", headerStyle)
	f.MergeCell(sheetName, "A1", "D1")

	// Metadata
	row := 3
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Teacher:")
	f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), fmt.Sprintf("%s %s", user.FirstName, user.LastName))
	row++
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Recording Title:")
	f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), derefStr(recording.Title))
	row++
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Subject:")
	if recording.Subject != nil {
		f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), *recording.Subject)
	}
	row++
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Grade Level:")
	if recording.GradeLevel != nil {
		f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), *recording.GradeLevel)
	}
	row++
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Overall Score:")
	if analysis.OverallScore != nil {
		f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), fmt.Sprintf("%.2f / 5.0", *analysis.OverallScore))
	}
	row += 2

	// ── Recording quality caveat ──────────────────────────────────────────────
	// Placed above the scores on purpose. When the AI flagged the audio as short,
	// largely inaudible, or thin on teaching content, a reviewer scoring the AI's
	// output needs to know that before reading it — otherwise the model gets
	// marked down for a shallow analysis of shallow audio.
	if warning, ok := contentWarning(analysis); ok {
		warningStyle, _ := f.NewStyle(&excelize.Style{
			Font: &excelize.Font{Bold: true, Color: "9C5700"},
			Fill: excelize.Fill{Type: "pattern", Color: []string{"FFEB9C"}, Pattern: 1},
		})

		f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "⚠ Recording quality caveat")
		f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("D%d", row), warningStyle)
		f.MergeCell(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("D%d", row))
		row++

		f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Issue:")
		f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("A%d", row), labelStyle)
		f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), warning.label)
		row++

		if warning.detectedSeconds > 0 {
			f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Detected audio:")
			f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("A%d", row), labelStyle)
			f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), fmt.Sprintf("%d seconds", warning.detectedSeconds))
			row++
		}

		if warning.message != "" {
			f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Detail:")
			f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("A%d", row), labelStyle)
			f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), stripMarkdown(warning.message))
			f.MergeCell(sheetName, fmt.Sprintf("B%d", row), fmt.Sprintf("D%d", row))
			row++
		}
		row++
	}

	// TEACH Framework Scores
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "TEACH Framework Scores")
	f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("D%d", row), sectionStyle)
	f.MergeCell(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("D%d", row))
	row++

	// Table headers
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Element")
	f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), "Score")
	f.SetCellValue(sheetName, fmt.Sprintf("C%d", row), "Rationale")
	f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("C%d", row), labelStyle)
	row++

	// Add each element
	elements := []struct {
		name      string
		score     *int
		behaviors models.JSONB
	}{
		{"Supportive Environment", analysis.SupportiveEnvironmentScore, analysis.SupportiveEnvironmentBehaviors},
		{"Positive Expectations", analysis.PositiveExpectationsScore, analysis.PositiveExpectationsBehaviors},
		{"Lesson Facilitation", analysis.LessonFacilitationScore, analysis.LessonFacilitationBehaviors},
		{"Checks Understanding", analysis.ChecksUnderstandingScore, analysis.ChecksUnderstandingBehaviors},
		{"Feedback", analysis.FeedbackScore, analysis.FeedbackBehaviors},
		{"Critical Thinking", analysis.CriticalThinkingScore, analysis.CriticalThinkingBehaviors},
		{"Autonomy", analysis.AutonomyScore, analysis.AutonomyBehaviors},
		{"Perseverance", analysis.PerseveranceScore, analysis.PerseveranceBehaviors},
		{"Social & Collaborative", analysis.SocialCollaborativeScore, analysis.SocialCollaborativeBehaviors},
	}

	for _, elem := range elements {
		f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), elem.name)
		if elem.score != nil {
			f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), *elem.score)
		} else {
			f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), "N/A")
		}

		// Extract rationale from behaviors JSONB
		if rationale, ok := elem.behaviors["rationale"].(string); ok {
			f.SetCellValue(sheetName, fmt.Sprintf("C%d", row), stripMarkdown(rationale))
		}
		row++
	}

	row++

	// Qualitative Feedback
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Qualitative Feedback")
	f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("D%d", row), sectionStyle)
	f.MergeCell(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("D%d", row))
	row++

	if analysis.Summary != nil {
		f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Summary:")
		f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("A%d", row), labelStyle)
		row++
		f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), stripMarkdown(*analysis.Summary))
		f.MergeCell(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("D%d", row))
		row += 2
	}

	// Strengths
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Strengths:")
	f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("A%d", row), labelStyle)
	row++
	for _, strength := range analysis.Strengths {
		if str, ok := strength.(string); ok {
			f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "• "+stripMarkdown(str))
			f.MergeCell(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("D%d", row))
			row++
		}
	}
	row++

	// Areas for Improvement
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Areas for Improvement:")
	f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("A%d", row), labelStyle)
	row++
	for _, area := range analysis.AreasForImprovement {
		if str, ok := area.(string); ok {
			f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "• "+stripMarkdown(str))
			f.MergeCell(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("D%d", row))
			row++
		}
	}
	row++

	// Recommendations
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Recommendations:")
	f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("A%d", row), labelStyle)
	row++
	for _, rec := range analysis.Recommendations {
		if recMap, ok := rec.(map[string]interface{}); ok {
			if title, ok := recMap["title"].(string); ok {
				f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "• "+stripMarkdown(title))
				f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("A%d", row), labelStyle)
				row++
				if desc, ok := recMap["description"].(string); ok {
					f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "  "+stripMarkdown(desc))
					f.MergeCell(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("D%d", row))
					row++
				}
				// The model produces a concrete classroom example for every
				// recommendation; the export was dropping it on the floor.
				if example, ok := recMap["example"].(string); ok && example != "" {
					f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "  Example: "+stripMarkdown(example))
					f.MergeCell(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("D%d", row))
					row++
				}
			}
		}
	}

	row++

	// ── Science of Learning ───────────────────────────────────────────────────
	// Present on the dashboard but previously missing from this export, which
	// left the pedagogical experts reviewing the AI's feedback without a third
	// of it.
	if areas := coachingAreasFor(analysis, user); len(areas) > 0 {
		f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Science of Learning")
		f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("D%d", row), sectionStyle)
		f.MergeCell(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("D%d", row))
		row++

		for _, area := range areas {
			f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), area.label)
			f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("A%d", row), labelStyle)
			row++

			// Labels match what the dashboard shows, so an expert comparing the
			// two is reading the same words.
			for _, part := range []struct{ label, text string }{
				{"Strengths:", area.pros},
				{"Watch-outs:", area.cons},
				{"Coach feedback:", area.feedback},
			} {
				if part.text == "" {
					continue
				}
				f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), part.label)
				f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), stripMarkdown(part.text))
				f.MergeCell(sheetName, fmt.Sprintf("B%d", row), fmt.Sprintf("D%d", row))
				row++
			}
			row++
		}
	}

	// Set column widths
	f.SetColWidth(sheetName, "A", "A", 25)
	f.SetColWidth(sheetName, "B", "B", 12)
	f.SetColWidth(sheetName, "C", "D", 50)

	return nil
}

// audioCaveat is the AI's flag that the recording limited what it could assess.
type audioCaveat struct {
	// label is a stable English name for the issue. The message itself is
	// written in the teacher's language, so the label gives an English-reading
	// reviewer something to anchor on.
	label           string
	message         string
	detectedSeconds int
}

// contentWarning pulls the AI's recording-quality caveat out of the analysis.
//
// It lives under time_on_learning rather than in its own column — the analysis
// handler tucks several extras in there to avoid schema changes. Reading it here
// keeps that quirk in one place.
func contentWarning(analysis *models.Analysis) (audioCaveat, bool) {
	raw, ok := analysis.TimeOnLearning["content_warning"].(map[string]interface{})
	if !ok {
		return audioCaveat{}, false
	}

	warningType, _ := raw["type"].(string)
	message, _ := raw["message"].(string)
	if warningType == "" && message == "" {
		return audioCaveat{}, false
	}

	// JSON numbers decode as float64.
	seconds := 0
	if v, ok := raw["detected_seconds"].(float64); ok {
		seconds = int(v)
	}

	label := ""
	switch warningType {
	case "too_short":
		label = "Recording too short for a full analysis"
	case "limited_teaching":
		label = "Limited teaching activity detected"
	case "poor_audio":
		label = "Audio quality too low to assess most behaviours"
	case "":
		label = "Recording quality flagged"
	default:
		label = warningType
	}

	return audioCaveat{label: label, message: message, detectedSeconds: seconds}, true
}

// solArea is one Science of Learning area, flattened for the export.
type solArea struct {
	label    string
	pros     string
	cons     string
	feedback string
}

// coachingAreasFor flattens the analysis's science_of_learning JSONB into
// ordered, labelled rows.
//
// Which areas exist is per-deployment configuration (gemini/programme.go), and
// Go map iteration is random, so order comes from the configured list for the
// teacher's country. Any key not in that list — an older analysis, or a country
// whose configuration has since changed — is still emitted, after the known
// ones, so nothing is silently dropped from the export.
func coachingAreasFor(analysis *models.Analysis, user *models.User) []solArea {
	if len(analysis.ScienceOfLearning) == 0 {
		return nil
	}

	country := ""
	if user != nil && user.Country != nil {
		country = *user.Country
	}

	var ordered []string
	seen := map[string]bool{}
	for _, area := range gemini.CoachingAreasFor(country) {
		if _, ok := analysis.ScienceOfLearning[area.Key]; ok {
			ordered = append(ordered, area.Key)
			seen[area.Key] = true
		}
	}
	var leftovers []string
	for key := range analysis.ScienceOfLearning {
		if !seen[key] {
			leftovers = append(leftovers, key)
		}
	}
	sort.Strings(leftovers)
	ordered = append(ordered, leftovers...)

	result := make([]solArea, 0, len(ordered))
	for _, key := range ordered {
		content, ok := analysis.ScienceOfLearning[key].(map[string]interface{})
		if !ok {
			continue
		}
		str := func(field string) string {
			v, _ := content[field].(string)
			return v
		}
		area := solArea{
			label:    solAreaLabel(key),
			pros:     str("pros"),
			cons:     str("cons"),
			feedback: str("feedback"),
		}
		if area.pros == "" && area.cons == "" && area.feedback == "" {
			continue
		}
		result = append(result, area)
	}
	return result
}

// solAreaLabel gives a coaching area a readable English name, falling back to a
// de-slugified key so a newly configured area never exports as snake_case.
func solAreaLabel(key string) string {
	switch key {
	case "clarity_and_cognitive_load":
		return "Clarity & Cognitive Load"
	case "student_engagement_and_retrieval_practice":
		return "Engagement & Retrieval"
	case "feedback_and_metacognition":
		return "Feedback & Metacognition"
	case "checks_understanding":
		return "Checking for Understanding"
	case "feedback":
		return "Giving Feedback"
	}

	words := strings.Split(key, "_")
	for i, w := range words {
		if w == "" {
			continue
		}
		words[i] = strings.ToUpper(w[:1]) + w[1:]
	}
	return strings.Join(words, " ")
}

// manualElement pairs a display name with the coach's score and rationale for
// one TEACH element. When `m` is nil the score/rationale are left empty (blank
// template). The keys match the frontend/element_rationales convention.
type manualElement struct {
	name      string
	score     *int
	rationale string
}

func manualElements(m *models.ManualScore) []manualElement {
	names := []string{
		"Supportive Environment", "Positive Expectations", "Lesson Facilitation",
		"Checks Understanding", "Feedback", "Critical Thinking",
		"Autonomy", "Perseverance", "Social & Collaborative",
	}
	if m == nil {
		out := make([]manualElement, len(names))
		for i, n := range names {
			out[i] = manualElement{name: n}
		}
		return out
	}
	rat := func(key string) string {
		if m.ElementRationales == nil {
			return ""
		}
		if v, ok := m.ElementRationales[key].(string); ok {
			return v
		}
		return ""
	}
	scores := []*int{
		m.SupportiveEnvironmentScore, m.PositiveExpectationsScore, m.LessonFacilitationScore,
		m.ChecksUnderstandingScore, m.FeedbackScore, m.CriticalThinkingScore,
		m.AutonomyScore, m.PerseveranceScore, m.SocialCollaborativeScore,
	}
	keys := []string{
		"supportive_environment", "positive_expectations", "lesson_facilitation",
		"checks_understanding", "feedback", "critical_thinking",
		"autonomy", "perseverance", "social_collaborative",
	}
	out := make([]manualElement, len(names))
	for i, n := range names {
		out[i] = manualElement{name: n, score: scores[i], rationale: rat(keys[i])}
	}
	return out
}

// derefStr returns the string value of a *string, or "" when nil.
func derefStr(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

// generateBlankTemplateSheet creates the manual scoring sheet. When `manual` is
// non-nil the score/rationale and qualitative cells are pre-filled.
func generateBlankTemplateSheet(f *excelize.File, sheetName string, user *models.User, recording *models.Recording, manual *models.ManualScore) error {
	headerStyle, _ := f.NewStyle(&excelize.Style{
		Font:      &excelize.Font{Bold: true, Size: 14, Color: "FFFFFF"},
		Fill:      excelize.Fill{Type: "pattern", Color: []string{"70AD47"}, Pattern: 1},
		Alignment: &excelize.Alignment{Horizontal: "center", Vertical: "center"},
	})

	sectionStyle, _ := f.NewStyle(&excelize.Style{
		Font: &excelize.Font{Bold: true, Size: 12},
		Fill: excelize.Fill{Type: "pattern", Color: []string{"E2EFDA"}, Pattern: 1},
	})

	labelStyle, _ := f.NewStyle(&excelize.Style{
		Font: &excelize.Font{Bold: true},
	})

	// Title
	f.SetCellValue(sheetName, "A1", "Manual Scoring Template")
	f.SetCellStyle(sheetName, "A1", "D1", headerStyle)
	f.MergeCell(sheetName, "A1", "D1")

	// Instructions
	row := 3
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Instructions: Please score each element from 1-5 and provide your rationale.")
	f.MergeCell(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("D%d", row))
	row += 2

	// Metadata
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Teacher:")
	f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), fmt.Sprintf("%s %s", user.FirstName, user.LastName))
	row++
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Recording Title:")
	f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), derefStr(recording.Title))
	row += 2

	// TEACH Framework Scores
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "TEACH Framework Scores")
	f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("D%d", row), sectionStyle)
	f.MergeCell(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("D%d", row))
	row++

	// Table headers
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Element")
	f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), "Your Score (1-5)")
	f.SetCellValue(sheetName, fmt.Sprintf("C%d", row), "Your Rationale")
	f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("C%d", row), labelStyle)
	row++

	// Add each element, pre-filling the score (B) and rationale (C) when present.
	for _, elem := range manualElements(manual) {
		f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), elem.name)
		if elem.score != nil {
			f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), *elem.score)
		}
		if elem.rationale != "" {
			f.SetCellValue(sheetName, fmt.Sprintf("C%d", row), elem.rationale)
		}
		row++
	}

	row++

	// Overall Score
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Overall Score:")
	f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("A%d", row), labelStyle)
	if manual != nil && manual.OverallScore != nil {
		f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), fmt.Sprintf("%.2f / 5.0", *manual.OverallScore))
	}
	row += 2

	// Qualitative Feedback section
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Your Qualitative Feedback")
	f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("D%d", row), sectionStyle)
	f.MergeCell(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("D%d", row))
	row++

	// qualitative writes a bold label then the (optional) value on the next row.
	qualitative := func(label, value string) {
		f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), label)
		f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("A%d", row), labelStyle)
		row++
		if value != "" {
			f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), value)
			f.MergeCell(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("D%d", row))
		}
		row += 2
	}

	var summary, strengths, areas, recs string
	if manual != nil {
		summary = derefStr(manual.Summary)
		strengths = derefStr(manual.Strengths)
		areas = derefStr(manual.AreasForImprovement)
		recs = derefStr(manual.Recommendations)
	}
	qualitative("Summary:", summary)
	qualitative("Strengths:", strengths)
	qualitative("Areas for Improvement:", areas)
	qualitative("Recommendations:", recs)

	// Set column widths
	f.SetColWidth(sheetName, "A", "A", 25)
	f.SetColWidth(sheetName, "B", "B", 20)
	f.SetColWidth(sheetName, "C", "D", 50)

	return nil
}

// generateComparisonSheet creates a side-by-side comparison of AI vs Human
// scores. When `manual` is non-nil the Human Score and Notes columns are filled.
func generateComparisonSheet(f *excelize.File, sheetName string, analysis *models.Analysis, user *models.User, recording *models.Recording, manual *models.ManualScore) error {
	headerStyle, _ := f.NewStyle(&excelize.Style{
		Font:      &excelize.Font{Bold: true, Size: 14, Color: "FFFFFF"},
		Fill:      excelize.Fill{Type: "pattern", Color: []string{"FFC000"}, Pattern: 1},
		Alignment: &excelize.Alignment{Horizontal: "center", Vertical: "center"},
	})

	sectionStyle, _ := f.NewStyle(&excelize.Style{
		Font: &excelize.Font{Bold: true, Size: 12},
		Fill: excelize.Fill{Type: "pattern", Color: []string{"FFF2CC"}, Pattern: 1},
	})

	labelStyle, _ := f.NewStyle(&excelize.Style{
		Font: &excelize.Font{Bold: true},
	})

	// Title
	f.SetCellValue(sheetName, "A1", "AI vs Human Scoring Comparison")
	f.SetCellStyle(sheetName, "A1", "E1", headerStyle)
	f.MergeCell(sheetName, "A1", "E1")

	// Metadata
	row := 3
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Teacher:")
	f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), fmt.Sprintf("%s %s", user.FirstName, user.LastName))
	row++
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Recording Title:")
	f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), derefStr(recording.Title))
	row += 2

	// TEACH Framework Comparison
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "TEACH Framework Comparison")
	f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("E%d", row), sectionStyle)
	f.MergeCell(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("E%d", row))
	row++

	// Table headers
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Element")
	f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), "AI Score")
	f.SetCellValue(sheetName, fmt.Sprintf("C%d", row), "Human Score")
	f.SetCellValue(sheetName, fmt.Sprintf("D%d", row), "Difference")
	f.SetCellValue(sheetName, fmt.Sprintf("E%d", row), "Notes")
	f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("E%d", row), labelStyle)
	row++

	// Add each element
	elements := []struct {
		name  string
		score *int
	}{
		{"Supportive Environment", analysis.SupportiveEnvironmentScore},
		{"Positive Expectations", analysis.PositiveExpectationsScore},
		{"Lesson Facilitation", analysis.LessonFacilitationScore},
		{"Checks Understanding", analysis.ChecksUnderstandingScore},
		{"Feedback", analysis.FeedbackScore},
		{"Critical Thinking", analysis.CriticalThinkingScore},
		{"Autonomy", analysis.AutonomyScore},
		{"Perseverance", analysis.PerseveranceScore},
		{"Social & Collaborative", analysis.SocialCollaborativeScore},
	}

	human := manualElements(manual)
	startRow := row
	for i, elem := range elements {
		f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), elem.name)
		if elem.score != nil {
			f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), *elem.score)
		} else {
			f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), "N/A")
		}
		// Human score (C) and notes (E), pre-filled from the saved manual score.
		if human[i].score != nil {
			f.SetCellValue(sheetName, fmt.Sprintf("C%d", row), *human[i].score)
		}
		if human[i].rationale != "" {
			f.SetCellValue(sheetName, fmt.Sprintf("E%d", row), human[i].rationale)
		}
		// Difference formula
		if elem.score != nil {
			f.SetCellFormula(sheetName, fmt.Sprintf("D%d", row),
				fmt.Sprintf("IF(ISNUMBER(C%d),C%d-B%d,\"\")", row, row, row))
		}
		row++
	}

	row++

	// Overall Score Comparison
	f.SetCellValue(sheetName, fmt.Sprintf("A%d", row), "Overall Score")
	f.SetCellStyle(sheetName, fmt.Sprintf("A%d", row), fmt.Sprintf("A%d", row), labelStyle)
	if analysis.OverallScore != nil {
		f.SetCellValue(sheetName, fmt.Sprintf("B%d", row), fmt.Sprintf("%.2f", *analysis.OverallScore))
	}
	// Formula to calculate human overall score as average
	// Use IFERROR to handle #DIV/0! when no scores are entered yet
	f.SetCellFormula(sheetName, fmt.Sprintf("C%d", row),
		fmt.Sprintf("IFERROR(AVERAGE(C%d:C%d), \"\")", startRow, startRow+8))
	f.SetCellFormula(sheetName, fmt.Sprintf("D%d", row),
		fmt.Sprintf("IF(ISNUMBER(C%d),C%d-B%d,\"\")", row, row, row))

	// Set column widths
	f.SetColWidth(sheetName, "A", "A", 25)
	f.SetColWidth(sheetName, "B", "D", 15)
	f.SetColWidth(sheetName, "E", "E", 40)

	return nil
}

// GenerateLessonsLogExcel creates a single-sheet workbook listing the
// consolidated lesson log (one recording per row) for the monitoring dashboard
// export. Rows should already be filtered/ordered by the caller.
func GenerateLessonsLogExcel(rows []*models.LessonLogRow) (*bytes.Buffer, error) {
	f := excelize.NewFile()
	defer f.Close()

	sheet := "Lessons"
	f.SetSheetName("Sheet1", sheet)

	headerStyle, _ := f.NewStyle(&excelize.Style{
		Font:      &excelize.Font{Bold: true, Color: "FFFFFF"},
		Fill:      excelize.Fill{Type: "pattern", Color: []string{"4472C4"}, Pattern: 1},
		Alignment: &excelize.Alignment{Horizontal: "center", Vertical: "center"},
	})

	// "Teacher" is whoever taught the lesson. "Recorded by" is the account that
	// made the recording — the same person for a teacher's own lesson, the
	// coordinator for an observed one.
	headers := []string{
		"Date", "Country", "School", "Teacher", "Username",
		"Recorded by", "Recorded by role",
		"Subject", "Grade", "Language", "Duration (s)", "Status",
		"Analyzed", "Overall Score", "Recording ID",
	}
	for i, h := range headers {
		cell, _ := excelize.CoordinatesToCellName(i+1, 1)
		f.SetCellValue(sheet, cell, h)
	}
	lastCol, _ := excelize.CoordinatesToCellName(len(headers), 1)
	f.SetCellStyle(sheet, "A1", lastCol, headerStyle)

	deref := func(s *string) string {
		if s == nil {
			return ""
		}
		return *s
	}

	for ri, row := range rows {
		r := ri + 2 // data starts on row 2
		date := ""
		if row.CreatedAt != nil {
			date = row.CreatedAt.Format("2006-01-02 15:04")
		}
		duration := ""
		if row.DurationSeconds != nil {
			duration = fmt.Sprintf("%d", *row.DurationSeconds)
		}
		analyzed := "No"
		score := ""
		if row.HasAnalysis {
			analyzed = "Yes"
			if row.OverallScore != nil {
				score = fmt.Sprintf("%.2f", *row.OverallScore)
			}
		}

		values := []interface{}{
			date, deref(row.Country), deref(row.SchoolName), row.TeacherName, row.TeacherUsername,
			row.RecordedByName, row.RecordedByRole,
			deref(row.Subject), deref(row.GradeLevel), row.Language, duration, row.Status,
			analyzed, score, row.RecordingID.String(),
		}
		for ci, v := range values {
			cell, _ := excelize.CoordinatesToCellName(ci+1, r)
			f.SetCellValue(sheet, cell, v)
		}
	}

	// Reasonable column widths.
	f.SetColWidth(sheet, "A", "A", 18)
	f.SetColWidth(sheet, "B", "E", 20)
	f.SetColWidth(sheet, "F", "L", 14)
	f.SetColWidth(sheet, "M", "M", 38)

	buf := new(bytes.Buffer)
	if err := f.Write(buf); err != nil {
		return nil, fmt.Errorf("failed to write excel to buffer: %v", err)
	}
	return buf, nil
}

// stripMarkdown removes common markdown formatting from text
func stripMarkdown(text string) string {
	// Bold **text**
	reBold := regexp.MustCompile(`\*\*(.*?)\*\*`)
	text = reBold.ReplaceAllString(text, "$1")

	// Italic *text* - excluding list bullets at start of line
	reItalic := regexp.MustCompile(`([^*]|^)\*(.*?)\*`)
	text = reItalic.ReplaceAllString(text, "$1$2")

	// Bold __text__
	reBoldUnderscore := regexp.MustCompile(`__(.*?)__`)
	text = reBoldUnderscore.ReplaceAllString(text, "$1")

	// Italic _text_
	reItalicUnderscore := regexp.MustCompile(`_(.*?)_`)
	text = reItalicUnderscore.ReplaceAllString(text, "$1")

	return text
}
