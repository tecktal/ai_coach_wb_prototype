package gemini

import (
	"strings"
	"testing"
)

// The three keys every analysis stored before B4 contains, and which Ethiopia,
// Senegal and every other unconfigured deployment must keep generating.
var defaultAreaKeys = []string{
	"clarity_and_cognitive_load",
	"student_engagement_and_retrieval_practice",
	"feedback_and_metacognition",
}

// TestUnconfiguredCountriesKeepTheDefaultAreas is the regression guard for every
// deployment that is not Brazil.
func TestUnconfiguredCountriesKeepTheDefaultAreas(t *testing.T) {
	for _, country := range []string{"", "Senegal", "Ethiopia", "Tanzania", "Nowhere"} {
		t.Run(country, func(t *testing.T) {
			areas := CoachingAreasFor(country)

			if len(areas) != len(defaultAreaKeys) {
				t.Fatalf("expected %d areas, got %d", len(defaultAreaKeys), len(areas))
			}
			for i, want := range defaultAreaKeys {
				if areas[i].Key != want {
					t.Errorf("area %d: expected %q, got %q", i, want, areas[i].Key)
				}
			}

			if HasPriorityCoachingAreas(country) {
				t.Error("unconfigured country must not report priority areas")
			}
		})
	}
}

// The generated prompt for an unconfigured country must still name the three
// original areas, with their original briefs.
func TestDefaultPromptKeepsOriginalCoachingWording(t *testing.T) {
	prompt := promptForCountry("en", AudienceTeacher, "Senegal")

	mustContain := []string{
		"Analyze the lesson through the lens of cognitive science.",
		"**1. Clarity and Cognitive Load**",
		"Did the teacher manage cognitive load effectively? Was instruction clear?",
		"**2. Student Engagement and Retrieval Practice**",
		"Were students actively engaged? Did they practice retrieving information?",
		"**3. Feedback and Metacognition**",
		"Was feedback timely and actionable? Did students reflect on their learning?",
		// The worked example is part of the original prompt and must survive.
		`"pros": "You used clear language..."`,
	}
	for _, want := range mustContain {
		if !strings.Contains(prompt, want) {
			t.Errorf("default prompt lost: %q", want)
		}
	}

	for _, key := range defaultAreaKeys {
		if !strings.Contains(prompt, `"`+key+`"`) {
			t.Errorf("default prompt does not emit key %q", key)
		}
	}
}

func TestBrazilUsesPrioritySkills(t *testing.T) {
	areas := CoachingAreasFor("Brazil")

	if len(areas) != 2 {
		t.Fatalf("expected 2 priority areas, got %d", len(areas))
	}
	if areas[0].Key != "checks_understanding" || areas[1].Key != "feedback" {
		t.Fatalf("unexpected priority areas: %q, %q", areas[0].Key, areas[1].Key)
	}
	if !HasPriorityCoachingAreas("Brazil") {
		t.Error("Brazil must report priority areas")
	}
}

func TestBrazilPromptReplacesTheDefaultAreas(t *testing.T) {
	prompt := promptForCountry("pt", AudienceCoordinator, "Brazil")

	for _, want := range []string{
		"**1. Checking for Understanding**",
		"**2. Giving Feedback**",
		`"checks_understanding"`,
		`"feedback"`,
		"priorit", // the programme-priorities intro line
	} {
		if !strings.Contains(prompt, want) {
			t.Errorf("Brazil prompt missing: %q", want)
		}
	}

	// The defaults must be gone entirely — leaving them would ask for five areas.
	for _, key := range defaultAreaKeys {
		if strings.Contains(prompt, key) {
			t.Errorf("Brazil prompt still names default area %q", key)
		}
	}
	if strings.Contains(prompt, "lens of cognitive science") {
		t.Error("Brazil prompt kept the cognitive-science framing")
	}
	// A clarity example under "Checking for Understanding" would invite the
	// model to write about the wrong subject.
	if strings.Contains(prompt, "You used clear language...") {
		t.Error("Brazil prompt reused the clarity worked example")
	}
}

// Every configured area must produce a syntactically plausible example entry,
// otherwise the model has no shape to imitate.
func TestCoachingAreaExampleRendersForEveryArea(t *testing.T) {
	for _, country := range []string{"Senegal", "Brazil"} {
		prompt := promptForCountry("en", AudienceTeacher, country)
		for _, area := range CoachingAreasFor(country) {
			snippet := `"` + area.Key + `": {`
			if !strings.Contains(prompt, snippet) {
				t.Errorf("%s: example missing entry for %q", country, area.Key)
			}
		}
		if strings.Contains(prompt, "{{COACHING_AREAS") {
			t.Errorf("%s: unresolved coaching-area placeholder", country)
		}
	}
}
