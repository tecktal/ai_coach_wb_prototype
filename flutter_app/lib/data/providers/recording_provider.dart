import 'package:flutter/foundation.dart';
import '../models/recording.dart';
import '../services/api_service.dart';

class RecordingProvider with ChangeNotifier {
  final ApiService _api = ApiService();

  List<Recording> _recordings = [];
  bool _isLoading = false;
  String? _error;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  List<Recording> get recordings => _recordings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;

  Future<void> loadRecordings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.getRecordings();
      _recordings = response.map((r) => Recording.fromJson(r)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> uploadRecording(
    String filePath,
    String title,
    String? description,
    String? subject,
    String? gradeLevel,
    String language,
  ) async {
    _isUploading = true;
    _uploadProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      final metadata = {
        'title': title,
        if (description != null) 'description': description,
        if (subject != null) 'subject': subject,
        if (gradeLevel != null) 'grade_level': gradeLevel,
        'language': language,
      };

      final response = await _api.uploadRecording(filePath, metadata);
      final recording = Recording.fromJson(response);
      _recordings.insert(0, recording);
      
      _isUploading = false;
      _uploadProgress = 1.0;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRecording(String id) async {
    try {
      await _api.deleteRecording(id);
      _recordings.removeWhere((r) => r.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Recording? getRecordingById(String id) {
    try {
      return _recordings.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }
}
