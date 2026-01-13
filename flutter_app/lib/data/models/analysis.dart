class Analysis {
  final String id;
  final String recordingId;
  final Map<String, dynamic> timeOnLearning;
  
  // Element Scores (kept for backward compatibility and easy access)
  final int? supportiveEnvironmentScore;
  final int? positiveExpectationsScore;
  final int? lessonFacilitationScore;
  final int? checksUnderstandingScore;
  final int? feedbackScore;
  final int? criticalThinkingScore;
  final int? autonomyScore;
  final int? perseveranceScore;
  final int? socialCollaborativeScore;
  
  // Enhanced Element Analysis (New)
  final ElementAnalysis? supportiveEnvironment;
  final ElementAnalysis? positiveExpectations;
  final ElementAnalysis? lessonFacilitation;
  final ElementAnalysis? checksUnderstanding;
  final ElementAnalysis? feedback;
  final ElementAnalysis? criticalThinking;
  final ElementAnalysis? autonomy;
  final ElementAnalysis? perseverance;
  final ElementAnalysis? socialCollaborative;

  final double? overallScore;
  final String? summary;
  final List<String> strengths;
  final List<String> areasForImprovement;
  final List<Recommendation> recommendations;
  final DateTime createdAt;
  final Transcription? transcription;
  final ConfidenceFactors? confidenceFactors; // New

  Analysis({
    required this.id,
    required this.recordingId,
    required this.timeOnLearning,
    this.supportiveEnvironmentScore,
    this.positiveExpectationsScore,
    this.lessonFacilitationScore,
    this.checksUnderstandingScore,
    this.feedbackScore,
    this.criticalThinkingScore,
    this.autonomyScore,
    this.perseveranceScore,
    this.socialCollaborativeScore,
    this.supportiveEnvironment,
    this.positiveExpectations,
    this.lessonFacilitation,
    this.checksUnderstanding,
    this.feedback,
    this.criticalThinking,
    this.autonomy,
    this.perseverance,
    this.socialCollaborative,
    this.overallScore,
    this.summary,
    required this.strengths,
    required this.areasForImprovement,
    required this.recommendations,
    required this.createdAt,
    this.transcription,
    this.confidenceFactors,
  });

  factory Analysis.fromJson(Map<String, dynamic> json) {
    // Parse confidence factors from time_on_learning if present
    ConfidenceFactors? factors;
    if (json['time_on_learning'] != null && json['time_on_learning']['confidence_factors'] != null) {
      try {
        factors = ConfidenceFactors.fromJson(json['time_on_learning']['confidence_factors']);
      } catch (e) {
        print("Error parsing confidence factors: $e");
      }
    }

    // Helper to parse element analysis
    ElementAnalysis? parseElement(dynamic data) {
      if (data == null) return null;
      try {
        return ElementAnalysis.fromJson(data);
      } catch (e) {
        print("Error parsing element analysis: $e");
        return null;
      }
    }

    return Analysis(
      id: json['id'],
      recordingId: json['recording_id'],
      timeOnLearning: json['time_on_learning'] ?? {},
      
      supportiveEnvironmentScore: json['supportive_environment_score'],
      positiveExpectationsScore: json['positive_expectations_score'],
      lessonFacilitationScore: json['lesson_facilitation_score'],
      checksUnderstandingScore: json['checks_understanding_score'],
      feedbackScore: json['feedback_score'],
      criticalThinkingScore: json['critical_thinking_score'],
      autonomyScore: json['autonomy_score'],
      perseveranceScore: json['perseverance_score'],
      socialCollaborativeScore: json['social_collaborative_score'],
      
      supportiveEnvironment: parseElement(json['supportive_environment_behaviors']),
      positiveExpectations: parseElement(json['positive_expectations_behaviors']),
      lessonFacilitation: parseElement(json['lesson_facilitation_behaviors']),
      checksUnderstanding: parseElement(json['checks_understanding_behaviors']),
      feedback: parseElement(json['feedback_behaviors']),
      criticalThinking: parseElement(json['critical_thinking_behaviors']),
      autonomy: parseElement(json['autonomy_behaviors']),
      perseverance: parseElement(json['perseverance_behaviors']),
      socialCollaborative: parseElement(json['social_collaborative_behaviors']),
      
      overallScore: json['overall_score']?.toDouble(),
      summary: json['summary'],
      strengths: List<String>.from(json['strengths'] ?? []),
      areasForImprovement: List<String>.from(json['areas_for_improvement'] ?? []),
      recommendations: (json['recommendations'] as List?)
          ?.map((r) => Recommendation.fromJson(r))
          .toList() ?? [],
      createdAt: DateTime.parse(json['created_at']),
      transcription: json['transcription'] != null 
          ? Transcription.fromJson(json['transcription'])
          : null,
      confidenceFactors: factors,
    );
  }

  Map<String, int> get elementScores => {
    'Supportive Environment': supportiveEnvironmentScore ?? 0,
    'Positive Expectations': positiveExpectationsScore ?? 0,
    'Lesson Facilitation': lessonFacilitationScore ?? 0,
    'Checks Understanding': checksUnderstandingScore ?? 0,
    'Feedback': feedbackScore ?? 0,
    'Critical Thinking': criticalThinkingScore ?? 0,
    'Autonomy': autonomyScore ?? 0,
    'Perseverance': perseveranceScore ?? 0,
    'Social & Collaborative': socialCollaborativeScore ?? 0,
  };
}

class ElementAnalysis {
  final int score;
  final String rationale;
  final String? limitationsNoted;
  final Map<String, BehaviorRating> behaviors;

  ElementAnalysis({
    required this.score,
    required this.rationale,
    this.limitationsNoted,
    required this.behaviors,
  });

  factory ElementAnalysis.fromJson(Map<String, dynamic> json) {
    final Map<String, BehaviorRating> behaviors = {};
    if (json['behaviors'] != null) {
      (json['behaviors'] as Map<String, dynamic>).forEach((key, value) {
        behaviors[key] = BehaviorRating.fromJson(value);
      });
    }

    return ElementAnalysis(
      score: json['score'] ?? 0,
      rationale: json['rationale'] ?? '',
      limitationsNoted: json['limitations_noted'],
      behaviors: behaviors,
    );
  }
}

class BehaviorRating {
  final String rating;
  final String evidence;
  final int? count;
  final List<String> instancesFound;
  final String? limitations;
  final Map<String, String>? subBehaviors;

  BehaviorRating({
    required this.rating,
    required this.evidence,
    this.count,
    this.instancesFound = const [],
    this.limitations,
    this.subBehaviors,
  });

  factory BehaviorRating.fromJson(Map<String, dynamic> json) {
    return BehaviorRating(
      rating: json['rating'] ?? 'N/A',
      evidence: json['evidence'] ?? '',
      count: json['count'],
      instancesFound: List<String>.from(json['instances_found'] ?? []),
      limitations: json['limitations'],
      subBehaviors: json['sub_behaviors'] != null 
          ? Map<String, String>.from(json['sub_behaviors']) 
          : null,
    );
  }
}

class ConfidenceFactors {
  final String audioQuality;
  final String recordingLength;
  final String evidenceCompleteness;
  final List<String> limitations;

  ConfidenceFactors({
    required this.audioQuality,
    required this.recordingLength,
    required this.evidenceCompleteness,
    required this.limitations,
  });

  factory ConfidenceFactors.fromJson(Map<String, dynamic> json) {
    return ConfidenceFactors(
      audioQuality: json['audio_quality'] ?? '',
      recordingLength: json['recording_length'] ?? '',
      evidenceCompleteness: json['evidence_completeness'] ?? '',
      limitations: List<String>.from(json['limitations'] ?? []),
    );
  }
}

class Transcription {
  final String fullText;
  final String? language;
  
  Transcription({required this.fullText, this.language});
  
  factory Transcription.fromJson(Map<String, dynamic> json) {
    return Transcription(
      fullText: json['full_text'] ?? '',
      language: json['language_detected'],
    );
  }
}

class Recommendation {
  final String title;
  final String description;
  final String example;

  Recommendation({
    required this.title,
    required this.description,
    required this.example,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      title: json['title'],
      description: json['description'],
      example: json['example'],
    );
  }
}
