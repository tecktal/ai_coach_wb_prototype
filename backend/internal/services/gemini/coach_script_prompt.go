// coach_script_prompt.go
package gemini

import "fmt"

// CoachScriptResult is the seven-block conversation guide the model returns.
//
// The blocks and their order are the Mato Grosso coordinators' own structure:
// observed evidence → what it means → coach question → follow-ups →
// possible model → practice → next step.
type CoachScriptResult struct {
	ObservedEvidence  []string `json:"observed_evidence"`
	WhatItMeans       string   `json:"what_it_means"`
	CoachQuestion     string   `json:"coach_question"`
	FollowUpQuestions []string `json:"follow_up_questions"`
	PossibleModel     string   `json:"possible_model"`
	Practice          string   `json:"practice"`
	NextStep          string   `json:"next_step"`
}

// GetCoachScriptPrompt builds the prompt for one TEACH element.
//
// [elementAnalysisJSON] is the stored analysis for that element — its behaviours,
// evidence quotes and rationale. The lesson audio is not needed: everything the
// script draws on was already extracted during the TEACH analysis.
//
// The result is always coordinator-voiced. A coaching script exists to be used
// by a coach; there is no teacher-facing variant.
func GetCoachScriptPrompt(elementLabel, subject, gradeLevel, elementAnalysisJSON, language string) string {
	if subject == "" {
		subject = "unspecified"
	}
	if gradeLevel == "" {
		gradeLevel = "unspecified"
	}

	prompt := fmt.Sprintf(`You are preparing a pedagogy coordinator for a coaching conversation with a teacher whose lesson they observed.

FOCAL SKILL: %s
Subject: %s
Grade level: %s

Below is the TEACH analysis for this one skill — the behaviours assessed, the evidence heard in the recording, and the rationale. Build the coaching conversation from THIS evidence. Do not invent moments that are not in it.

--- ANALYSIS FOR THE FOCAL SKILL ---
%s
--- END ANALYSIS ---

%s

%s

## YOUR TASK — SEVEN BLOCKS

Produce exactly seven blocks. Each has a distinct job; do not blur them together.

**1. observed_evidence** — What was actually heard, as an array of short factual items.
   Quote the lesson where a quote exists, with its timestamp. Nothing inferred, nothing
   interpreted — this block is the shared ground the conversation stands on. 2-5 items.
   If the analysis contains little evidence for this skill, say so plainly in one item
   rather than padding the list. Never invent evidence.

**2. what_it_means** — A formative reading of that evidence: what it suggests about this
   area of practice in this lesson. Not a verdict on the teacher, and not a score.
   2-3 sentences.

**3. coach_question** — ONE open question the coordinator asks to OPEN the conversation.
   It must be genuinely open (no yes/no), non-leading, and invite the teacher's own
   thinking about a specific moment. This is the single most important line in the whole
   script — the coordinator says it out loud first.

**4. follow_up_questions** — 2 to 4 further open questions to go deeper, depending where
   the teacher takes it. Each should follow naturally from a different possible response.
   Array of strings.

**5. possible_model** — What stronger practice could look like, concretely, IN THIS
   LESSON with this content and this grade level. Describe the practice, do not instruct
   the teacher to adopt it. 2-4 sentences.

**6. practice** — Something specific the coordinator and teacher can rehearse together
   during the conversation, in a few minutes, before the coordinator leaves. Make it
   small enough to actually do. 1-3 sentences.

**7. next_step** — ONE commitment the teacher could take into the next lessons, specific
   enough that the coordinator can check it at the next visit. 1-2 sentences.

## HOW TO WRITE

- The coordinator is your reader. The teacher is the subject, in the third person.
- Give material for a conversation, not a script to read aloud.
- Be concrete. "Ask about the moment at 4:10 when the class answered together" beats
  "ask about student engagement".
- Keep the whole response under 500 words. A coordinator reads this on a phone,
  standing in a corridor, before walking into a classroom.

## OUTPUT FORMAT

Return a SINGLE JSON object with EXACTLY these keys and no others:

{
  "observed_evidence": ["Short factual item with quote (04:10)", "Second item (07:22)"],
  "what_it_means": "2-3 sentences reading that evidence.",
  "coach_question": "One open question to start the conversation.",
  "follow_up_questions": ["Deeper question 1", "Deeper question 2", "Deeper question 3"],
  "possible_model": "What stronger practice could look like in this lesson.",
  "practice": "Something to rehearse together now.",
  "next_step": "One checkable commitment for next time."
}

CRITICAL:
- Output ONLY the JSON object. No preamble, no markdown fences, no commentary.
- Every value is a plain string; the two array fields contain plain strings.
- Keep timestamps INSIDE the string quotes: "Quote (04:10)" — never outside them.
- Do not add keys. Do not omit keys.`,
		elementLabel, subject, gradeLevel, elementAnalysisJSON,
		CoordinatorVoiceRules, NonJudgementalRules)

	languageLabel := languageName(language)
	return prompt + fmt.Sprintf(
		"\n\nCRITICAL INSTRUCTION: Write every string value in the **%s** language. "+
			"The JSON keys MUST remain exactly as specified in English.",
		languageLabel,
	)
}
