// programme.go
package gemini

// Per-deployment configuration of the coaching section.
//
// By default the analysis closes with three cognitive-science areas ("Science of
// Learning"). Mato Grosso asked for that section to speak instead to the two
// teaching practices their state is driving, so which areas get generated is a
// property of the programme rather than a constant.
//
// Country-gated rather than role-gated: priority skills are what the *state* is
// driving, so a Brazilian teacher using the app directly should be coached on
// them too.

// CoachingArea is one section of the coaching analysis.
type CoachingArea struct {
	// Key is the JSON key under `science_of_learning`, and by convention the
	// suffix of the app's label key (`coachArea_<Key>`). Never translated.
	Key string

	// Label is the English name the model is told it is writing about.
	Label string

	// Focus is the one-line brief for that area, written as the questions the
	// model should be answering.
	Focus string
}

// DefaultCoachingAreas reproduces the original Science of Learning section
// exactly — keys, labels and briefs — so every deployment that has not been
// configured otherwise is unaffected.
//
// Do not reword without updating the regression test in programme_test.go: these
// three keys are what every analysis stored before B4 contains, and what
// Ethiopia and Senegal still generate.
var DefaultCoachingAreas = []CoachingArea{
	{
		Key:   "clarity_and_cognitive_load",
		Label: "Clarity and Cognitive Load",
		Focus: "Did the teacher manage cognitive load effectively? Was instruction clear?",
	},
	{
		Key:   "student_engagement_and_retrieval_practice",
		Label: "Student Engagement and Retrieval Practice",
		Focus: "Were students actively engaged? Did they practice retrieving information?",
	},
	{
		Key:   "feedback_and_metacognition",
		Label: "Feedback and Metacognition",
		Focus: "Was feedback timely and actionable? Did students reflect on their learning?",
	},
}

// programmeCoachingAreas overrides the default for a specific deployment.
//
// Keys are country names as they appear in the app's country dropdown — the same
// spelling `CountryCustomization` uses for language and coordinator gating.
var programmeCoachingAreas = map[string][]CoachingArea{
	// Mato Grosso, Brazil: the two skills the state prioritises. Both map onto
	// TEACH elements the app already scores, so the coaching section and the
	// framework scores talk about the same practices.
	"Brazil": {
		{
			Key:   "checks_understanding",
			Label: "Checking for Understanding",
			Focus: "How did the teacher find out what students had understood? Were checks individual or only choral? Did the teacher act on what the checks revealed?",
		},
		{
			Key:   "feedback",
			Label: "Giving Feedback",
			Focus: "Was feedback specific rather than general praise? Did it name what the student did? Did students get feedback on misunderstandings as well as on successes?",
		},
	},
}

// CoachingAreasFor returns the areas configured for a country, or the default
// three when the country has no configuration.
func CoachingAreasFor(country string) []CoachingArea {
	if areas, ok := programmeCoachingAreas[country]; ok {
		return areas
	}
	return DefaultCoachingAreas
}

// HasPriorityCoachingAreas reports whether a country overrides the default —
// used by the app to decide whether to show a priority-skills heading.
func HasPriorityCoachingAreas(country string) bool {
	_, ok := programmeCoachingAreas[country]
	return ok
}
