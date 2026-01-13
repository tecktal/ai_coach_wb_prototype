class User {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? schoolName;
  final String? country;
  final String languagePreference;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.schoolName,
    this.country,
    required this.languagePreference,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      email: json['email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      schoolName: json['school_name'],
      country: json['country'],
      languagePreference: json['language_preference'] ?? 'en',
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'school_name': schoolName,
      'country': country,
      'language_preference': languagePreference,
    };
  }

  String get fullName => '$firstName $lastName';
}
