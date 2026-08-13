import 'package:flutter/foundation.dart';

import '../models/coach_script.dart';
import '../services/api_service.dart';

/// Loads and generates the coordinator's seven-block coaching scripts.
///
/// One script per (recording, TEACH element). Scripts are stored server-side, so
/// reopening a prepared element returns what the coordinator read before rather
/// than newly worded questions.
class CoachScriptProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  /// Scripts for the recording currently open, keyed by canonical element key.
  final Map<String, CoachScript> _scripts = {};

  bool _isLoading = false;
  bool _isGenerating = false;
  String? _error;

  /// Element key currently being generated, so the picker can show progress on
  /// the right row.
  String? _generatingElementKey;

  Map<String, CoachScript> get scripts => _scripts;
  bool get isLoading => _isLoading;
  bool get isGenerating => _isGenerating;
  String? get error => _error;
  String? get generatingElementKey => _generatingElementKey;

  CoachScript? scriptFor(String elementKey) => _scripts[elementKey];
  bool hasScriptFor(String elementKey) => _scripts.containsKey(elementKey);

  /// Clears state when moving to a different lesson, so one recording's scripts
  /// never show under another.
  void reset() {
    _scripts.clear();
    _error = null;
    _isLoading = false;
    _isGenerating = false;
    _generatingElementKey = null;
    notifyListeners();
  }

  /// Loads every script already prepared for this recording.
  Future<void> loadScripts(String recordingId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.getCoachScripts(recordingId);
      _scripts
        ..clear()
        ..addEntries(
          response
              .map((json) => CoachScript.fromJson(json))
              .map((script) => MapEntry(script.elementKey, script)),
        );
    } catch (e) {
      _error = e.toString();
      debugPrint('[CoachScript] load failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Generates the script for one element, replacing any previous one.
  /// Returns null on failure; [error] holds the reason.
  Future<CoachScript?> generate(String recordingId, String elementKey) async {
    _isGenerating = true;
    _generatingElementKey = elementKey;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.generateCoachScript(recordingId, elementKey);
      final script = CoachScript.fromJson(response);
      _scripts[elementKey] = script;
      return script;
    } catch (e) {
      _error = e.toString();
      debugPrint('[CoachScript] generate failed for $elementKey: $e');
      return null;
    } finally {
      _isGenerating = false;
      _generatingElementKey = null;
      notifyListeners();
    }
  }

  /// Returns the stored script, generating it only if absent.
  Future<CoachScript?> ensureScript(String recordingId, String elementKey) async {
    final existing = _scripts[elementKey];
    if (existing != null) return existing;
    return generate(recordingId, elementKey);
  }
}
