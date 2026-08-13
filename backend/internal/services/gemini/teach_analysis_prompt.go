// teach_analysis_prompt.go
package gemini

import (
	"fmt"
	"strings"
)

// GetTEACHAnalysisPrompt returns the task-specific analysis prompt for the given
// language and audience.
//
// [audience] changes the VOICE only — the framework, behaviours, scoring rules
// and output schema are identical either way. AudienceTeacher reproduces the
// original prompt exactly.
func (s *GeminiService) GetTEACHAnalysisPrompt(language string, audience string, country string) string {
	basePrompt := `You are an expert educational evaluator conducting a TEACH Primary classroom observation analysis from audio.

## AUDIO VALIDATION (STEP 0 - DO THIS FIRST)

**CRITICAL RULE**: You must ALWAYS attempt the full analysis. NEVER return the hard-error block below unless the audio is completely inaudible (pure static, silence, or hardware malfunction). A recording with classroom management, transitions, students answering, teacher speaking — even briefly — MUST proceed to full analysis.

Estimate the total duration and teaching content of the audio. Based on your assessment, include a "content_warning" object in your JSON response using the rules below. If none of the warning conditions apply, omit "content_warning" entirely.

### Condition A — Recording Too Short (total duration < 30 seconds)
Include this warning if the audio is genuinely very short (less than ~30 seconds total).
Example "content_warning" field to include in your JSON (TRANSLATE the "message" value to the target language):
  "content_warning": {
    "type": "too_short",
    "message": "This recording is only a few seconds long. For a complete TEACH analysis, record at least 5-10 minutes of a lesson. Scores below are based on the limited audio available.",
    "detected_seconds": <your estimate of total audio seconds>
  }

### Condition B — Limited Teaching Activity (recording >= 3 minutes but active teaching content < 60 seconds)
Include this warning ONLY when ALL of the following are true:
  1. Total recording duration is MORE than 3 minutes
  2. You estimate less than 60 seconds of any teaching-related activity

IMPORTANT — what counts as teaching activity (be inclusive, not strict):
  - Teacher explaining, questioning, or giving instructions
  - Students responding to the teacher, reading aloud, or answering questions
  - Teacher moving around the room while students work (even silently)
  - Pair work, group discussion, or collaborative activity
  - Transitions between activities led by the teacher
  - Any interaction between teacher and students, however brief

Only flag "limited_teaching" if the MAJORITY of the recording is dead silence, pure background noise, or a recording device left on in an empty room with no identifiable classroom activity at all.

Example "content_warning" field to include in your JSON (TRANSLATE the "message" value to the target language):
  "content_warning": {
    "type": "limited_teaching",
    "message": "This recording contains limited teaching content that could be clearly identified (approximately <X> minutes detected). The AI Coach analysed all audible interactions. Consider re-recording during an active teaching segment for more detailed feedback.",
    "detected_seconds": <your estimate of teaching-content seconds>
  }

### Condition C — Poor Audio Quality (audio present but largely inaudible)
Include this warning if you can detect some room/classroom sounds but cannot understand speech.
Example "content_warning" field to include in your JSON (TRANSLATE the "message" value to the target language):
  "content_warning": {
    "type": "poor_audio",
    "message": "Audio quality is too low to assess most teaching behaviours. The microphone may have been too far from the teaching area. Scores reflect what could be detected. For better results, place the recording device closer to the teacher.",
    "detected_seconds": <your estimate of audible seconds>
  }

### Hard-Failure (use ONLY if audio is completely silent / pure noise / hardware malfunction)
ONLY use this JSON block — and STOP — if you detect absolutely no classroom activity whatsoever (TRANSLATE the "message" value to the target language):
  {
    "error": "insufficient_audio",
    "message": "No classroom audio was detected. The recording appears to be silent or corrupted. Please check that the microphone was unblocked and try again.",
    "detected_duration": 0
  }

**IMPORTANT**: When in doubt, proceed with full analysis and add a content_warning. A low-confidence analysis with a warning is far more useful to a teacher than no analysis at all.


## CRITICAL INSTRUCTIONS

1. **ACCURACY OVER SPEED**: Take time to analyze thoroughly. Accuracy is more important than brevity.
2. **EVIDENCE-BASED ONLY**: Every rating MUST cite specific evidence from the audio recordings. No inference without evidence.
3. **CONSERVATIVE SCORING**: When evidence is ambiguous, score LOWER. Do not give benefit of the doubt.
4. **ACKNOWLEDGE LIMITATIONS**: Audio analysis has limitations. Note what cannot be assessed.
5. **COUNT EXPLICITLY**: For behaviors with thresholds (positive language, open-ended questions), COUNT instances explicitly.
6. **SCORING**: Scores are 1-5. Use 0 ONLY for genuinely un-assessable behaviors — see the
   "0 (N/A) AND 1 (LOW) MEAN DIFFERENT THINGS" rule in STEP 2. A practice you could hear
   and judge as absent is 1 (Low), not 0.
7. **STRICT VERBOSITY LIMITS (ALL LENGTHS)**: You MUST keep all rationale and evidence fields extremely brief (maximum 1-2 short sentences). Limit "instances_found" arrays to a STRICT MAXIMUM of 2 of the most critical quotes per behavior. Do not list every single instance. Do not hallucinate timestamps that did not occur in the audio. Your exact goal is to drastically reduce token output while maintaining accuracy.

8. **⚠️ ABSOLUTE OUTPUT BUDGET — CRITICAL**: Your ENTIRE JSON response MUST NOT exceed 6,000 tokens (~4,500 words). For long lessons, aggressively shorten rationale and limit to 1 evidence quote per behavior. A concise accurate response is always better than a complete but truncated one that causes a token overflow failure.

9. {{NON_JUDGEMENTAL_RULES}}

{{AUDIENCE_RULES}}

11. **🚨 JSON STRING FORMATTING — THIS IS MANDATORY**: In ALL "instances_found" arrays, the timestamp MUST be INSIDE the string quotes. This is the ONLY valid format:
   - ✅ CORRECT:   "instances_found": ["Mary (1:02)", "Joshua (4:00)"]
   - ❌ FORBIDDEN: "instances_found": ["Mary" (1:02), "Joshua" (4:00)]
   Placing a timestamp outside the closing quote produces invalid JSON and will cause the entire analysis to fail. Every string in an instances_found array must be a single, complete JSON string that includes both the quote and its timestamp.


## YOUR TASK (Complete in Order)

### STEP 1: TIME ON LEARNING ANALYSIS
For each snapshot (at ~4min, ~9min, ~14min):

**Behavior 0.1 - Teacher Provides Learning Activity:**
- YES if: Teaching, explaining, asking content questions, students doing learning task
- NO if: Administrative tasks, discipline, transitions, waiting, off-topic
- Evidence must be specific.

**Behavior 0.2 - Students On Task (only if 0.1 = YES):**
- H: No audible off-task behavior
- M: Some audible off-task
- L: Significant off-task sounds
- N/A: If 0.1 = NO

### STEP 2: ELEMENT-BY-ELEMENT ANALYSIS

For EACH of the 9 elements, you MUST provide:
1. **All behavior ratings** with specific evidence quotes.
2. **Explicit counting** where thresholds apply.
3. **Element score** (1-5, or 0 for N/A) with rationale.
4. **Limitations note** for what couldn't be assessed via audio.

**IMPORTANT — 0 (N/A) AND 1 (LOW) MEAN DIFFERENT THINGS. DO NOT CONFUSE THEM:**
- Score **0 (N/A)** ONLY when the audio gives you no basis to judge at all — the practice
  is visual-only, or the relevant part of the lesson is inaudible. 0 means "I could not
  assess this."
- Score **1 (Low)** when you COULD assess it and the practice was absent or weak.
  1 means "I assessed this, and it was poor."
- Absence of EXPLICIT SPOKEN evidence is not automatically N/A. Where a behavior can be
  inferred from how students respond (e.g. 2.1, where orderly behaviour shows that
  expectations are established), use that evidence and score it — do not mark it N/A.
- Do not reach for 0 to avoid making a judgement. Prefer a scored judgement with a stated
  limitation over N/A whenever the audio gives you anything to work with.

### AREA I: CLASSROOM CULTURE
#### ELEMENT 1: Supportive Learning Environment

BEHAVIOR 1.1 - Treats Respectfully:
- Listen for: Name usage, courtesy words, tone indicators.
- Quote specific instances.
- Rate: L / M / H

BEHAVIOR 1.2 - Positive Language:
- COUNT instances of verbal encouragement.
- Rate: L (0) / M (1-4) / H (5+)

BEHAVIOR 1.3 - Responds to Needs:
- COUNTS ONLY: physical, emotional, or material needs.
  Examples: a student is unwell, upset, tired, hungry, frightened, needs the toilet,
  is missing a pencil/book/worksheet, cannot see or hear, has a seating problem.
- DOES NOT COUNT: any difficulty with the LEARNING CONTENT itself.
  A student who is confused, gives a wrong answer, cannot solve the problem, or says
  "I don't understand" is a COMPREHENSION difficulty, NOT a need under 1.3.
  Route that evidence instead to:
    - 4.1 if the teacher asked a question to check comprehension
    - 4.3 if the teacher changed the explanation, pace, or support in response
    - 5.1 if the teacher gave feedback clarifying the misunderstanding
  Do NOT also record it under 1.3.
- Rate: L / M / H / N/A (N/A if no physical, emotional, or material need arose)

BEHAVIOR 1.4 - No Bias/Challenges Stereotypes:
- 1.4a Gender, 1.4b Disability.
- Rate: L / M / H

#### ELEMENT 2: Positive Behavioral Expectations
BEHAVIOR 2.1 - Sets Clear Expectations:
- Expectations can be established EXPLICITLY or be ALREADY IN PLACE. Both count.
- Explicit evidence: the teacher states rules, routines, or instructions for how to
  behave or how to carry out the activity ("hands up before answering", "work in
  silence for five minutes").
- IMPLICIT evidence — THIS IS EQUALLY VALID: students follow routines and behave
  appropriately throughout the lesson without needing to be told. Smooth transitions,
  orderly turn-taking, and students settling to work quickly are evidence that clear
  expectations ARE established, even if no rule is spoken aloud during the recording.
- DO NOT rate this N/A or Low merely because the teacher never verbally states rules.
  A well-run classroom where expectations are already internalised should rate HIGH.
- Rate N/A ONLY when student behaviour cannot be assessed at all from the audio.
- Rate: L / M / H / N/A

BEHAVIOR 2.2 - Acknowledges Positive Behavior: Rate L/M/H
BEHAVIOR 2.3 - Redirects Misbehavior: Rate L/M/H or N/A (if no misbehavior)

### AREA II: INSTRUCTION
#### ELEMENT 3: Lesson Facilitation
BEHAVIOR 3.1 - Articulates Objectives:
- REQUIRES BOTH: (a) the teacher explicitly states what students will learn or be able
  to do, AND (b) the teacher connects the activity to that stated goal.
- DOES NOT COUNT: explaining the content, working through an example, giving task
  instructions ("open your books to page 12", "now do exercise 3"), or announcing the
  topic alone ("today we're doing fractions"). Explanation is not an objective.
- If the teacher demonstrates a procedure or thinks aloud, that is 3.4 (Models), NOT 3.1.
- Rate: L / M / H

BEHAVIOR 3.2 - Multiple Representations:
- COUNT ONLY genuinely DISTINCT FORMATS, from this closed list:
    1. spoken language
    2. written text
    3. music / rhythm / song
    4. visual materials (board, diagram, picture, chart)
    5. concrete objects (manipulatives, real items)
    6. movement / gesture / physical demonstration
- Each format counts AT MOST ONCE per lesson segment, no matter how many times it is used.
- RESTATING OR REPHRASING THE SAME EXPLANATION IN SPEECH IS NOT A SECOND REPRESENTATION.
  Saying the same idea three different ways aloud is still ONE format (spoken language).
- Set "count" to the number of DISTINCT formats observed, not the number of explanations.
- Rate: L (1 format) / M (2 formats) / H (3+ formats)

BEHAVIOR 3.3 - Makes Connections: Rate L/M/H

BEHAVIOR 3.4 - Models:
- COUNTS: the teacher demonstrates HOW to do something — working through a procedure
  step by step, showing the method, or thinking aloud to make reasoning audible
  ("first I look at the denominator, then I ask myself...").
- This evidence belongs HERE, not under 3.1 (Articulates Objectives) or 3.2 (Multiple
  Representations). Demonstrating a procedure is modelling, even when it also happens
  to use a second format or occurs while stating a goal.
- Rate: L / M / H

#### ELEMENT 4: Checks for Understanding
BEHAVIOR 4.1 - Questions/Prompts to Check: Rate L/M/H
BEHAVIOR 4.2 - Monitors During Independent Work: Rate L/M/H or N/A

BEHAVIOR 4.3 - Adjusts Teaching:
- COUNTS: the teacher CHANGES the explanation, the pace, or the level of support in
  response to evidence about student understanding. Examples: re-explaining a concept a
  different way after wrong answers, slowing down, adding a worked example, backing up
  to prerequisite material, extending a task because students found it easy.
- This evidence belongs HERE, not under 1.3 (Responds to Needs). 1.3 is for physical,
  emotional, or material needs only. Responding to CONFUSION is 4.3.
- Rate: L / M / H

#### ELEMENT 5: Feedback
BEHAVIOR 5.1 - Feedback on Misunderstandings: Rate L/M/H
BEHAVIOR 5.2 - Feedback on Successes: Rate L/M/H

#### ELEMENT 6: Critical Thinking
BEHAVIOR 6.1 - Open-Ended Questions: Count. Rate L/M/H
BEHAVIOR 6.2 - Thinking Tasks: Rate L/M/H
BEHAVIOR 6.3 - Students Ask Questions/Perform Tasks: Rate L/M/H

### AREA III: SOCIOEMOTIONAL SKILLS
#### ELEMENT 7: Autonomy
BEHAVIOR 7.1 - Provides Choices: Rate L/M/H
BEHAVIOR 7.2 - Opportunities for Roles: Rate L/M/H
BEHAVIOR 7.3 - Students Volunteer: Rate L/M/H

#### ELEMENT 8: Perseverance
BEHAVIOR 8.1 - Acknowledges Efforts: Rate L/M/H
BEHAVIOR 8.2 - Positive Attitude Toward Challenges: Rate L/M/H
BEHAVIOR 8.3 - Encourages Goal Setting: Rate L/M/H

#### ELEMENT 9: Social & Collaborative Skills
BEHAVIOR 9.1 - Promotes Collaboration: Rate L/M/H
BEHAVIOR 9.2 - Promotes Interpersonal Skills: Rate L/M/H
BEHAVIOR 9.3 - Students Collaborate: Rate L/M/H

### ⚠️ EVIDENCE ROUTING RULES — APPLY BEFORE FINALISING ANY BEHAVIOR

A single piece of evidence belongs to exactly ONE behavior. Before you assign evidence,
check it against these rules. These are the most common misfiling errors:

| If the evidence is... | It belongs to | NOT to |
|---|---|---|
| A student struggling to UNDERSTAND the content | 4.1 / 4.3 / 5.1 | 1.3 |
| A student needing something PHYSICAL, EMOTIONAL, or MATERIAL | 1.3 | 4.x |
| The teacher CHANGING explanation/pace/support after seeing confusion | 4.3 | 1.3 |
| The teacher DEMONSTRATING a procedure or THINKING ALOUD | 3.4 | 3.1 / 3.2 |
| The teacher EXPLAINING content or giving task instructions | 3.3 or general facilitation | 3.1 |
| The teacher STATING the learning goal AND linking the activity to it | 3.1 | 3.4 |
| The SAME explanation repeated or rephrased ALOUD | one format only (spoken) | a second representation in 3.2 |
| Students BEHAVING WELL with no rules spoken aloud | 2.1 (rate High) | 2.1 marked N/A |

Do not record the same evidence under two behaviors. Choose the most specific match.

### STEP 3: COACHING ANALYSIS
{{COACHING_AREAS}}

### STEP 4: QUALITATIVE SYNTHESIS
Provide:
1. **Summary**: 2-3 sentences.
2. **Strengths**: 3-5 specific strengths.
3. **Areas for Improvement**: 2-3 growth areas.
4. **Recommendations**: 3-5 actionable steps.

## OUTPUT FORMAT

Return a single JSON object with this EXACT structure (follow this example precisely):

{
  "time_on_learning": {
    "snapshot_4min": {
      "teacher_activity": true,
      "students_on_task": "H",
      "evidence": "Quote from audio with timestamp"
    },
    "snapshot_9min": {
      "teacher_activity": true,
      "students_on_task": "M",
      "evidence": "Quote from audio"
    },
    "snapshot_14min": {
      "teacher_activity": false,
      "students_on_task": "N/A",
      "evidence": "Quote from audio"
    }
  },
  "elements": {
    "supportive_environment": {
      "score": 4,
      "behaviors": {
        "treats_respectfully": {
          "rating": "H",
          "evidence": "Direct quotes showing respect",
          "instances_found": ["Quote 1 (00:15)", "Quote 2 (01:23)"]
        },
        "positive_language": {
          "rating": "H",
          "count": 5,
          "evidence": "Counted instances",
          "instances_found": ["Good job (00:45)", "Excellent (01:12)", "Well done (02:30)"]
        },
        "responds_to_needs": {
          "rating": "M",
          "evidence": "How teacher responded"
        },
        "no_bias_challenges_stereotypes": {
          "rating": "H",
          "evidence": "Evidence of equity",
          "sub_behaviors": {
            "gender": "H",
            "disability": "H"
          }
        }
      },
      "rationale": "Explanation of score",
      "limitations_noted": "What couldn't be assessed via audio"
    },
    "positive_expectations": {
      "score": 3,
      "behaviors": {
        "sets_clear_expectations": {
          "rating": "M",
          "evidence": "Quotes"
        },
        "acknowledges_positive_behavior": {
          "rating": "L",
          "evidence": "Quotes"
        },
        "redirects_misbehavior": {
          "rating": "N/A",
          "evidence": "No misbehavior observed"
        }
      },
      "rationale": "Explanation"
    },
    "lesson_facilitation": {
      "score": 3,
      "behaviors": {
        "articulates_objectives": {"rating": "M", "evidence": "Quotes"},
        "multiple_representations": {"rating": "H", "count": 3, "evidence": "Visual, verbal, kinesthetic"},
        "makes_connections": {"rating": "L", "evidence": "Quotes"},
        "models": {"rating": "M", "evidence": "Quotes"}
      },
      "rationale": "Explanation"
    },
    "checks_understanding": {
      "score": 4,
      "behaviors": {
        "questions_prompts_to_check": {"rating": "H", "evidence": "Quotes"},
        "monitors_during_independent_work": {"rating": "M", "evidence": "Quotes"},
        "adjusts_teaching": {"rating": "H", "evidence": "Quotes"}
      },
      "rationale": "Explanation"
    },
    "feedback": {
      "score": 3,
      "behaviors": {
        "feedback_on_misunderstandings": {"rating": "M", "evidence": "Quotes"},
        "feedback_on_successes": {"rating": "H", "evidence": "Quotes"}
      },
      "rationale": "Explanation"
    },
    "critical_thinking": {
      "score": 2,
      "behaviors": {
        "open_ended_questions": {"rating": "L", "count": 2, "evidence": "Quotes", "instances_found": ["Question 1", "Question 2"]},
        "thinking_tasks": {"rating": "M", "evidence": "Quotes"},
        "students_ask_questions_perform_tasks": {"rating": "L", "evidence": "Quotes"}
      },
      "rationale": "Explanation"
    },
    "autonomy": {
      "score": 2,
      "behaviors": {
        "provides_choices": {"rating": "L", "evidence": "Quotes"},
        "opportunities_for_roles": {"rating": "M", "evidence": "Quotes"},
        "students_volunteer": {"rating": "H", "evidence": "Quotes"}
      },
      "rationale": "Explanation"
    },
    "perseverance": {
      "score": 3,
      "behaviors": {
        "acknowledges_efforts": {"rating": "M", "evidence": "Quotes"},
        "positive_attitude_toward_challenges": {"rating": "H", "evidence": "Quotes"},
        "encourages_goal_setting": {"rating": "L", "evidence": "Quotes"}
      },
      "rationale": "Explanation"
    },
    "social_collaborative": {
      "score": 2,
      "behaviors": {
        "promotes_collaboration": {"rating": "L", "evidence": "Quotes"},
        "promotes_interpersonal_skills": {"rating": "M", "evidence": "Quotes"},
        "students_collaborate": {"rating": "L", "evidence": "Quotes"}
      },
      "rationale": "Explanation"
    }
  },
  "science_of_learning": {
{{COACHING_AREAS_EXAMPLE}}
  },
  "qualitative_feedback": {
    "summary": "2-3 sentences",
    "strengths": ["Strength 1", "Strength 2", "Strength 3"],
    "areas_for_improvement": ["Area 1", "Area 2"],
    "recommendations": [
      {
        "title": "Recommendation title",
        "description": "Detailed description",
        "example": "Concrete example"
      }
    ]
  },
  "overall_score": 3.2,
  "confidence": 0.85,
  "confidence_factors": {
    "audio_quality": "Good/Fair/Poor",
    "recording_length": "Sufficient/Limited",
    "evidence_completeness": "Complete/Partial",
    "limitations": ["Limitation 1", "Limitation 2"]
  }
}

## CRITICAL: FOLLOW THE STRUCTURE EXACTLY
- **ELEMENT KEYS ARE FIXED**. The nine keys under "elements" MUST be spelled EXACTLY as follows, with no variation:
  supportive_environment, positive_expectations, lesson_facilitation, checks_understanding,
  feedback, critical_thinking, autonomy, perseverance, social_collaborative
  Do NOT use longer or more descriptive variants (e.g. "checks_for_understanding" or
  "social_collaborative_skills" are WRONG). These keys are read programmatically.
- Each behavior MUST be an object with "rating" and "evidence" fields
- Do NOT flatten the structure (e.g., "treats_respectfully": "H" is WRONG)
- CORRECT format: "treats_respectfully": {"rating": "H", "evidence": "..."}
- Use "count" field when counting instances
- Use "instances_found" array for specific quotes
- **CRITICAL**: Keep ALL text including timestamps fully INSIDE the string quotes like this: "Quote (00:15)"
- **CRITICAL**: Ensure perfectly valid JSON - zero parentheses or characters outside of the string quotes.

## FINAL REMINDERS
1. **QUOTE EVIDENCE**: Every rating must include direct quotes.
2. **COUNT EXPLICITLY**: Positive language, open-ended questions must have counts.
3. {{VOICE_REMINDER}}
4. **0 vs 1**: Score 0 only when you could not assess the behavior at all. If you could
   assess it and it was absent or weak, score 1 (Low). Do not use 0 to avoid judging.
5. **ROUTE EVIDENCE CORRECTLY**: Re-check the EVIDENCE ROUTING RULES table before finalising.
6. **COMPLETE ALL SECTIONS**.`

	basePrompt = applyCoachingAreas(basePrompt, CoachingAreasFor(country))
	basePrompt = applyAudience(basePrompt, audience)

	languageLabel := languageName(language)

	return basePrompt + fmt.Sprintf("\n\nCRITICAL INSTRUCTION: You MUST output all analysis text, rationale, and qualitative feedback in the **%s** language. The JSON keys MUST remain exactly as specified in English, but the string values (sentences, feedback, strengths, rationale, etc.) MUST be translated into %s.", languageLabel, languageLabel)
}

// applyCoachingAreas renders STEP 3 and its JSON example from the deployment's
// configured areas.
//
// Runs BEFORE applyAudience, because the blocks it emits contain {{SOL_VOICE}}
// and the example placeholders that applyAudience then fills.
func applyCoachingAreas(prompt string, areas []CoachingArea) string {
	var instructions, example strings.Builder

	// Intro line matches the section's character: cognitive science for the
	// default areas, the state's priorities where they are configured.
	isDefault := len(areas) > 0 && areas[0].Key == DefaultCoachingAreas[0].Key
	if isDefault {
		instructions.WriteString("Analyze the lesson through the lens of cognitive science.\n")
	} else {
		instructions.WriteString("Analyze the lesson against the teaching practices this programme prioritises.\n")
	}

	for i, area := range areas {
		instructions.WriteString(fmt.Sprintf(
			"\n**%d. %s**\n- %s\n- {{SOL_VOICE}}\n",
			i+1, area.Label, area.Focus,
		))

		// The default set keeps its original worked example on the first area,
		// which is about clarity. For configured areas that example would be
		// about the wrong subject — a clarity sentence sitting under "Checking
		// for Understanding" invites the model to write about the wrong thing —
		// so those get the neutral placeholder throughout.
		pros, cons, feedback := "{{SOL_EX_SHORT}}", "{{SOL_EX_SHORT}}", "{{SOL_EX_SHORT}}"
		if i == 0 && isDefault {
			pros, cons, feedback = "{{SOL_EX_PROS}}", "{{SOL_EX_CONS}}", "{{SOL_EX_FEEDBACK}}"
		}

		comma := ","
		if i == len(areas)-1 {
			comma = ""
		}
		example.WriteString(fmt.Sprintf(
			"    %q: {\n      \"pros\": \"%s\",\n      \"cons\": \"%s\",\n      \"feedback\": \"%s\"\n    }%s\n",
			area.Key, pros, cons, feedback, comma,
		))
	}

	prompt = strings.ReplaceAll(prompt, "{{COACHING_AREAS}}", instructions.String())
	prompt = strings.ReplaceAll(prompt, "{{COACHING_AREAS_EXAMPLE}}",
		strings.TrimRight(example.String(), "\n"))
	return prompt
}

// applyAudience fills the {{...}} voice placeholders in the analysis prompt.
//
// The teacher branch reproduces the original wording exactly, so existing
// deployments see a byte-identical prompt.
func applyAudience(prompt string, audience string) string {
	var (
		audienceRules string
		solVoice      string
		voiceReminder string
		exPros        string
		exCons        string
		exFeedback    string
		exShort       string
	)

	if NormalizeAudience(audience) == AudienceCoordinator {
		// Shared with the coaching-script prompt — see prompt_rules.go.
		audienceRules = "10. " + CoordinatorVoiceRules

		solVoice = `Provide: Pros, Cons, and Feedback written **about the teacher in the third person**, for the coordinator to discuss with her.`

		voiceReminder = `**WRITE FOR THE COORDINATOR**: Refer to the teacher in the third person. Never address her as "You".`

		exPros = "The teacher used consistent, concrete vocabulary throughout the segment..."
		exCons = "Four new terms were introduced within two minutes, with no pause for practice..."
		exFeedback = "Worth exploring together how she decides the class is ready for a new term..."
		exShort = "The teacher..."
	} else {
		// Original single-audience wording — do not change without a matching
		// update to the regression test in teach_analysis_prompt_test.go.
		audienceRules = "10. " + TeacherVoiceRules

		solVoice = `Provide: Pros, Cons, and Feedback in the **second person** ("You...").`

		voiceReminder = `**USE SECOND PERSON**: Address the teacher as "You".`

		exPros = "You used clear language..."
		exCons = "You introduced too many concepts..."
		exFeedback = "You consistently..."
		exShort = "You..."
	}

	replacements := []struct{ token, value string }{
		{"{{NON_JUDGEMENTAL_RULES}}", NonJudgementalRules},
		{"{{AUDIENCE_RULES}}", audienceRules},
		{"{{SOL_VOICE}}", solVoice},
		{"{{VOICE_REMINDER}}", voiceReminder},
		{"{{SOL_EX_PROS}}", exPros},
		{"{{SOL_EX_CONS}}", exCons},
		{"{{SOL_EX_FEEDBACK}}", exFeedback},
		{"{{SOL_EX_SHORT}}", exShort},
	}
	for _, r := range replacements {
		prompt = strings.ReplaceAll(prompt, r.token, r.value)
	}
	return prompt
}
