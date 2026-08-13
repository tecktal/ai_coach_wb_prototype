import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_message.dart';
import '../services/api_service.dart';

class ChatProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  List<ChatMessage> _messages = [];
  String? _currentSessionId;
  bool _isLoading = false;
  bool _isStreaming = false;
  String? _error;

  List<ChatMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isStreaming => _isStreaming;
  String? get error => _error;
  String? get currentSessionId => _currentSessionId;

  List<dynamic> _sessions = [];
  List<dynamic> get sessions => _sessions;

  static const String _sessionsCacheKey = 'cached_chat_sessions';
  static const String _messagesPrefix = 'cached_messages_'; // + sessionId

  // ── Sessions ──────────────────────────────────────────────────────────────

  Future<void> loadSessions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _sessions = await _api.getChatSessions();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sessionsCacheKey, jsonEncode(_sessions));
    } catch (e) {
      _error = e.toString();
      if (_sessions.isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          final raw = prefs.getString(_sessionsCacheKey);
          if (raw != null) {
            _sessions = jsonDecode(raw) as List<dynamic>;
          }
        } catch (_) {}
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> initSession(String? analysisId) async {
    _messages = [];
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (analysisId != null) {
        await loadSessions();

        final existingSession = _sessions.firstWhere(
          (s) => s['analysis_id'] == analysisId,
          orElse: () => null,
        );

        if (existingSession != null) {
          final sessionId = existingSession['id'] as String;
          await loadChatSession(sessionId);
          return;
        }
      }

      final data = await _api.createChatSession(analysisId);
      _currentSessionId = data['id'];

      if (data['messages'] != null) {
        _messages = (data['messages'] as List)
            .map((m) => ChatMessage.fromJson(m))
            .toList();
      } else {
        _messages = [];
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadChatSession(String sessionId) async {
    _messages = [];
    _isLoading = true;
    _error = null;
    _currentSessionId = sessionId;
    notifyListeners();

    try {
      final data = await _api.getChatSession(sessionId);
      _currentSessionId = data['session']['id'];

      if (data['messages'] != null) {
        _messages = (data['messages'] as List)
            .map((m) => ChatMessage.fromJson(m))
            .toList();
      } else {
        _messages = [];
      }
      await _cacheMessages(sessionId);
    } catch (e) {
      _error = e.toString();
      final restored = await _restoreMessages(sessionId);
      if (restored.isNotEmpty) {
        _messages = restored;
        _error = null;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Message cache helpers ─────────────────────────────────────────────────

  Future<void> _cacheMessages(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_messages.map((m) => m.toJson()).toList());
      await prefs.setString('$_messagesPrefix$sessionId', encoded);
    } catch (_) {}
  }

  Future<List<ChatMessage>> _restoreMessages(String sessionId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_messagesPrefix$sessionId');
      if (raw != null) {
        final List decoded = jsonDecode(raw);
        return decoded
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ── Send message ──────────────────────────────────────────────────────────

  Future<void> sendMessage(String content, {String? language}) async {
    if (_currentSessionId == null) return;

    // Add user message immediately so it appears in the chat.
    _messages.add(ChatMessage(
      id: DateTime.now().toString(),
      content: content,
      role: 'user',
      createdAt: DateTime.now(),
    ));

    _isLoading = true;
    _isStreaming = true;
    notifyListeners(); // Shows user message + typing indicator; no AI bubble yet.

    final aiTempId = 'ai_${DateTime.now().millisecondsSinceEpoch}';
    String fullContent = '';

    try {
      final stream = _api.streamChatResponse(_currentSessionId!, content);

      // Buffer silently — no per-chunk notifyListeners().
      //
      // Previously, MarkdownBody was re-rendered on every SSE chunk. Because
      // chunks arrive mid-sentence, mid-list, and mid-header, the markdown
      // parser produced broken visuals (split bold, unclosed lists, truncated
      // headers) that only resolved once the full text was received.
      //
      // Now we buffer the entire response and render it once on completion.
      // The _TypingIndicator widget stays visible for the full duration.
      await for (final chunk in stream) {
        if (chunk.trim() == '[DONE]' || chunk.trim().isEmpty) continue;
        fullContent += chunk;
      }

      // ── DIAGNOSTIC: what the provider assembled ──────────────────────────
      debugPrint('[Chat] Stream complete. fullContent length=${fullContent.length}');
      if (fullContent.isNotEmpty) {
        debugPrint('[Chat] FIRST 100: ${fullContent.substring(0, fullContent.length.clamp(0, 100))}');
        debugPrint('[Chat]  LAST 100: ${fullContent.substring((fullContent.length - 100).clamp(0, fullContent.length))}');
      }

      // Stream complete — add the finished, fully-formatted AI message at once.
      if (fullContent.isNotEmpty) {
        _messages.add(ChatMessage(
          id: aiTempId,
          content: fullContent,
          role: 'assistant',
          createdAt: DateTime.now(),
        ));
      }
    } catch (e) {
      _error = e.toString();

      // If we received partial content before the error, keep it with a notice.
      // If nothing arrived, add a clean error message.
      final errorContent = fullContent.isNotEmpty
          ? '$fullContent\n\n_[Response interrupted. Please try again.]_'
          : '_[Could not complete the response. Please try again.]_';

      _messages.add(ChatMessage(
        id: aiTempId,
        content: errorContent,
        role: 'assistant',
        createdAt: DateTime.now(),
      ));
    } finally {
      _isLoading = false;
      _isStreaming = false;
      if (_currentSessionId != null) {
        await _cacheMessages(_currentSessionId!);
      }
      notifyListeners(); // One render: typing indicator out, full response in.
    }
  }

  // ── Delete session ────────────────────────────────────────────────────────

  Future<void> deleteSession(String sessionId) async {
    try {
      await _api.deleteChatSession(sessionId);
      _sessions.removeWhere((s) => s['id'] == sessionId);
      if (_currentSessionId == sessionId) {
        _messages = [];
        _currentSessionId = null;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  /// Resets all in-memory chat state on logout.
  /// SharedPreferences is wiped by LocalStorageService.clearAll().
  /// Call this before navigating to the login screen so the old user's
  /// sessions never flash on screen for the next user.
  void clearUserData() {
    _sessions = [];
    _messages = [];
    _currentSessionId = null;
    _isLoading = false;
    _isStreaming = false;
    _error = null;
    notifyListeners();
  }
}
