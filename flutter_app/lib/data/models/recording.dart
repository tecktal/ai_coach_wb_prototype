class Recording {
  final String id;
  final String userId;
  final String? title;
  final String? description;
  final String fileUrl;
  final int? fileSizeBytes;
  final int? durationSeconds;
  final String? subject;
  final String? gradeLevel;
  final String language;
  final String status;
  final DateTime? recordedAt;
  final DateTime createdAt;

  Recording({
    required this.id,
    required this.userId,
    this.title,
    this.description,
    required this.fileUrl,
    this.fileSizeBytes,
    this.durationSeconds,
    this.subject,
    this.gradeLevel,
    required this.language,
    required this.status,
    this.recordedAt,
    required this.createdAt,
  });

  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      description: json['description'],
      fileUrl: json['file_url'],
      fileSizeBytes: json['file_size_bytes'],
      durationSeconds: json['duration_seconds'],
      subject: json['subject'],
      gradeLevel: json['grade_level'],
      language: json['language'] ?? 'en',
      status: json['status'],
      recordedAt: json['recorded_at'] != null 
          ? DateTime.parse(json['recorded_at']) 
          : null,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  bool get isPending => status == 'pending';
  bool get isProcessing => status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  String get statusDisplay {
    switch (status) {
      case 'pending':
        return 'Pending Analysis';
      case 'processing':
        return 'Analyzing...';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      default:
        return status;
    }
  }

  String get durationDisplay {
    if (durationSeconds == null) return 'Unknown';
    final minutes = durationSeconds! ~/ 60;
    final seconds = durationSeconds! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
