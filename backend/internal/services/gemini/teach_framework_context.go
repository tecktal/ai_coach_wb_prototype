// teach_framework_context.go
package gemini

// GetTEACHFrameworkContext returns the complete TEACH Primary framework reference
// This is the exhaustive context document for the AI agent
func GetTEACHFrameworkContext() string {
    return `# WORLD BANK TEACH PRIMARY FRAMEWORK - COMPLETE REFERENCE
Version: Second Edition (2021)
Purpose: Audio-based classroom observation and teacher evaluation

================================================================================
SECTION 1: FRAMEWORK ARCHITECTURE
================================================================================

## 1.1 Overall Structure
TEACH Primary measures teaching quality through THREE integrated components:

| Component | Purpose | Weight in Analysis |
|-----------|---------|-------------------|
| TIME ON TASK | Captures whether learning time is maximized | Contextual |
| QUALITY OF TEACHING PRACTICES | Measures teacher-student interaction quality | Primary (9 elements, 28 behaviors) |
| ENVIRONMENTAL CHECKLIST | Physical environment factors | Limited in audio analysis |

## 1.2 Observation Protocol
- Standard observation: Two 15-minute segments per class
- Each segment scored INDEPENDENTLY - do not let one segment influence another
- For audio analysis: Treat as continuous observation, create virtual segments at minutes 0-15 and 15-30 if recording exceeds 15 minutes

## 1.3 Scoring Philosophy
- ALL ratings must be based on SPECIFIC EVIDENCE from the audio
- When evidence is ambiguous, default to the lower score
- Cultural context matters - what constitutes "respect" or "positive language" varies
- Only score what is OBSERVABLE - do not infer intentions
- Each behavior scored as Low (L), Medium (M), High (H), or N/A
- Element scores are 1-5 based on behavior patterns

================================================================================
SECTION 2: TIME ON TASK (Element 0)
================================================================================

## 2.1 Snapshot Method
Take THREE mental "snapshots" at minutes 4, 9, and 14 of each 15-minute segment.
For audio: Estimate based on what is audible at those approximate timestamps.

## 2.2 Behavior 0.1: Teacher Provides Learning Activity
BINARY SCORE: Yes or No

### YES - Learning Activities (ANY activity related to class content):
- Teacher lecturing or explaining content
- Teacher reading aloud to students
- Students reading (individually or chorally)
- Small group or pair work on content
- Students working on worksheets
- Teacher asking content-related questions
- Students presenting work
- Teacher demonstrating a procedure
- CRITICAL: If teacher leaves but assigned learning activity, still counts as YES

### NO - Non-Learning Activities:
- Taking attendance (reading names individually)
- Disciplining students (extended redirection)
- Silently writing on board WITHOUT student engagement
- Administrative tasks (collecting money, signing forms)
- Prolonged transitions between activities
- Checking homework individually while others wait with nothing to do
- Outside disruptions where teacher stops to investigate
- Students waiting with nothing to do
- Setting up materials without concurrent activity

### AUDIO INDICATORS for 0.1:
- YES: Hear teacher explanation, student responses, reading, discussion
- NO: Silence, off-topic conversation, administrative dialogue, extended quiet

## 2.3 Behavior 0.2: Students Are On Task
ONLY SCORE IF 0.1 = YES; otherwise mark N/A

| Rating | Criteria | Audio Indicators |
|--------|----------|------------------|
| HIGH (H) | 0-1 students off task | Engaged responses, participation sounds, focused quiet during independent work |
| MEDIUM (M) | 2-5 students off task | Some side conversations, partial participation, mixed engagement sounds |
| LOW (L) | 6+ students off task | Significant noise, multiple side conversations, teacher repeatedly calling for attention |

### Off-Task Audio Indicators:
- Audible side conversations unrelated to content
- Teacher repeatedly asking for attention
- Disruptive sounds (laughing inappropriately, shouting)
- Extended silence when participation expected
- Students talking over teacher

================================================================================
SECTION 3: AREA A - CLASSROOM CULTURE
================================================================================

## ELEMENT 1: SUPPORTIVE LEARNING ENVIRONMENT
Definition: Teacher creates environment where students feel emotionally safe, supported, and welcome through respectful treatment.

### Behavior 1.1: Teacher Treats All Students Respectfully

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| Yells at students | Does not treat disrespectfully | Uses students' names |
| Scolds students | No outward signs of respect | Says "please" and "thank you" |
| Shames or ridicules students | Neutral tone throughout | Warm, welcoming tone |
| Uses harsh/demeaning language | Doesn't use names or courtesy | Shows culturally relevant respect signs |
| Dismissive responses | Matter-of-fact interactions | Patient with all students |

AUDIO SCORING GUIDE:
- Listen for: Tone of voice, use of names, courtesy words, patience in responses
- LOW indicators: Raised voice in anger, sarcastic tone, dismissive "whatever" responses, singling out students negatively
- MEDIUM indicators: Neutral professional tone, no negative but no positive markers
- HIGH indicators: Warm tone, consistent name usage, "please," "thank you," patient explanations

CRITICAL DISTINCTION: Physical punishment cannot be detected via audio - note as "unable to assess physical interactions"

### Behavior 1.2: Teacher Uses Positive Language
ONLY VERBAL COMMUNICATION COUNTS - nonverbal does not count for this behavior

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| No positive language | Some positive language (infrequent) | Consistent positive language |
| Only corrections/instructions | 1-4 instances in segment | 5+ instances in segment |
| Neutral or negative only | Generic: "good," "okay," "well done" | Enthusiastic and varied |

QUANTITATIVE THRESHOLDS (from official FAQ):
- 0 instances = LOW
- 1-4 instances = MEDIUM  
- 5+ instances = HIGH

EXAMPLES OF POSITIVE LANGUAGE:
- "Great job!"
- "Excellent thinking!"
- "You can do this!"
- "You are such a talented group!"
- "I love how you explained that!"
- "That's a wonderful answer!"
- "Keep up the good work!"
- "You're making great progress!"

WHAT DOES NOT COUNT:
- Clapping (nonverbal)
- Smiling (nonverbal)
- Nodding (nonverbal)
- "Okay" (neutral, not positive)
- "Correct" (evaluative, not encouraging)

AUDIO SCORING: Count each distinct instance of verbal encouragement. Track frequency explicitly.

### Behavior 1.3: Teacher Responds to Students' Needs
SCORE N/A IF: No observable emotional, material, or physical needs during segment

NEED TYPES:
1. Emotional: Student upset, frustrated, anxious, confused emotionally
2. Material: Missing supplies, textbook, pencil, paper
3. Physical: Needs bathroom, feels unwell, uncomfortable seating

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| Not aware of needs | Responds but doesn't solve | Promptly responds AND solves |
| Sees and ignores | Partial solution attempted | Complete resolution |
| Dismissive ("get over it") | Acknowledges without action | Specific address of problem |
| "Pull yourself together" | Asks another student to help but doesn't follow up | Provides solution or alternative |

AUDIO INDICATORS:
- Student request audible → Teacher response (or lack thereof) audible
- Listen for: Student distress sounds, requests for help, teacher acknowledgment

SCORING EXAMPLES:
- Student: "I don't have a pencil" → Teacher ignores → LOW
- Student: "I don't have a pencil" → Teacher: "Ask your neighbor" (no follow-up) → MEDIUM
- Student: "I don't have a pencil" → Teacher: "Here, take one from my box" → HIGH

### Behavior 1.4: Teacher Does Not Exhibit Bias and Challenges Stereotypes

This behavior has TWO SUB-BEHAVIORS that combine for final rating:

#### Sub-Behavior 1.4a: Gender Bias

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| Unequal participation opportunities by gender | Equal opportunities for all genders | Equal opportunities AND challenges stereotypes |
| Only calls on boys for difficult questions | Similar expectations for all | Uses counter-stereotypical examples |
| Only assigns girls to certain tasks (cleaning, organizing) | Both genders do same tasks | Explicitly discusses gender equality |
| Different praise/scolding patterns by gender | No obvious bias | "Let's hear more from the girls" or "Now a boy" |
| Stereotypical comments about gender abilities | Balanced attention | Examples showing women in science, men in caregiving |

AUDIO ANALYSIS:
- Track which students are called on (if names indicate gender)
- Listen for gendered language: "boys do this," "girls do that"
- Note distribution of difficult questions vs. simple questions
- Listen for stereotypical comments or counter-stereotypical examples

#### Sub-Behavior 1.4b: Disability Bias

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| Uses stigmatizing terms | Equal opportunities for all ability levels | Equal opportunities AND challenges stereotypes |
| Expresses low expectations | Similar expectations for all | Uses examples of people with disabilities in important roles |
| Excludes from participation | Praises similarly | Explicitly inclusive language |
| Ignores students with different needs | Enables participation | Discusses disability in positive light |

AUDIO INDICATORS:
- Stigmatizing language: "slow learner," derogatory terms
- Exclusionary phrases: "except for [student]"
- Positive: "Everyone can participate," inclusive examples

#### COMBINING 1.4a AND 1.4b FOR OVERALL 1.4 SCORE:

| 1.4a | 1.4b | Overall 1.4 |
|------|------|-------------|
| Same rating | Same rating | That rating |
| LOW | Any | LOW (Low takes precedence) |
| Any | LOW | LOW (Low takes precedence) |
| HIGH | MEDIUM | HIGH (High takes precedence when no Low) |
| MEDIUM | HIGH | HIGH (High takes precedence when no Low) |

---

## ELEMENT 2: POSITIVE BEHAVIORAL EXPECTATIONS
Definition: Teacher promotes positive behavior through acknowledgment and clear expectations.

### Behavior 2.1: Sets Clear Behavioral Expectations

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| Does not set expectations | Unclear/superficial expectations | Clear expectations throughout |
| Just says "work on this" | "Sit in groups and behave" (vague) | Explicit behavior descriptions |
| No guidance on conduct | General rules without specifics | "Use quiet indoor voice" |
| | | "Take turns speaking" |
| | | "Raise your hand before speaking" |
| | | "When finished, read quietly" |
| | | OR: No expectations stated but students well-behaved throughout |

CRITICAL DISTINCTION:
- Behavioral expectations = Expected CONDUCT ("use quiet voices")
- Activity instructions = STEPS to complete task ("read paragraph, answer questions")

AUDIO SCORING:
- Listen for: Explicit statements about expected behavior during activities
- HIGH also achieved if: No behavioral expectations stated BUT no behavioral issues occur (implicit well-managed classroom)

### Behavior 2.2: Acknowledges Positive Student Behavior

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| Does not acknowledge | Acknowledges but not specific | Specifically acknowledges behavior meeting/exceeding expectations |
| No recognition of good behavior | "Good job" without why | "I noticed Group A is taking turns" |
| | "This group is doing well" (generic) | "Thank you for raising your hand" |
| | | "I appreciate how quietly you're working" |

AUDIO INDICATORS:
- Listen for: Specific praise tied to behavior (not just academic correctness)
- Distinguish from academic praise: "Good answer" vs. "Good job raising your hand"

### Behavior 2.3: Redirects Misbehavior

MISBEHAVIOR DEFINITION: Student causes disruption that:
- Interferes with flow of lesson
- Distracts other students  
- Upsets the teacher

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| Ineffective AND focuses on misbehavior | Effective but focuses on negative OR somewhat effective focusing on positive | Effective AND focuses on expected behavior |
| "Why are you not paying attention?" | "Stop talking, you're making noise" (works but negative) | "Remember to use quiet voices" (works) |
| Ignores until escalates | "Focus on the task" (positive but doesn't work) | OR: No misbehavior occurs (well-behaved class) |
| Public shaming | | |

KEY DISTINCTION:
- Focusing on MISBEHAVIOR: "Stop talking," "Don't do that," "Why are you..."
- Focusing on EXPECTED BEHAVIOR: "Remember to...," "Let's use...," "Please..."

================================================================================
SECTION 4: AREA B - INSTRUCTION
================================================================================

## ELEMENT 3: LESSON FACILITATION
Definition: Teacher facilitates lesson to promote comprehension through clear objectives, multiple representations, connections, and modeling.

### Behavior 3.1: Explicitly Articulates Objectives

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| No stated/written objective | Broad objective stated OR inferable from activities | Specific objective stated AND activities align |
| Cannot be inferred from activities | "Today we're learning multiplication" (but activity is fractions) | "Today we'll learn to multiply fractions" + related activities |
| Activities seem random/disconnected | Topic mentioned but not specific skill | Learning goal clearly communicated |

AUDIO INDICATORS:
- Listen for: "Today we will learn...," "Our objective is...," "By the end of class you will..."
- If no explicit statement, can objective be clearly inferred from all activities heard?

### Behavior 3.2: Explains Content Using Multiple Forms of Representation

THE SIX FORMS OF REPRESENTATION:

1. **SPOKEN LANGUAGE** - Verbal explanation, reading aloud, teacher talk
   - Includes: Radio/video audio played for students

2. **MUSIC** - Singing, chanting, rhythmic elements
   - Includes: Songs, educational chants, musical recordings

3. **TEXT** - Letters, words, numbers, symbols (written)
   - Includes: Writing on board, referring to textbooks, worksheets
   - NOTE: In audio, infer from teacher references ("look at page 3," "on the board I wrote...")

4. **VISUAL AIDS** - Pictures, posters, images, drawings
   - Includes: Sign language, video images
   - NOTE: In audio, infer from teacher references ("look at this picture," "in the diagram...")

5. **CONCRETE OBJECTS** - Physical items, manipulatives, tactile materials
   - Includes: Braille materials, objects students can touch
   - NOTE: In audio, infer from descriptions ("hold up your blocks," "using these buttons...")

6. **MOVEMENT** - Dance, exercise, physical actions, gestures
   - NOTE: In audio, infer from instructions ("stand up," "act out," "point to...")

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| One form OR no explanation | Two forms | Three or more forms |
| Only lectures (spoken) | Spoken + written | Spoken + written + visual/concrete/movement |
| Technical terms unexplained | | |

CRITICAL RULES:
- Each category counts ONLY ONCE regardless of frequency
- One object can demonstrate multiple forms (teacher reads from textbook = spoken + text)
- Student-created examples can count if teacher references them in instruction

AUDIO SCORING:
- Primary form almost always present: SPOKEN LANGUAGE
- Listen for references to: board, textbook, pictures, objects, movements, songs

### Behavior 3.3: Makes Connections to Other Content or Daily Life

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| No connections made | Superficial/confusing connection | Meaningful explicit connection |
| Uses relatable examples without explicit connection | "When we cut cake, we use fractions" (no elaboration) | Fully explains how prior learning connects |
| "Remember X, today we learn Y" (no link) | Mentions connection but doesn't develop it | Relates to students' experiences with clear purpose |

CRITICAL DISTINCTION:
- Using relatable examples ≠ Making connections
- Must EXPLICITLY state how the connection relates to learning objective

EXAMPLES:
- LOW: Uses picture of cake for fractions (relatable but no stated connection)
- MEDIUM: "When we cut cake, we use fractions" (stated but not developed)
- HIGH: "Who has sliced a cake? How did you make sure everyone got equal pieces? That's exactly what fractions help us do - divide things equally. Today we'll learn..."

AUDIO SCORING:
- Listen for: Explicit linking statements between content areas or to student experiences
- Must hear the PURPOSE of the connection stated

### Behavior 3.4: Teacher Models by Enacting or Thinking Aloud

DEFINITIONS:
- **ENACTING**: Demonstrating/performing the procedure students will do
- **THINKING ALOUD**: Verbalizing thought process while performing task

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| Does not model | Partially models | Completely models |
| Gives problems without demonstrating | Shows some steps but not all | Enacts ALL parts of procedure |
| Only gives instructions | Doesn't clarify thinking | OR: Enacts procedure AND thinks aloud |
| | | Shows full procedure with reasoning |

CRITICAL DISTINCTIONS:
- Explaining/giving directions ≠ Modeling
- Modeling = Teacher PERFORMS the task (or part of it)
- Can occur at ANY point in lesson (beginning, middle, or end)
- Task students do must be SAME or SIMILAR to what teacher modeled

AUDIO INDICATORS:
- LOW: Only hear instructions ("Now do problems 1-5")
- MEDIUM: Hear teacher doing part of a problem, but not complete
- HIGH: Hear teacher work through entire example, explaining each step

THINK ALOUD MARKERS:
- "I'm thinking about..."
- "First I need to..."
- "I notice that..."
- "This tells me..."
- "Let me check..."
- "I'm going to try..."

---

## ELEMENT 4: CHECKS FOR UNDERSTANDING
Definition: Teacher ensures most students comprehend through questioning, monitoring, and adjusting.

### Behavior 4.1: Uses Questions/Prompts to Check Understanding

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| No questions OR only choral response accepted | Checks FEW students | Checks MOST students |
| "Do you understand?" → "Yes" (unison) | Asks question, few raise hands, calls on 1-2 | Strategies that gather info from majority |
| "This is correct, right?" | Allows voluntary responses from few | Thumbs up/down for whole class |
| Teacher answers own questions | | All students share answers |
| | | Cold calling multiple students |
| | | Written checks reviewed |

AUDIO SCORING:
- LOW: Rhetorical questions, unison responses only
- MEDIUM: Individual students responding (limited number)
- HIGH: Hear evidence of most students responding (multiple voices, teacher acknowledging various responses)

### Behavior 4.2: Monitors During Independent/Group Work
SCORE N/A IF: No independent or group work occurs

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| Does not monitor | Monitors SOME students | Systematically monitors MOST students |
| Stays at desk | Circulates but limited interaction | Circulates approaching students/groups |
| Remains at front | Observes some work | Asks questions, clarifies concepts |
| | | Approaches in systematic way |

AUDIO INDICATORS:
- Listen during work time for: Teacher voice location changes (near/far from microphone)
- Individual conversations between teacher and students
- Teacher addressing different students by name across the room

NOTE: If teacher walks around but no verbal interaction is heard, infer MEDIUM (cannot confirm what teacher is observing)

### Behavior 4.3: Adjusts Teaching to Student Level

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| Does not adjust | Brief/superficial adjustment | Substantial adjustment |
| Notices errors but continues | Quick reminder without elaboration | Stops to re-explain concept |
| No response to confusion | "Remember to dot your i's" | Uses different representation |
| | Reminds of procedure briefly | Provides additional examples |
| | | More challenging tasks for advanced students |
| | | Adapted approaches for different needs |

TYPES OF ADJUSTMENTS:
1. RE-EXPLAINING: Presenting same content differently
2. ADDITIONAL PRACTICE: More time/examples
3. SCAFFOLDING: Breaking down into smaller steps
4. DIFFERENTIATION: Different tasks for different levels
5. ACCOMMODATION: Adapted approaches for specific needs (Braille, sign language, etc.)
6. LANGUAGE SWITCHING: Changing language of instruction for comprehension (counts as MEDIUM maximum unless combined with other adjustment)

AUDIO INDICATORS:
- Listen for: Teacher responding to wrong answers with elaboration
- "Let me explain that another way..."
- "Here's another example..."
- "For those who finished early, try this..."

---

## ELEMENT 5: FEEDBACK
Definition: Teacher provides specific comments or prompts that clarify misunderstandings and identify successes.

FEEDBACK DEFINITION: Information that helps learner understand:
- What they did well and WHY
- What they misunderstood and HOW to correct it

### Behavior 5.1: Feedback on Misunderstandings

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| No feedback OR simple evaluative | General/superficial comments | Specific substantive information |
| "That is incorrect" (no more) | "You forgot the negative sign" | "Do you remember what happens when we multiply positive and negative numbers?" |
| "No" | Identifies error but not why | Guides through correction process |
| "Try again" (no guidance) | "Check your work" (generic) | Provides prompts to help student self-correct |
| | | Explains the specific misconception |

AUDIO INDICATORS:
- LOW: Short rejections, moving on quickly
- MEDIUM: Brief identification of error
- HIGH: Extended dialogue helping student understand

### Behavior 5.2: Feedback on Successes

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| No feedback OR simple evaluative | General/superficial comments | Specific substantive information |
| "That is correct" | "Good job on third paragraph" (no why) | "You did a great job getting the reader interested when you wrote..." |
| "Yes" | "Nice work" (generic) | Explains specifically what was done well |
| "Right" | | Highlights student work as example with specific explanation |

CRITICAL DISTINCTION:
- Positive language (1.2): "Good job!" "Great!" - encouragement
- Specific feedback on success (5.2): "Your opening sentence works because..." - substantive

================================================================================
SECTION 5: AREA B - INSTRUCTION (CONTINUED)
================================================================================

## ELEMENT 6: CRITICAL THINKING
Definition: Teacher builds critical thinking by encouraging active content analysis.

### Behavior 6.1: Asks Open-Ended Questions

OPEN-ENDED QUESTION DEFINITION:
- Requires reasoning, explanation, or generalization
- Has more than one possible correct answer
- Cannot be answered with single word/fact

CLOSED-ENDED EXAMPLES:
- "Who is the main character?"
- "What is 5 + 3?"
- "Which is greater, -2 or -6?"
- "What year did this happen?"

OPEN-ENDED EXAMPLES:
- "Why do you think the character made that choice?"
- "How did you solve that problem?"
- "What might happen if...?"
- "Can you explain your thinking?"
- "What's another way we could approach this?"
- "Why is -2 greater than -6?"

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| No open-ended OR only 1 | At least 2 open-ended but no building on responses | 3+ open-ended AND at least 1 builds on response |
| Only closed-ended questions | OR: 2 questions where 1 is follow-up | Asks students to justify reasoning |
| | | Asks to further explain or clarify |
| | | "What makes you think that?" after response |

BUILDING ON RESPONSES:
- Student answers → Teacher asks "Why?" or "How do you know?"
- Teacher probes deeper into student thinking
- Follow-up questions that extend initial response

AUDIO SCORING:
- Count open-ended questions explicitly
- Note whether follow-up questions build on student responses

### Behavior 6.2: Provides Thinking Tasks

THINKING TASK CONTINUUM:

**NOT THINKING TASKS (Rote):**
- Memorization
- Repetition
- Copying
- Simple recall
- Listening only

**SUPERFICIAL THINKING TASKS (MEDIUM):**
- Matching sets of items
- Identifying concepts or key information
- Comparing and contrasting characteristics
- Applying learned techniques to SIMILAR problems (as demonstrated)
- Categorizing items
- Sequencing events

**SUBSTANTIAL THINKING TASKS (HIGH):**
- Making predictions
- Identifying patterns
- Explaining thinking/reasoning
- Making connections
- Interpreting information
- Applying to NEW tasks (not demonstrated)
- Analyzing causes/effects
- Evaluating options
- Creating original content
- Problem-solving with multiple approaches

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| No thinking tasks | Superficial thinking tasks | Substantial thinking tasks |
| Students only listen | Matching, identifying, comparing | Predicting, pattern-finding |
| Rote memorization | Apply to similar problems | Explaining reasoning |
| Copying from board | Basic categorization | Apply to new contexts |

SUBJECT-SPECIFIC EXAMPLES:

**Language Arts:**
- LOW: Repetitively read text, copy sentences
- MEDIUM: Answer comprehension questions identifying protagonist/setting, write sentences with specific structure
- HIGH: Predict what happens next with reasoning, analyze author's choices, compare different texts

**Mathematics:**
- LOW: Memorize numbers, copy examples from board
- MEDIUM: Complete similar problems to those demonstrated, compare/order numbers
- HIGH: Find patterns in number sequences, explain why a method works, apply to real-world scenarios

### Behavior 6.3: Students Ask Questions or Perform Tasks

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| Students don't ask open-ended OR perform thinking tasks | Students perform superficial thinking tasks | Students ask open-ended questions OR perform substantial thinking tasks |
| Only respond to closed questions | No open-ended questions from students | "Why does 6-9 equal negative?" |
| Passive reception | Complete matching/identifying tasks | Students explain their reasoning |
| | | Students make predictions with justification |

AUDIO INDICATORS:
- Listen for student-initiated questions
- Listen for student explanations of thinking
- Listen for student responses that show analysis vs. recall

================================================================================
SECTION 6: AREA C - SOCIOEMOTIONAL SKILLS
================================================================================

## ELEMENT 7: AUTONOMY
Definition: Teacher provides opportunities for choices and meaningful roles; students volunteer participation.

### Behavior 7.1: Provides Choices

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| No explicit choices | Superficial choice UNRELATED to learning objective | Substantive choice RELATED to learning objective |
| Teacher decides everything | Choose pencil color | Choose between essay or presentation |
| Prescribes exact approach | Choose where to sit | Choose topic to investigate |
| | Choose order of activities | Choose method to solve problem |
| | Vote on best presentation | Choose which questions to answer |
| | | Choose format of final product |

CRITICAL: Choice must be EXPLICITLY stated by teacher
- "You may choose to..." = Counts
- Open-ended task without stated options = Does NOT count

AUDIO INDICATORS:
- Listen for: "You can choose...," "You decide...," "You have options..."

### Behavior 7.2: Provides Opportunities for Roles

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| No opportunities for roles | Limited roles | Meaningful roles responsible for learning |
| Lecture-based only | Taking attendance | Explain solution to class |
| Students only copy | Passing out materials | Lead discussion |
| | Writing on board (without explanation) | Teach peers |
| | Housekeeping tasks (cleaning, organizing) | Present and explain reasoning |
| | Helper roles without learning component | Responsible for part of lesson |

AUDIO INDICATORS:
- LIMITED: "Sarah, please hand out papers"
- MEANINGFUL: "Sarah, can you come up and show us how you solved this problem?"

### Behavior 7.3: Students Volunteer

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| Students do not volunteer | Few students volunteer | Most students volunteer |
| Silence when opportunities given | Same few students participate repeatedly | Many students respond |
| Only respond when called | Limited participation | Students volunteer without being asked |
| | | Spontaneous contributions |

WHAT IS NOT VOLUNTEERING:
- Call-and-response (rehearsed patterns)
- Choral responses ("Yes we understand")
- Required unison answers
- Responding only when directly called on

AUDIO INDICATORS:
- Many different voices participating
- Students speaking up unprompted
- Enthusiasm in responses
- Students offering additional information

---

## ELEMENT 8: PERSEVERANCE
Definition: Teacher acknowledges efforts, has positive attitude toward challenges, encourages goal-setting.

### Behavior 8.1: Acknowledges Students' Efforts

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| Does not acknowledge efforts | Sometimes acknowledges but mostly focuses on outcomes/intelligence | Frequently acknowledges efforts explicitly |
| "You're so smart!" | Occasional effort recognition | "You've progressed so much!" |
| "You're the smartest!" | Most praise about being smart/intelligent | "I can tell you've been practicing" |
| Focus only on correct answers | | "Your hard work is paying off" |
| | | "I'm glad you asked for help" |
| | | Identifies specific efforts made |

CRITICAL DISTINCTION:
- Intelligence praise: "You're so smart," "You're intelligent," "You're talented"
- Effort praise: "You worked hard," "You practiced," "You didn't give up," "You asked good questions"

AUDIO SCORING:
- Track instances of each type
- If mostly intelligence praise with rare effort praise = MEDIUM
- If consistently effort-focused = HIGH

### Behavior 8.2: Positive Attitude Toward Challenges

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| Negative attitude | Neutral attitude | Positive attitude |
| Scolds for mistakes | Doesn't penalize but doesn't normalize failure | Explicitly normalizes struggle |
| Impatient with confusion | Just gives answer neutrally | "It's okay to feel frustrated" |
| Sighs/frustration evident | Matter-of-fact corrections | "Mistakes help us learn" |
| "Why don't you get this?" | | Encourages strategies for getting help |
| | | "Let's think about how to approach this" |

AUDIO INDICATORS:
- Tone of voice when students struggle
- Response to wrong answers
- Explicit statements about failure being okay
- Patience level in explanations

### Behavior 8.3: Encourages Goal Setting

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| Does not encourage goals | Short-term OR long-term goals only | Short-term AND long-term goals |
| No mention of goals | "How many pages will you read this week?" (short) | Links short-term to long-term |
| | "What do you want to be when you grow up?" (long) | "What will you do this week toward our yearly goal?" |
| | Mentions importance of goals generally | |
| | Highlights goal-setting in stories | |

DEFINITIONS:
- SHORT-TERM: Within a month or less (daily, weekly, monthly)
- LONG-TERM: Beyond a month (semester, year, life goals)

---

## ELEMENT 9: SOCIAL & COLLABORATIVE SKILLS
Definition: Teacher fosters collaboration and interpersonal skills; students collaborate positively.

### Behavior 9.1: Promotes Collaboration

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| Does not promote collaboration | Superficial collaboration | Substantial collaboration |
| No group or pair work | Share opinions/materials/ideas | Work together to produce product |
| Individual work only | Read neighbor's work | Solve problem together |
| | Share supplies | Create something collaboratively |
| | "Tell your partner your answer" | Peer feedback and revision |
| | | Joint presentations |

AUDIO INDICATORS:
- Listen for group/pair work instructions
- Student-to-student discussion about content
- Instructions for joint products

### Behavior 9.2: Promotes Interpersonal Skills

INTERPERSONAL SKILLS DEFINED:
1. **PERSPECTIVE TAKING**: Considering situation from different viewpoint
2. **EMPATHIZING**: Recognizing and sharing another's emotions
3. **EMOTION REGULATION**: Managing and responding to emotional experiences
4. **SOCIAL PROBLEM SOLVING**: Process to solve interpersonal problems

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| Does not promote | Brief/superficial promotion | Explicitly encourages these skills |
| No interpersonal skill instruction | "Help each other" (no explanation) | "How do you think that made them feel?" |
| | "Say you're sorry" (no why) | "Imagine what it would be like if..." |
| | "Take turns" (no why) | Guides conflict resolution |
| | No explanation of importance | Discusses why these skills matter |

AUDIO INDICATORS:
- Explicit teaching about emotions, perspectives
- Questions about feelings
- Conflict resolution guidance
- "Put yourself in their shoes"

### Behavior 9.3: Students Collaborate

| LOW | MEDIUM | HIGH |
|-----|--------|------|
| No collaboration OR negative behaviors | Superficial collaboration (minor negative okay) | Substantial collaboration, no negative behaviors |
| Purposeful exclusion | Share materials but work independently | Work together on product/problem |
| | Minor teasing (playful, no one upset) | Help each other |
| | Side-by-side work without interaction | Discuss content together |
| | | No negative behaviors heard |

================================================================================
SECTION 7: SCORING METHODOLOGY
================================================================================

## 7.1 Behavior to Element Score Conversion

| Behavior Pattern | Typical Element Score |
|------------------|----------------------|
| All Low | 1 |
| Mostly Low, some Medium | 2 |
| All Medium OR mixed | 3 |
| Mostly Medium, some High OR mixed with High | 4 |
| Mostly/All High | 5 |

## 7.2 Score Interpretation

| Score | Interpretation |
|-------|---------------|
| 1 | Ineffective - Significant improvement needed |
| 2 | Between ineffective and somewhat effective |
| 3 | Somewhat effective - Meeting basic expectations |
| 4 | Between somewhat effective and effective |
| 5 | Effective - Strong teaching practice |

## 7.3 Overall Score Calculation
- Calculate average of all 9 element scores
- Round to one decimal place
- Range: 1.0 - 5.0

## 7.4 Confidence Assessment

Consider these factors:
- Audio quality (clarity of speech)
- Length of recording relative to standard 15-minute segment
- Completeness of evidence for behaviors
- Ambiguity in interactions

| Confidence Level | Description |
|------------------|-------------|
| 0.9-1.0 | High: Clear audio, complete evidence for most behaviors |
| 0.7-0.89 | Moderate: Good audio, some behaviors difficult to assess |
| 0.5-0.69 | Low: Poor audio or significant missing evidence |
| Below 0.5 | Very Low: Insufficient for reliable assessment |

================================================================================
SECTION 8: AUDIO-SPECIFIC ADAPTATIONS
================================================================================

## 8.1 What CAN Be Assessed via Audio

FULLY ASSESSABLE:
- Positive language use (1.2) - count instances
- Respectful treatment (1.1) - tone, words used
- Open-ended questions (6.1) - count and categorize
- Feedback quality (5.1, 5.2) - content of responses
- Behavioral expectations (2.1) - verbal statements
- Lesson objectives (3.1) - stated objectives
- Connections (3.3) - verbal connections made
- Modeling (3.4) - if verbalized/think aloud
- Goal-setting (8.3) - verbal encouragement
- Collaboration promotion (9.1) - verbal instructions
- Interpersonal skills (9.2) - verbal teaching

PARTIALLY ASSESSABLE:
- Students on task (0.2) - only disruptive off-task behavior audible
- Monitoring (4.2) - can hear teacher moving, speaking to individuals
- Multiple representations (3.2) - some inferred from teacher references
- Responding to needs (1.3) - only if need voiced and response audible
- Student volunteering (7.3) - based on voice variety, unprompted responses

DIFFICULT/LIMITED:
- Bias (1.4) - unless clearly verbal, gender distribution hard to track
- Physical environment factors
- Non-verbal communication
- Visual materials (unless described)
- Exact count of students off-task

## 8.2 Required Adaptations

1. **Time on Task**: Base primarily on audible engagement indicators
2. **Multiple Representations**: Note what can be inferred from teacher's verbal references
3. **Bias**: Focus on verbal indicators; note limitations in analysis
4. **Monitoring**: Infer from teacher's physical movement sounds and individual interactions
5. **Student behaviors**: Assess based on what can be heard

## 8.3 Confidence Adjustments

Reduce confidence when:
- Audio quality prevents clear understanding
- Key behaviors require visual observation
- Student responses are inaudible
- Unclear speaker identification

================================================================================
SECTION 9: FAQ CLARIFICATIONS
================================================================================

## Critical Distinctions from Official FAQ

1. **Positive Language vs. Acknowledging Effort**
   - "Good job!" = positive language ONLY
   - "You've made progress, I can tell you practiced!" = BOTH

2. **Behavioral Expectations vs. Instructions**
   - Expectations = Expected CONDUCT
   - Instructions = STEPS to complete task

3. **Modeling vs. Explaining**
   - Explaining = TELLING what to do
   - Modeling = DEMONSTRATING/performing

4. **Connections**
   - Using relatable examples ≠ Making connections
   - Must EXPLICITLY link to learning objective

5. **Volunteering**
   - Choral response ≠ volunteering
   - Must be individual CHOICE to participate

6. **Open-ended Questions**
   - Asking many without building on responses = MEDIUM max
   - Must have follow-up for HIGH

7. **Feedback vs. Positive Language**
   - "Great!" = positive language
   - "Your opening works because..." = feedback

## Special Scoring Situations

1. **No Observable Need (1.3)**: Score N/A if no student needs are evident
2. **No Independent Work (4.2)**: Score N/A if entire segment is whole-class
3. **Well-Behaved Class (2.1, 2.3)**: Can score HIGH if no misbehavior and no explicit expectations needed
4. **Single Strong Instance**: One excellent example CAN justify HIGH if sufficiently substantive
5. **Cultural Variations**: Respect signs vary by culture; adjust for context`
}