/// Who the user is. Mirrors the backend `users.role` column.
///
/// Distinct from [FeedbackAudience]: role is durable identity — it drives the
/// World Bank's reporting and the app's labelling, and only an admin can change
/// it. Audience is a preference the user can flip whenever they like.
class UserRole {
  /// Records their own lessons. The default.
  static const teacher = 'teacher';

  /// A pedagogy coordinator who observes other teachers' lessons.
  static const coordinator = 'coordinator';

  /// Monitoring-dashboard roles. Never self-assignable at registration.
  static const viewer = 'viewer';
  static const admin = 'admin';

  /// The only roles a user may choose for themselves when signing up.
  static const selfAssignable = [teacher, coordinator];
}

/// Who the AI writes its feedback for. Mirrors the backend's
/// `gemini.AudienceTeacher` / `AudienceCoordinator`.
class FeedbackAudience {
  /// Addressed to the teacher ("You used clear language..."). The default.
  static const teacher = 'teacher';

  /// Written about the teacher, for a coach to lead a conversation from.
  static const coordinator = 'coordinator';

  static const values = [teacher, coordinator];
}

class User {
  final String id;
  final String username;
  final String? email;
  final String firstName;
  final String lastName;
  final String? schoolName;
  final String? country;
  final String languagePreference;

  /// One of [UserRole]. Durable identity — set at registration, changed only by
  /// an admin. Drives labelling and the World Bank's reporting.
  final String role;

  /// One of [FeedbackAudience.values]. Changes only how the AI phrases its
  /// feedback, not what it analyses.
  final String feedbackAudience;

  final bool emailVerified;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    this.email,
    required this.firstName,
    required this.lastName,
    this.schoolName,
    this.country,
    required this.languagePreference,
    this.role = UserRole.teacher,
    this.feedbackAudience = FeedbackAudience.teacher,
    this.emailVerified = false,
    required this.createdAt,
  });

  /// True when this account is a pedagogy coordinator. Drives labelling and
  /// which screens the app offers.
  bool get isCoordinator => role == UserRole.coordinator;

  /// True when the AI should write about the teacher rather than to them.
  /// Usually follows [isCoordinator], but a user can override it in Profile —
  /// e.g. a coordinator who wants teacher-voiced output to hand over directly.
  bool get isCoordinatorAudience =>
      feedbackAudience == FeedbackAudience.coordinator;

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'],
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      schoolName: json['school_name'],
      country: json['country'],
      languagePreference: json['language_preference'] ?? 'en',
      role: json['role'] ?? UserRole.teacher,
      // Unknown or absent values fall back to teacher, matching the backend.
      feedbackAudience:
          FeedbackAudience.values.contains(json['feedback_audience'])
              ? json['feedback_audience']
              : FeedbackAudience.teacher,
      emailVerified: json['email_verified'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'school_name': schoolName,
      'country': country,
      'language_preference': languagePreference,
      'role': role,
      'feedback_audience': feedbackAudience,
      'email_verified': emailVerified,
      'created_at': createdAt.toIso8601String(), // required for cache restore
    };
  }

  String get fullName => '$firstName $lastName';
}
