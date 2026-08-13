/// The seven-block conversation guide a pedagogy coordinator uses to discuss one
/// TEACH element with the teacher they observed.
///
/// Structure comes from the Mato Grosso coordinators:
/// observed evidence → what it means → coach question → follow-up questions →
/// possible model → practice → next step.
///
/// Generated on demand from the stored analysis and then kept, so reopening the
/// screen returns the same questions rather than a reworded set.
class CoachScript {
  final String id;
  final String recordingId;

  /// Canonical TEACH element key, e.g. 'checks_understanding'.
  final String elementKey;

  final String language;

  // ── The seven blocks ───────────────────────────────────────────────────────

  /// What was actually heard. Factual, quoted where possible.
  final List<String> observedEvidence;

  /// A formative reading of that evidence.
  final String? whatItMeans;

  /// The single open question that starts the conversation.
  final String? coachQuestion;

  /// Further questions, depending where the teacher takes it.
  final List<String> followUpQuestions;

  /// What stronger practice could look like in this lesson.
  final String? possibleModel;

  /// Something to rehearse together, now.
  final String? practice;

  /// One commitment to check at the next visit.
  final String? nextStep;

  final DateTime? createdAt;

  CoachScript({
    required this.id,
    required this.recordingId,
    required this.elementKey,
    required this.language,
    this.observedEvidence = const [],
    this.whatItMeans,
    this.coachQuestion,
    this.followUpQuestions = const [],
    this.possibleModel,
    this.practice,
    this.nextStep,
    this.createdAt,
  });

  factory CoachScript.fromJson(Map<String, dynamic> json) {
    List<String> stringList(dynamic value) {
      if (value is! List) return const [];
      return value.map((e) => e.toString()).toList();
    }

    return CoachScript(
      id: json['id'] ?? '',
      recordingId: json['recording_id'] ?? '',
      elementKey: json['element_key'] ?? '',
      language: json['language'] ?? 'en',
      observedEvidence: stringList(json['observed_evidence']),
      whatItMeans: json['what_it_means'],
      coachQuestion: json['coach_question'],
      followUpQuestions: stringList(json['follow_up_questions']),
      possibleModel: json['possible_model'],
      practice: json['practice'],
      nextStep: json['next_step'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  /// True when the script has enough to run a conversation from. A response
  /// missing the opening question is not usable.
  bool get isUsable => coachQuestion != null && coachQuestion!.isNotEmpty;
}
