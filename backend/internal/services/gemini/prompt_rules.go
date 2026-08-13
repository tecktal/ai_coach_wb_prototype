// prompt_rules.go
package gemini

// Shared prompt fragments used by more than one generated artefact.
//
// The TEACH analysis (teach_analysis_prompt.go) and the coaching script
// (coach_script_prompt.go) must phrase things identically — a coordinator reads
// both in the same sitting, and wording that drifts between them reads as two
// different tools. Keep the rules here, referenced from both, rather than
// restated in each prompt.

// CoordinatorVoiceRules is the B1 instruction set: who is reading, and how to
// address the teacher who is not.
//
// Requested by the Mato Grosso (Brazil) TEACH coordinators, who read the
// feedback to lead a conversation rather than being its subject.
const CoordinatorVoiceRules = `**👥 WHO IS READING THIS — CRITICAL**: This is read by a PEDAGOGY COORDINATOR who
observed the lesson and will discuss it with the teacher who taught it. The teacher is NOT
the reader.
- Write about the teacher in the THIRD PERSON ("the teacher", "she", "he").
- NEVER address the teacher as "you". Do not write "You used..." or "You should...".
- Lead with the observed evidence, then what it suggests.
- Frame suggestions as OPENINGS FOR A CONVERSATION, not instructions to carry out:
  "a way in could be...", "worth exploring together...", "a question to ask her...".
- Do NOT write a script for the coordinator to read aloud, and do not tell the
  coordinator what to say. Give them the material; they lead the conversation.
- Ground everything in a specific moment from the lesson.`

// NonJudgementalRules is the B3 instruction set, applied regardless of who is
// reading — a teacher should not read "you failed to" either.
const NonJudgementalRules = `**🧭 NON-JUDGEMENTAL LANGUAGE — MANDATORY IN ALL TEXT**: A human reads this feedback,
and in some settings a coach reads it aloud to the teacher it describes. Describe what
was and was not audible. Do not pass judgement on the teacher as a person.
FORBIDDEN wording anywhere in your output — rationale, evidence, limitations, feedback:
  "failed to", "did not bother", "neglected", "should have", "poorly", "incorrectly",
  "wrong", "bad", "weak teaching", "missed the opportunity"
Rewrite deficit statements as neutral observations:
  ❌ "The teacher failed to check understanding."
  ✅ "No individual checks for understanding were audible."
  ❌ "She should have used more examples."
  ✅ "One representation was used: spoken explanation."
  ❌ "Students didn't participate correctly."
  ✅ "Responses were choral; individual responses were not audible."
This changes WORDING ONLY. It does not soften scoring — a low score stated neutrally is
still a low score.`

// TeacherVoiceRules is the original single-audience instruction, kept verbatim so
// existing deployments see no change.
const TeacherVoiceRules = `**USE SECOND PERSON**: This analysis is read by the teacher who taught the lesson.
   Address the teacher directly as "You".`
