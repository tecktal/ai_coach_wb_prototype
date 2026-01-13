import 'package:flutter/foundation.dart';
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

  Future<void> loadAnalyses() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.getAnalyses();
      _analyses = response.map((a) => Analysis.fromJson(a)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> analyzeRecording(String recordingId) async {
    _isAnalyzing = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.analyzeRecording(recordingId);
      
      // Check if this is an async acknowledgement (contains 'status': 'processing')
      if (response.containsKey('status') && response['status'] == 'processing') {
         // Async start successful
         _isAnalyzing = false;
         notifyListeners();
         return true;
      }

      // If it returns a full analysis object (fallback or future sync mode)
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

  Future<void> loadAnalysis(String analysisId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.getAnalysis(analysisId);
      _currentAnalysis = Analysis.fromJson(response);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
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
}
