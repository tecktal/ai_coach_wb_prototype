class Recording {
  final String id;
  final String userId;
  final String? title;
  final String? description;
  final String fileUrl;
  final int? fileSizeBytes;
  final int? durationSeconds;
  final String recordingType;
  final String? subject;
  /// Set when a coordinator records a lesson taught by someone else.
  final String? observedTeacherName;
  final String? gradeLevel;
  final String language;
  final String status;
  final String? failureReason; // too_short, insufficient_content, service_error, etc.
  final String? errorMessage; // Human-readable error message
  final DateTime? recordedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Offline / local-draft support ────────────────────────────────────────
  /// True when this recording exists only on the device and has not yet
  /// been uploaded to the server.
  final bool isLocalDraft;

  /// Absolute file-system path to the audio file.  Present for local drafts
  /// and also stored alongside server-backed recordings so we can play them
  /// offline (and retry failed uploads).
  final String? localFilePath;

  const Recording({
    required this.id,
    required this.userId,
    this.title,
    this.description,
    required this.fileUrl,
    this.fileSizeBytes,
    this.durationSeconds,
    required this.recordingType,
    this.subject,
    this.observedTeacherName,
    this.gradeLevel,
    required this.language,
    required this.status,
    this.failureReason,
    this.errorMessage,
    this.recordedAt,
    required this.createdAt,
    required this.updatedAt,
    this.isLocalDraft = false,
    this.localFilePath,
  });

  // ── Server response constructor ───────────────────────────────────────────
  factory Recording.fromJson(Map<String, dynamic> json) {
    return Recording(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      description: json['description'],
      fileUrl: json['file_url'],
      fileSizeBytes: json['file_size_bytes'],
      durationSeconds: json['duration_seconds'],
      recordingType: json['recording_type'] ?? 'audio',
      subject: json['subject'],
      observedTeacherName: json['observed_teacher_name'],
      gradeLevel: json['grade_level'],
      language: json['language'] ?? 'en',
      status: json['status'],
      failureReason: json['failure_reason'],
      errorMessage: json['error_message'],
      recordedAt: json['recorded_at'] != null
          ? DateTime.parse(json['recorded_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  // ── Local-draft factory ──────────────────────────────────────────────────
  /// Creates a Recording that lives only on-device.  A temporary UUID-like id
  /// is generated from the current timestamp so it is unique per session.
  factory Recording.localDraft({
    required String localFilePath,
    required String userId,
    required String title,
    String? description,
    String? subject,
    String? observedTeacherName,
    String? gradeLevel,
    required String language,
    required int durationSeconds,
  }) {
    final now = DateTime.now();
    return Recording(
      id: 'local_${now.millisecondsSinceEpoch}',
      userId: userId,
      title: title,
      description: description,
      fileUrl: localFilePath, // points to the on-device file
      durationSeconds: durationSeconds,
      recordingType: 'audio',
      subject: subject,
      observedTeacherName: observedTeacherName,
      gradeLevel: gradeLevel,
      language: language,
      status: 'local_draft',
      createdAt: now,
      updatedAt: now,
      isLocalDraft: true,
      localFilePath: localFilePath,
    );
  }

  // ── Serialisation for server payloads ─────────────────────────────────────
  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'title': title,
    'description': description,
    'file_url': fileUrl,
    'file_size_bytes': fileSizeBytes,
    'duration_seconds': durationSeconds,
    'recording_type': recordingType,
    'subject': subject,
    'observed_teacher_name': observedTeacherName,
    'grade_level': gradeLevel,
    'language': language,
    'status': status,
    'failure_reason': failureReason,
    'error_message': errorMessage,
    'recorded_at': recordedAt?.toIso8601String(),
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  // ── Serialisation for local SharedPreferences storage ────────────────────
  Map<String, dynamic> toLocalJson() => {
    'id': id,
    'user_id': userId,
    'title': title,
    'description': description,
    'local_file_path': localFilePath,
    'duration_seconds': durationSeconds,
    'subject': subject,
    'observed_teacher_name': observedTeacherName,
    'grade_level': gradeLevel,
    'language': language,
    'created_at': createdAt.toIso8601String(),
  };

  factory Recording.fromLocalJson(Map<String, dynamic> json) {
    final path = json['local_file_path'] as String;
    final now = DateTime.parse(json['created_at'] as String);
    return Recording(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      fileUrl: path,
      durationSeconds: json['duration_seconds'] as int?,
      recordingType: 'audio',
      subject: json['subject'] as String?,
      observedTeacherName: json['observed_teacher_name'] as String?,
      gradeLevel: json['grade_level'] as String?,
      language: json['language'] as String? ?? 'en',
      status: 'local_draft',
      createdAt: now,
      updatedAt: now,
      isLocalDraft: true,
      localFilePath: path,
    );
  }

  // ── Status helpers ────────────────────────────────────────────────────────
  bool get isPending => status == 'pending';
  bool get isProcessing => status == 'processing';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isInsufficientAudio => status == 'insufficient_audio';

  String get statusDisplay {
    switch (status) {
      case 'local_draft':
        return 'Saved Locally';
      case 'pending':
        return 'Pending Analysis';
      case 'processing':
        return 'Analyzing...';
      case 'completed':
        return 'Completed';
      case 'failed':
        return 'Failed';
      case 'insufficient_audio':
        return 'Recording Too Short';
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
