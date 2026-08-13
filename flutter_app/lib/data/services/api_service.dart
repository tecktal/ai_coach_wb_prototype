import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/api_constants.dart';
import 'local_storage_service.dart';

class ApiService {
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  
  late Dio _dio;
  final LocalStorageService _storage = LocalStorageService();

  ApiService._internal() {

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
      // NOTE: 401 handling is intentionally NOT done here.
      // Auto-clearing the token from the interceptor caused silent session wipes
      // when any API call failed (recordings, analyses, etc.) — even with a valid token.
      // Logout is handled explicitly by AuthProvider.logout() and clearAll().
    ));
  }
  
  // Cleanup method (call when app is disposed if needed)
  void dispose() {
    _dio.close();
  }

  // Auth
  Future<Map<String, dynamic>> register(Map<String, dynamic> data) async {
    final response = await _dio.post('/auth/register', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'username': username, 'password': password},
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

  Future<void> verifyEmail(String email, String code) async {
    await _dio.post(
      '/auth/verify-email',
      data: {'email': email, 'code': code},
    );
  }

  Future<void> resendVerification(String email) async {
    await _dio.post(
      '/auth/resend-verification',
      data: {'email': email},
    );
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post(
      '/auth/forgot-password',
      data: {'email': email},
    );
  }

  Future<void> resetPassword(String token, String newPassword) async {
    await _dio.post(
      '/auth/reset-password',
      data: {'token': token, 'new_password': newPassword},
    );
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

  // Coaching scripts (coordinator flow)

  /// Returns the stored script for one element, or null if not generated yet.
  Future<Map<String, dynamic>?> getCoachScript(
    String recordingId,
    String elementKey,
  ) async {
    final response = await _dio.get(
      '/recordings/$recordingId/coach-script',
      queryParameters: {'element': elementKey},
    );
    return response.data as Map<String, dynamic>?;
  }

  /// Every element already prepared for this recording.
  Future<List<dynamic>> getCoachScripts(String recordingId) async {
    final response = await _dio.get('/recordings/$recordingId/coach-scripts');
    return response.data as List;
  }

  /// Generates (or regenerates) the script for one element. Synchronous —
  /// it runs over the stored analysis, not the audio.
  Future<Map<String, dynamic>> generateCoachScript(
    String recordingId,
    String elementKey,
  ) async {
    final response = await _dio.post(
      '/recordings/$recordingId/coach-script',
      data: {'element_key': elementKey},
    );
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
    try {

      final response = await _dio.post(
        '/chat/sessions',
        data: {'analysis_id': analysisId},
      );

      return response.data;
    } catch (e) {

      if (e is DioException) {
        // No print statements here
      }
      rethrow;
    }
  }

  Future<List<dynamic>> getChatSessions() async {
    final response = await _dio.get('/chat/sessions');
    return response.data as List;
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

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _dio.post(
      '/auth/change-password',
      data: {'current_password': currentPassword, 'new_password': newPassword},
    );
  }

  Stream<String> streamChatResponse(String sessionId, String content) async* {
    try {
      final response = await _dio.post(
        '/chat/sessions/$sessionId/stream',
        data: {'content': content},
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Accept': 'text/event-stream',
          },
        ),
      );
      final stream = response.data.stream as Stream<List<int>>;
      int chunkIndex = 0;
      int totalBytesReceived = 0;
      int totalDataLinesYielded = 0;
      final StringBuffer assembledBuffer = StringBuffer();
      String leftover = '';   // carries incomplete lines across chunk boundaries
      String? eventData;      // null = no data: lines seen yet for this event
      String eventName = '';  // current SSE event type (e.g. 'message', 'done')

      await for (final chunk in stream) {
        chunkIndex++;
        totalBytesReceived += chunk.length;
        final String text = utf8.decode(chunk, allowMalformed: true);

        // ── DIAGNOSTIC LOG: raw chunk ──────────────────────────────────────
        final preview = text.length > 80 ? '${text.substring(0, 80)}...' : text;
        debugPrint('[SSE] Chunk #$chunkIndex (${chunk.length}B): '
            '${preview.replaceAll('\n', '\\n').replaceAll('\r', '\\r')}');

        // Combine leftover from previous chunk with new text
        final combined = leftover + text;
        leftover = '';

        // Normalise line endings (SSE allows \r\n, \n, or \r)
        final normalised = combined.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
        final lines = normalised.split('\n');

        // The last element may be an incomplete line — save for next chunk
        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i];

          if (line.startsWith('event:')) {
            // Track event type — used to filter out 'done' events below.
            eventName = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            // Strip 'data:' prefix (5 chars, NO space — Gin doesn't add one).
            final content = line.substring(5);
            // Use null-vs-string to distinguish "no data seen" from "empty data".
            // This lets empty data: lines properly contribute \n separators.
            eventData = eventData == null ? content : '$eventData\n$content';
          } else if (line.isEmpty) {
            // ── Blank line = end of SSE event ─────────────────────────────
            // Only yield 'message' events — 'done' carries "Stream finished"
            // which must never appear in chat content.
            if (eventName == 'message' && eventData != null && eventData.isNotEmpty) {
              debugPrint('[SSE] Event yielded (${eventData.length}B): '
                  '${eventData.length > 60 ? eventData.substring(0, 60) : eventData}');
              assembledBuffer.write(eventData);
              totalDataLinesYielded++;
              yield eventData;
            }
            // Reset for next event
            eventData = null;
            eventName = '';
          }
        }
        leftover = lines.last;
      }

      // Flush any remaining data after stream ends (no trailing blank line)
      if (leftover.startsWith('data:')) {
        final content = leftover.substring(5);
        eventData = eventData == null ? content : '$eventData\n$content';
      }
      if (eventName == 'message' && eventData != null && eventData.isNotEmpty) {
        debugPrint('[SSE] Final flush (${eventData.length}B): '
            '${eventData.length > 60 ? eventData.substring(0, 60) : eventData}');
        assembledBuffer.write(eventData);
        totalDataLinesYielded++;
        yield eventData;
      }

      // ── DIAGNOSTIC SUMMARY ────────────────────────────────────────────────
      final full = assembledBuffer.toString();
      debugPrint('[SSE] Stream done. Chunks=$chunkIndex, Bytes=$totalBytesReceived, '
          'Events=$totalDataLinesYielded, AssembledLen=${full.length}');
      if (full.isNotEmpty) {
        debugPrint('[SSE] FIRST 100: ${full.substring(0, full.length.clamp(0, 100))}');
        debugPrint('[SSE]  LAST 100: ${full.substring((full.length - 100).clamp(0, full.length))}');
      }
    } catch (e) {
      debugPrint('[SSE] ERROR: $e');
      rethrow;
    }
  }

  Future<void> deleteChatSession(String sessionId) async {
    await _dio.delete('/chat/sessions/$sessionId');
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
