import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/analysis.dart';
import '../services/api_service.dart';

class AnalysisProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  List<Analysis> _analyses = [];
  Analysis? _currentAnalysis;
  bool _isLoading = false;
  bool _isAnalyzing = false;
  String? _error;

  List<Analysis> get analyses => _analyses;
  Analysis? get currentAnalysis => _currentAnalysis;
  bool get isLoading => _isLoading;
  bool get isAnalyzing => _isAnalyzing;
  String? get error => _error;

  // ── Cache keys ──────────────────────────────────────────────────────────
  static const String _analysesListKey = 'cached_analyses_list';
  static const String _analysisPrefix = 'cached_analysis_'; // + id

  // ── Load the analyses list ───────────────────────────────────────────────

  Future<void> loadAnalyses() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.getAnalyses();
      // Cache raw JSON list for offline access
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_analysesListKey, jsonEncode(response));
      _analyses = response.map((a) => Analysis.fromJson(a)).toList();
    } catch (e) {
      _error = e.toString();
      // Restore from cache so the list doesn't go blank offline
      if (_analyses.isEmpty) {
        await _restoreAnalysesList();
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _restoreAnalysesList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_analysesListKey);
      if (raw != null) {
        final List decoded = jsonDecode(raw);
        _analyses = decoded
            .map((a) => Analysis.fromJson(a as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {
      // Ignore malformed cache
    }
  }

  // ── Load a single analysis detail ────────────────────────────────────────
  // This is the key offline method: teachers tap a lesson to see its detail.

  Future<void> loadAnalysis(String analysisId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.getAnalysis(analysisId);
      // Cache raw JSON keyed by analysis ID
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_analysisPrefix$analysisId', jsonEncode(response));
      _currentAnalysis = Analysis.fromJson(response);
    } catch (e) {
      _error = e.toString();
      // Try restoring from local cache
      final cached = await _restoreSingleAnalysis(analysisId);
      if (cached != null) {
        _currentAnalysis = cached;
        _error = null; // suppress network error — we have local data
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Analysis?> _restoreSingleAnalysis(String analysisId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_analysisPrefix$analysisId');
      if (raw != null) {
        return Analysis.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      // Ignore
    }
    return null;
  }

  // ── Analyze (requires internet — always online operation) ────────────────

  Future<bool> analyzeRecording(String recordingId) async {
    _isAnalyzing = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.analyzeRecording(recordingId);

      if (response.containsKey('status') && response['status'] == 'processing') {
        _isAnalyzing = false;
        notifyListeners();
        return true;
      }

      final analysis = Analysis.fromJson(response);
      _analyses.insert(0, analysis);
      _currentAnalysis = analysis;
      _isAnalyzing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isAnalyzing = false;
      notifyListeners();
      return false;
    }
  }

  void setCurrentAnalysis(Analysis analysis) {
    _currentAnalysis = analysis;
    notifyListeners();
  }

  Analysis? getAnalysisById(String id) {
    try {
      return _analyses.firstWhere((a) => a.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
