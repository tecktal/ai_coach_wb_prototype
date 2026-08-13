class ApiConstants {

  static const String baseUrl = 'https://coach.senecole.com';
  
  // API version
  static const String apiVersion = 'v1';
  
  // Full API base
  static const String apiBase = '$baseUrl/api/$apiVersion';
  
  // Auth endpoints
  static const String register = '$apiBase/auth/register';
  static const String login = '$apiBase/auth/login';
  static const String me = '$apiBase/auth/me';
  
  // Recording endpoints
  static const String recordings = '$apiBase/recordings';
  static String recordingDetail(String id) => '$recordings/$id';
  static String analyzeRecording(String id) => '$recordings/$id/analyze';
  
  // Analysis endpoints
  static const String analyses = '$apiBase/analyses';
  static String analysisDetail(String id) => '$analyses/$id';
  
  // Chat endpoints
  static const String chatSessions = '$apiBase/chat/sessions';
  static String chatSession(String id) => '$chatSessions/$id';
  static String chatMessages(String id) => '$chatSessions/$id/messages';
  
  // Progress endpoints
  static const String progress = '$apiBase/progress';
  static const String progressTrends = '$progress/trends';
  
  // Health check
  static const String health = '$apiBase/health';
  
  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 300);
  static const Duration receiveTimeout = Duration(seconds: 300);
}
