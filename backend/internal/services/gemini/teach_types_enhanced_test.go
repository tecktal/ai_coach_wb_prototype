package gemini

import "testing"

// TestResolveElement_ExactKey covers the happy path: the model emitted the
// canonical key exactly as the prompt requested.
func TestResolveElement_ExactKey(t *testing.T) {
	elements := map[string]ElementAnalysis{
		"checks_understanding": {Score: 4, Rationale: "exact"},
	}

	el, found := ResolveElement(elements, "checks_understanding")
	if !found {
		t.Fatal("expected to find element by its canonical key")
	}
	if el.Score != 4 || el.Rationale != "exact" {
		t.Fatalf("wrong element returned: %+v", el)
	}
}

// TestResolveElement_KnownAliases is the regression test for the defect this
// resolver exists to prevent: the prompt used to ask for these longer key names
// while the handler looked up the canonical ones, so three of the nine TEACH
// elements were silently dropped on every analysis.
func TestResolveElement_KnownAliases(t *testing.T) {
	cases := []struct {
		alias     string
		canonical string
	}{
		{"positive_behavioral_expectations", "positive_expectations"},
		{"positive_behavioural_expectations", "positive_expectations"},
		{"checks_for_understanding", "checks_understanding"},
		{"checking_for_understanding", "checks_understanding"},
		{"social_collaborative_skills", "social_collaborative"},
		{"social_and_collaborative_skills", "social_collaborative"},
	}

	for _, tc := range cases {
		t.Run(tc.alias, func(t *testing.T) {
			elements := map[string]ElementAnalysis{
				tc.alias: {Score: 3, Rationale: "aliased"},
			}

			el, found := ResolveElement(elements, tc.canonical)
			if !found {
				t.Fatalf("alias %q did not resolve to canonical key %q", tc.alias, tc.canonical)
			}
			if el.Score != 3 {
				t.Fatalf("wrong element returned for alias %q: %+v", tc.alias, el)
			}
		})
	}
}

// TestResolveElement_NormalizedKey covers cosmetic variation in casing and
// separators, which the model produces intermittently.
func TestResolveElement_NormalizedKey(t *testing.T) {
	cases := []string{
		"Checks Understanding",
		"checks-understanding",
		"ChecksUnderstanding",
		"Checks_For_Understanding", // alias + cosmetic variation together
	}

	for _, key := range cases {
		t.Run(key, func(t *testing.T) {
			elements := map[string]ElementAnalysis{key: {Score: 2}}

			el, found := ResolveElement(elements, "checks_understanding")
			if !found {
				t.Fatalf("key %q did not normalize to canonical key", key)
			}
			if el.Score != 2 {
				t.Fatalf("wrong element returned for key %q: %+v", key, el)
			}
		})
	}
}

// TestResolveElement_Missing asserts the resolver reports a miss rather than
// inventing a default. The caller depends on found=false to store a NULL score;
// returning a zero-value element with found=true would recreate the original bug
// in a new form.
func TestResolveElement_Missing(t *testing.T) {
	elements := map[string]ElementAnalysis{
		"supportive_environment": {Score: 5},
	}

	if _, found := ResolveElement(elements, "checks_understanding"); found {
		t.Fatal("expected found=false for an element the model omitted")
	}

	if _, found := ResolveElement(nil, "feedback"); found {
		t.Fatal("expected found=false for a nil elements map")
	}

	if _, found := ResolveElement(map[string]ElementAnalysis{}, "feedback"); found {
		t.Fatal("expected found=false for an empty elements map")
	}
}

// TestResolveElement_NoCrossElementMatching guards the normalization step from
// over-matching. "feedback" and "feedback_and_metacognition" must stay distinct,
// otherwise a Science-of-Learning key could satisfy a TEACH element lookup.
func TestResolveElement_NoCrossElementMatching(t *testing.T) {
	elements := map[string]ElementAnalysis{
		"feedback_and_metacognition": {Score: 5},
		"autonomy_support":           {Score: 5},
	}

	if _, found := ResolveElement(elements, "feedback"); found {
		t.Fatal("`feedback_and_metacognition` must not resolve as `feedback`")
	}
	if _, found := ResolveElement(elements, "autonomy"); found {
		t.Fatal("`autonomy_support` must not resolve as `autonomy`")
	}
}

// TestCanonicalElementsMatchDatabaseColumns pins the canonical list. These names
// are load-bearing in the analyses table columns, the Excel exporter and the
// monitoring dashboard (src/lib/teach.ts) — changing one without changing the
// others silently breaks a consumer.
func TestCanonicalElementsMatchDatabaseColumns(t *testing.T) {
	want := []string{
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

	if len(CanonicalElements) != len(want) {
		t.Fatalf("expected %d TEACH elements, got %d", len(want), len(CanonicalElements))
	}
	for i, name := range want {
		if CanonicalElements[i] != name {
			t.Errorf("element %d: expected %q, got %q", i, name, CanonicalElements[i])
		}
	}
}

// TestElementAliasesPointAtCanonicalKeys catches a typo'd alias target, which
// would otherwise fail silently at runtime exactly like the original defect.
func TestElementAliasesPointAtCanonicalKeys(t *testing.T) {
	canonical := make(map[string]bool, len(CanonicalElements))
	for _, name := range CanonicalElements {
		canonical[name] = true
	}

	for alias, target := range elementAliases {
		if !canonical[target] {
			t.Errorf("alias %q points at %q, which is not a canonical element", alias, target)
		}
		if canonical[alias] {
			t.Errorf("alias %q is itself a canonical element name", alias)
		}
	}
}
