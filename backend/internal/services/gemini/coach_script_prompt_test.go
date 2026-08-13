package gemini

import (
	"encoding/json"
	"strings"
	"testing"
)

const sampleElementJSON = `{"score":2,"rationale":"Checks were choral.","behaviors":{}}`

func coachPromptFor(language string) string {
	return GetCoachScriptPrompt(
		"Checks for Understanding", "Mathematics", "Grade 3",
		sampleElementJSON, language,
	)
}

func TestCoachScriptPromptNamesAllSevenBlocks(t *testing.T) {
	prompt := coachPromptFor("en")

	for _, key := range []string{
		"observed_evidence", "what_it_means", "coach_question",
		"follow_up_questions", "possible_model", "practice", "next_step",
	} {
		if !strings.Contains(prompt, key) {
			t.Errorf("prompt does not mention output key %q", key)
		}
	}
}

// The coaching script must carry the same voice and language rules as the TEACH
// analysis — a coordinator reads both in one sitting, and wording that drifts
// between them reads as two different tools.
func TestCoachScriptPromptReusesSharedRules(t *testing.T) {
	prompt := coachPromptFor("en")

	if !strings.Contains(prompt, CoordinatorVoiceRules) {
		t.Error("prompt does not embed the shared coordinator voice rules")
	}
	if !strings.Contains(prompt, NonJudgementalRules) {
		t.Error("prompt does not embed the shared non-judgemental language rules")
	}
}

func TestCoachScriptPromptIncludesLessonContext(t *testing.T) {
	prompt := coachPromptFor("en")

	for _, want := range []string{
		"Checks for Understanding", "Mathematics", "Grade 3", sampleElementJSON,
	} {
		if !strings.Contains(prompt, want) {
			t.Errorf("prompt is missing lesson context: %q", want)
		}
	}
}

// Missing subject/grade must not leak an empty field into the prompt.
func TestCoachScriptPromptHandlesMissingContext(t *testing.T) {
	prompt := GetCoachScriptPrompt("Feedback", "", "", sampleElementJSON, "en")

	if !strings.Contains(prompt, "Subject: unspecified") {
		t.Error("empty subject should render as 'unspecified'")
	}
	if !strings.Contains(prompt, "Grade level: unspecified") {
		t.Error("empty grade level should render as 'unspecified'")
	}
}

func TestCoachScriptPromptLanguage(t *testing.T) {
	cases := map[string]string{
		"pt": "Portuguese", "fr": "French", "am": "Amharic",
		"sw": "Swahili", "en": "English", "zz": "English",
	}
	for code, want := range cases {
		if !strings.Contains(coachPromptFor(code), "**"+want+"** language") {
			t.Errorf("language %q did not resolve to %q", code, want)
		}
	}
}

// TestCoachScriptResultParses covers the shape the handler depends on — in
// particular that both array blocks survive unmarshalling.
func TestCoachScriptResultParses(t *testing.T) {
	raw := `{
	  "observed_evidence": ["Class answered together at 04:10", "No individual checks were audible"],
	  "what_it_means": "Choral responses make it hard to tell who has understood.",
	  "coach_question": "How did you decide the class was ready to move on?",
	  "follow_up_questions": ["Which students did you hear from?", "What would tell you a quieter student was stuck?"],
	  "possible_model": "Cold-calling two students by name after a choral response.",
	  "practice": "Rehearse three names to call on during the next number line activity.",
	  "next_step": "Check two individual students before moving between sections next lesson."
	}`

	var result CoachScriptResult
	if err := json.Unmarshal([]byte(raw), &result); err != nil {
		t.Fatalf("failed to parse a representative response: %v", err)
	}

	if len(result.ObservedEvidence) != 2 {
		t.Errorf("expected 2 evidence items, got %d", len(result.ObservedEvidence))
	}
	if len(result.FollowUpQuestions) != 2 {
		t.Errorf("expected 2 follow-up questions, got %d", len(result.FollowUpQuestions))
	}
	if result.CoachQuestion == "" {
		t.Error("coach question did not parse")
	}
	if result.NextStep == "" {
		t.Error("next step did not parse")
	}
}

// The model wraps JSON in markdown fences often enough that the recovery path is
// load-bearing; this pins that the shared helpers handle it.
func TestCoachScriptResultParsesThroughRecoveryHelpers(t *testing.T) {
	fenced := "Here is the script:\n```json\n" + `{
	  "observed_evidence": ["One item (01:00)"],
	  "what_it_means": "A reading.",
	  "coach_question": "An opening question?",
	  "follow_up_questions": ["Another question?"],
	  "possible_model": "A model.",
	  "practice": "A rehearsal.",
	  "next_step": "A commitment."
	}` + "\n```\n"

	cleaned := cleanGeminiJSON(extractJSON(fenced))

	var result CoachScriptResult
	if err := json.Unmarshal([]byte(cleaned), &result); err != nil {
		t.Fatalf("recovery helpers did not yield parseable JSON: %v", err)
	}
	if result.CoachQuestion != "An opening question?" {
		t.Errorf("unexpected coach question: %q", result.CoachQuestion)
	}
}
