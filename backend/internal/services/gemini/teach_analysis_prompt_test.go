package gemini

import (
	"strings"
	"testing"
)

var allLanguages = []string{"en", "pt", "fr", "am", "sw"}

// promptFor builds the analysis prompt without needing a live Gemini client —
// GetTEACHAnalysisPrompt has a pointer receiver but never dereferences it.
//
// Country is empty, so these tests exercise the default coaching areas.
func promptFor(language, audience string) string {
	return promptForCountry(language, audience, "")
}

func promptForCountry(language, audience, country string) string {
	var s *GeminiService
	return s.GetTEACHAnalysisPrompt(language, audience, country)
}

// TestTeacherPromptUnchanged is the regression guard for every deployment that
// is NOT Brazil. The teacher audience is the default and must keep the exact
// wording it had before the coordinator variant was introduced.
func TestTeacherPromptUnchanged(t *testing.T) {
	for _, lang := range allLanguages {
		t.Run(lang, func(t *testing.T) {
			prompt := promptFor(lang, AudienceTeacher)

			mustContain := []string{
				`**USE SECOND PERSON**: Address the teacher as "You".`,
				`Provide: Pros, Cons, and Feedback in the **second person** ("You...").`,
				`"pros": "You used clear language..."`,
				`"cons": "You introduced too many concepts..."`,
			}
			for _, want := range mustContain {
				if !strings.Contains(prompt, want) {
					t.Errorf("teacher prompt lost required wording: %q", want)
				}
			}

			// No coordinator framing may leak into the teacher prompt.
			mustNotContain := []string{
				"PEDAGOGY\n   COORDINATOR",
				"THIRD PERSON",
				"WRITE FOR THE COORDINATOR",
			}
			for _, unwanted := range mustNotContain {
				if strings.Contains(prompt, unwanted) {
					t.Errorf("teacher prompt contains coordinator wording: %q", unwanted)
				}
			}
		})
	}
}

func TestCoordinatorPromptVoice(t *testing.T) {
	for _, lang := range allLanguages {
		t.Run(lang, func(t *testing.T) {
			prompt := promptFor(lang, AudienceCoordinator)

			mustContain := []string{
				"THIRD PERSON",
				`NEVER address the teacher as "you"`,
				"OPENINGS FOR A CONVERSATION",
				"WRITE FOR THE COORDINATOR",
			}
			for _, want := range mustContain {
				if !strings.Contains(prompt, want) {
					t.Errorf("coordinator prompt missing: %q", want)
				}
			}

			// The teacher-voiced instructions and examples must be gone —
			// leaving them would give the model contradictory directions.
			mustNotContain := []string{
				`**USE SECOND PERSON**: Address the teacher as "You".`,
				`Provide: Pros, Cons, and Feedback in the **second person** ("You...").`,
				`"pros": "You used clear language..."`,
				`"cons": "You introduced too many concepts..."`,
				`"feedback": "You consistently..."`,
			}
			for _, unwanted := range mustNotContain {
				if strings.Contains(prompt, unwanted) {
					t.Errorf("coordinator prompt still contains teacher voice: %q", unwanted)
				}
			}
		})
	}
}

// TestQualitativeSectionCarriesTheAudienceVoice covers the gap found in testing:
// element rationale came back correctly in the third person for a coordinator
// while the recommendations still instructed the teacher. STEP 4 had no voice
// instruction and fully generic JSON placeholders, so the model fell back to the
// imperative reading of "actionable steps".
func TestQualitativeSectionCarriesTheAudienceVoice(t *testing.T) {
	t.Run("coordinator", func(t *testing.T) {
		prompt := promptFor("en", AudienceCoordinator)

		for _, want := range []string{
			"the coordinator is the reader",
			"NOT instructions for the teacher to carry out",
			"third person",
		} {
			if !strings.Contains(prompt, want) {
				t.Errorf("STEP 4 is missing coordinator guidance: %q", want)
			}
		}

		// The worked examples carry more weight than the instruction — the model
		// imitates them, which is how the generic placeholder produced the
		// imperative voice in the first place.
		if !strings.Contains(prompt, "Explore how she knows the class is ready to move on") {
			t.Error("STEP 4 has no coordinator-voiced recommendation example")
		}
		if strings.Contains(prompt, `"title": "Recommendation title"`) {
			t.Error("STEP 4 still carries the generic placeholder that caused the imperative voice")
		}
	})

	t.Run("teacher", func(t *testing.T) {
		prompt := promptFor("en", AudienceTeacher)

		if !strings.Contains(prompt, `Address the teacher directly as "You"`) {
			t.Error("teacher STEP 4 lost its direct-address instruction")
		}
		// Unchanged from before this fix, so other deployments are untouched.
		for _, want := range []string{
			`"title": "Recommendation title"`,
			`"description": "Detailed description"`,
			`"example": "Concrete example"`,
		} {
			if !strings.Contains(prompt, want) {
				t.Errorf("teacher STEP 4 example changed: %q missing", want)
			}
		}
		if strings.Contains(prompt, "the coordinator is the reader") {
			t.Error("coordinator guidance leaked into the teacher prompt")
		}
	})
}

// TestNonJudgementalRuleInBothAudiences covers feedback item B3. A teacher
// should not read "you failed to" either, so the rule is audience-independent.
func TestNonJudgementalRuleInBothAudiences(t *testing.T) {
	for _, audience := range []string{AudienceTeacher, AudienceCoordinator} {
		t.Run(audience, func(t *testing.T) {
			prompt := promptFor("en", audience)

			if !strings.Contains(prompt, "NON-JUDGEMENTAL LANGUAGE") {
				t.Fatal("prompt is missing the non-judgemental language rule")
			}
			for _, banned := range []string{`"failed to"`, `"should have"`, `"neglected"`} {
				if !strings.Contains(prompt, banned) {
					t.Errorf("banned-wording list does not mention %s", banned)
				}
			}
			// The rule must not be read as licence to score more generously.
			if !strings.Contains(prompt, "It does not soften scoring") {
				t.Error("non-judgemental rule must state that scoring is unaffected")
			}
		})
	}
}

// TestNoUnresolvedPlaceholders guards the token-substitution mechanism: a typo'd
// or renamed token would otherwise ship "{{SOL_VOICE}}" straight to the model.
func TestNoUnresolvedPlaceholders(t *testing.T) {
	for _, audience := range []string{AudienceTeacher, AudienceCoordinator, "", "nonsense"} {
		for _, lang := range allLanguages {
			prompt := promptFor(lang, audience)
			if strings.Contains(prompt, "{{") || strings.Contains(prompt, "}}") {
				t.Errorf("unresolved placeholder for audience=%q lang=%q", audience, lang)
			}
		}
	}
}

// TestUnknownAudienceFallsBackToTeacher — an unrecognised stored value must
// never produce a half-configured prompt.
func TestUnknownAudienceFallsBackToTeacher(t *testing.T) {
	teacher := promptFor("en", AudienceTeacher)

	for _, audience := range []string{"", "nonsense", "TEACHER", "Coordinator"} {
		if got := promptFor("en", audience); got != teacher {
			t.Errorf("audience %q did not fall back to the teacher prompt", audience)
		}
	}
}

func TestNormalizeAudience(t *testing.T) {
	if NormalizeAudience(AudienceCoordinator) != AudienceCoordinator {
		t.Error("coordinator must normalize to itself")
	}
	for _, in := range []string{"", "teacher", "Coordinator", "admin", "viewer"} {
		if in == AudienceCoordinator {
			continue
		}
		if got := NormalizeAudience(in); got != AudienceTeacher {
			t.Errorf("NormalizeAudience(%q) = %q, want %q", in, got, AudienceTeacher)
		}
	}
}

// TestCoachingSystemPromptAudience covers the chat prompt, which was previously
// duplicated verbatim across the streaming and blocking call sites.
func TestCoachingSystemPromptAudience(t *testing.T) {
	teacher := buildCoachingSystemPrompt("en", AudienceTeacher)
	coordinator := buildCoachingSystemPrompt("en", AudienceCoordinator)

	if !strings.Contains(teacher, "helping a teacher improve based on their TEACH analysis") {
		t.Error("teacher coaching prompt lost its original persona")
	}
	if strings.Contains(teacher, "THIRD PERSON") {
		t.Error("teacher coaching prompt contains coordinator wording")
	}

	if !strings.Contains(coordinator, "You are talking to the COORDINATOR, not the teacher") {
		t.Error("coordinator coaching prompt missing its audience framing")
	}
	if !strings.Contains(coordinator, "THIRD PERSON") {
		t.Error("coordinator coaching prompt missing third-person instruction")
	}

	// Both keep the LaTeX formatting contract the Flutter renderer depends on.
	for name, prompt := range map[string]string{"teacher": teacher, "coordinator": coordinator} {
		if !strings.Contains(prompt, "FORMATTING RULES (mandatory)") {
			t.Errorf("%s coaching prompt lost the LaTeX formatting rules", name)
		}
	}
}

func TestCoachingSystemPromptLanguage(t *testing.T) {
	cases := map[string]string{
		"pt": "Portuguese", "fr": "French", "am": "Amharic",
		"sw": "Swahili", "en": "English", "zz": "English",
	}
	for code, want := range cases {
		prompt := buildCoachingSystemPrompt(code, AudienceTeacher)
		if !strings.Contains(prompt, "reply in the **"+want+"** language") {
			t.Errorf("language %q did not resolve to %q", code, want)
		}
	}
}
