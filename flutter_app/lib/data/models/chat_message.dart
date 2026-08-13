class ChatMessage {
  final String id;
  final String content;
  final String role; // 'user' or 'assistant'
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.content,
    required this.role,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'],
      content: json['content'],
      role: json['role'] == 'model' ? 'assistant' : json['role'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'content': content,
    'role': role,
    'created_at': createdAt.toIso8601String(),
  };

  bool get isUser => role == 'user';
}
