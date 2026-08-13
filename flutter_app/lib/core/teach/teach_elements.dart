import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Single source of truth for the nine TEACH Primary elements and their
/// behaviors, as displayed in the app.
///
/// Two sibling definitions exist and must stay in step:
///   - `monitoring-dashboard/src/lib/teach.ts` — same nine elements, same order,
///     for the World Bank dashboard.
///   - `gemini.CanonicalElements` in
///     `backend/internal/services/gemini/teach_types_enhanced.go` — the keys the
///     AI response is parsed into and the `analyses` table columns.
///
/// [TeachElement.canonicalKey] is the stable identity used for lookups and must
/// never be translated or derived from a display label. Display text always
/// comes from [TeachElement.labelKey] via `AppStrings`.

/// The three TEACH domains. Each carries the manual's colour scheme.
enum TeachDomain { classroomCulture, instruction, socioemotionalSkills }

extension TeachDomainStyle on TeachDomain {
  /// l10n key for the domain heading.
  String get labelKey {
    switch (this) {
      case TeachDomain.classroomCulture:
        return 'domainClassroomCulture';
      case TeachDomain.instruction:
        return 'domainInstruction';
      case TeachDomain.socioemotionalSkills:
        return 'domainSocioemotionalSkills';
    }
  }

  /// Accent colour — icons, borders, indicators. NOT safe for text.
  Color get accent {
    switch (this) {
      case TeachDomain.classroomCulture:
        return AppTheme.domainCultureAccent;
      case TeachDomain.instruction:
        return AppTheme.domainInstructionAccent;
      case TeachDomain.socioemotionalSkills:
        return AppTheme.domainSocioemotionalAccent;
    }
  }

  /// Pale fill behind icons and badges.
  Color get tint {
    switch (this) {
      case TeachDomain.classroomCulture:
        return AppTheme.domainCultureTint;
      case TeachDomain.instruction:
        return AppTheme.domainInstructionTint;
      case TeachDomain.socioemotionalSkills:
        return AppTheme.domainSocioemotionalTint;
    }
  }

  /// Contrast-safe shade for any text rendered in the domain colour.
  /// The manual's yellow is far below 4.5:1 on white, so text must never use
  /// [accent] directly.
  Color get onSurface {
    switch (this) {
      case TeachDomain.classroomCulture:
        return AppTheme.domainCultureText;
      case TeachDomain.instruction:
        return AppTheme.domainInstructionText;
      case TeachDomain.socioemotionalSkills:
        return AppTheme.domainSocioemotionalText;
    }
  }
}

/// One behavior within an element, e.g. 1.3 "Responds to Needs".
class TeachBehavior {
  /// Key the AI emits in the `behaviors` map, e.g. `responds_to_needs`.
  final String key;

  /// TEACH form number, e.g. "1.3". Coordinators work from the paper form and
  /// refer to behaviors by number, so it is shown alongside the name.
  final String number;

  /// l10n key for the behavior name.
  final String labelKey;

  const TeachBehavior(this.key, this.number, this.labelKey);
}

/// One of the nine TEACH elements.
class TeachElement {
  /// Stable identity. Matches the `analyses` table column prefix, the AI
  /// response key, and the dashboard's `rationaleKey`. Never translated.
  final String canonicalKey;

  /// l10n key for the element name.
  final String labelKey;

  final TeachDomain domain;
  final IconData icon;
  final List<TeachBehavior> behaviors;

  const TeachElement({
    required this.canonicalKey,
    required this.labelKey,
    required this.domain,
    required this.icon,
    required this.behaviors,
  });
}

/// The nine elements in TEACH form order.
const List<TeachElement> kTeachElements = [
  // ── Area I: Classroom Culture ─────────────────────────────────────────────
  TeachElement(
    canonicalKey: 'supportive_environment',
    labelKey: 'teachElementSupportiveEnvironment',
    domain: TeachDomain.classroomCulture,
    icon: Icons.spa,
    behaviors: [
      TeachBehavior('treats_respectfully', '1.1', 'teachBehaviorTreatsRespectfully'),
      TeachBehavior('positive_language', '1.2', 'teachBehaviorPositiveLanguage'),
      TeachBehavior('responds_to_needs', '1.3', 'teachBehaviorRespondsToNeeds'),
      TeachBehavior('no_bias_challenges_stereotypes', '1.4', 'teachBehaviorNoBias'),
    ],
  ),
  TeachElement(
    canonicalKey: 'positive_expectations',
    labelKey: 'teachElementPositiveExpectations',
    domain: TeachDomain.classroomCulture,
    icon: Icons.psychology_alt,
    behaviors: [
      TeachBehavior('sets_clear_expectations', '2.1', 'teachBehaviorSetsClearExpectations'),
      TeachBehavior('acknowledges_positive_behavior', '2.2', 'teachBehaviorAcknowledgesPositiveBehavior'),
      TeachBehavior('redirects_misbehavior', '2.3', 'teachBehaviorRedirectsMisbehavior'),
    ],
  ),

  // ── Area II: Instruction ──────────────────────────────────────────────────
  TeachElement(
    canonicalKey: 'lesson_facilitation',
    labelKey: 'teachElementLessonFacilitation',
    domain: TeachDomain.instruction,
    icon: Icons.record_voice_over,
    behaviors: [
      TeachBehavior('articulates_objectives', '3.1', 'teachBehaviorArticulatesObjectives'),
      TeachBehavior('multiple_representations', '3.2', 'teachBehaviorMultipleRepresentations'),
      TeachBehavior('makes_connections', '3.3', 'teachBehaviorMakesConnections'),
      TeachBehavior('models', '3.4', 'teachBehaviorModels'),
    ],
  ),
  TeachElement(
    canonicalKey: 'checks_understanding',
    labelKey: 'teachElementChecksUnderstanding',
    domain: TeachDomain.instruction,
    icon: Icons.quiz,
    behaviors: [
      TeachBehavior('questions_prompts_to_check', '4.1', 'teachBehaviorQuestionsPromptsToCheck'),
      TeachBehavior('monitors_during_independent_work', '4.2', 'teachBehaviorMonitorsIndependentWork'),
      TeachBehavior('adjusts_teaching', '4.3', 'teachBehaviorAdjustsTeaching'),
    ],
  ),
  TeachElement(
    canonicalKey: 'feedback',
    labelKey: 'teachElementFeedback',
    domain: TeachDomain.instruction,
    icon: Icons.feedback,
    behaviors: [
      TeachBehavior('feedback_on_misunderstandings', '5.1', 'teachBehaviorFeedbackMisunderstandings'),
      TeachBehavior('feedback_on_successes', '5.2', 'teachBehaviorFeedbackSuccesses'),
    ],
  ),
  TeachElement(
    canonicalKey: 'critical_thinking',
    labelKey: 'teachElementCriticalThinking',
    domain: TeachDomain.instruction,
    icon: Icons.lightbulb,
    behaviors: [
      TeachBehavior('open_ended_questions', '6.1', 'teachBehaviorOpenEndedQuestions'),
      TeachBehavior('thinking_tasks', '6.2', 'teachBehaviorThinkingTasks'),
      TeachBehavior('students_ask_questions_perform_tasks', '6.3', 'teachBehaviorStudentsAskQuestions'),
    ],
  ),

  // ── Area III: Socioemotional Skills ───────────────────────────────────────
  TeachElement(
    canonicalKey: 'autonomy',
    labelKey: 'teachElementAutonomy',
    domain: TeachDomain.socioemotionalSkills,
    icon: Icons.accessibility_new,
    behaviors: [
      TeachBehavior('provides_choices', '7.1', 'teachBehaviorProvidesChoices'),
      TeachBehavior('opportunities_for_roles', '7.2', 'teachBehaviorOpportunitiesForRoles'),
      TeachBehavior('students_volunteer', '7.3', 'teachBehaviorStudentsVolunteer'),
    ],
  ),
  TeachElement(
    canonicalKey: 'perseverance',
    labelKey: 'teachElementPerseverance',
    domain: TeachDomain.socioemotionalSkills,
    icon: Icons.hiking,
    behaviors: [
      TeachBehavior('acknowledges_efforts', '8.1', 'teachBehaviorAcknowledgesEfforts'),
      TeachBehavior('positive_attitude_toward_challenges', '8.2', 'teachBehaviorPositiveAttitude'),
      TeachBehavior('encourages_goal_setting', '8.3', 'teachBehaviorEncouragesGoalSetting'),
    ],
  ),
  TeachElement(
    canonicalKey: 'social_collaborative',
    labelKey: 'teachElementSocialCollaborative',
    domain: TeachDomain.socioemotionalSkills,
    icon: Icons.groups,
    behaviors: [
      TeachBehavior('promotes_collaboration', '9.1', 'teachBehaviorPromotesCollaboration'),
      TeachBehavior('promotes_interpersonal_skills', '9.2', 'teachBehaviorPromotesInterpersonalSkills'),
      TeachBehavior('students_collaborate', '9.3', 'teachBehaviorStudentsCollaborate'),
    ],
  ),
];

/// Elements grouped by domain, in display order.
final Map<TeachDomain, List<TeachElement>> kTeachElementsByDomain = {
  for (final domain in TeachDomain.values)
    domain: kTeachElements.where((e) => e.domain == domain).toList(),
};

/// TEACH elements a deployment prioritises, keyed by country.
///
/// Mirrors `programmeCoachingAreas` in `backend/internal/services/gemini/programme.go`
/// — the same skills the coaching section is built around. Kept in step by hand;
/// they are two views of one programme decision.
///
/// These lead the focal-skill picker rather than replacing it: the state's focus
/// is surfaced without deciding a coordinator may never coach on anything else.
const Map<String, List<String>> kPriorityElementsByCountry = {
  'Brazil': ['checks_understanding', 'feedback'],
};

/// Canonical keys the deployment prioritises, or empty when it has none.
List<String> priorityElementKeysFor(String? country) =>
    country == null ? const [] : (kPriorityElementsByCountry[country] ?? const []);

/// Lookup by canonical key. Returns null for an unknown key.
TeachElement? teachElementByKey(String canonicalKey) {
  for (final element in kTeachElements) {
    if (element.canonicalKey == canonicalKey) return element;
  }
  return null;
}

/// Lookup of a behavior by the key the AI emitted, across all elements.
/// Returns null when the model emits a behavior we have no label for — callers
/// must fall back to rendering the raw key rather than failing.
TeachBehavior? teachBehaviorByKey(String behaviorKey) {
  for (final element in kTeachElements) {
    for (final behavior in element.behaviors) {
      if (behavior.key == behaviorKey) return behavior;
    }
  }
  return null;
}
