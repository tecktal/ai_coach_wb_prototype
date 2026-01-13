import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import 'local_storage_service.dart';

class ApiService {
  late Dio _dio;
  final LocalStorageService _storage = LocalStorageService();

  ApiService() {
    print('ApiService Initializing with LONG TIMEOUTS...');
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.apiBase,
      connectTimeout: const Duration(seconds: 600), // Hardcoded to force update
      receiveTimeout: const Duration(seconds: 600),
      sendTimeout: const Duration(seconds: 600),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          await _storage.clearAll();
        }
        return handler.next(error);
      },
    ));
  }

  // Auth
  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final response = await _dio.post('/auth/register', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get('/auth/me');
    return response.data;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final response = await _dio.put('/auth/me', data: data);
    return response.data;
  }

  // Recordings
  Future<Map<String, dynamic>> uploadRecording(
    String filePath,
    Map<String, String> metadata,
  ) async {
    final formData = FormData.fromMap({
      'audio': await MultipartFile.fromFile(filePath),
      ...metadata,
    });

    final response = await _dio.post('/recordings', data: formData);
    return response.data;
  }

  Future<List<dynamic>> getRecordings() async {
    final response = await _dio.get('/recordings');
    return response.data as List;
  }

  Future<Map<String, dynamic>> getRecording(String id) async {
    final response = await _dio.get('/recordings/$id');
    return response.data;
  }

  Future<void> deleteRecording(String id) async {
    await _dio.delete('/recordings/$id');
  }

  Future<Map<String, dynamic>> analyzeRecording(String recordingId) async {
    final response = await _dio.post('/recordings/$recordingId/analyze');
    return response.data;
  }

  // Analyses
  Future<List<dynamic>> getAnalyses() async {
    final response = await _dio.get('/analyses');
    return response.data as List;
  }

  Future<Map<String, dynamic>> getAnalysis(String analysisId) async {
    final response = await _dio.get('/analyses/$analysisId');
    return response.data;
  }

  // Chat
  Future<Map<String, dynamic>> createChatSession(String? analysisId) async {
    final response = await _dio.post(
      '/chat/sessions',
      data: {'analysis_id': analysisId},
    );
    return response.data;
  }

  Future<Map<String, dynamic>> getChatSession(String sessionId) async {
    final response = await _dio.get('/chat/sessions/$sessionId');
    return response.data;
  }

  Future<Map<String, dynamic>> sendMessage(
    String sessionId,
    String content,
  ) async {
    final response = await _dio.post(
      '/chat/sessions/$sessionId/messages',
      data: {'content': content},
    );
    return response.data;
  }

  // Progress
  Future<Map<String, dynamic>> getProgress() async {
    final response = await _dio.get('/progress');
    return response.data;
  }

  Future<Map<String, dynamic>> getTrends() async {
    final response = await _dio.get('/progress/trends');
    return response.data;
  }
}
