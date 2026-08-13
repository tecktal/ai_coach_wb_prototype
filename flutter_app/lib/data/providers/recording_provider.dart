import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recording.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../../core/l10n/app_strings.dart';
import 'locale_provider.dart';

/// Called when a recording's status changes during polling.
/// [recording] is the updated recording.
/// [previousStatus] is what it was before.
typedef RecordingStatusCallback = void Function(
    Recording recording, String previousStatus);

class RecordingProvider with ChangeNotifier {
  final ApiService _api = ApiService();
  SharedPreferences? _prefs;

  /// Injected so notification text can be localized. Notifications are built
  /// from a background poll with no BuildContext, and AppStrings can be
  /// constructed from a Locale directly. Same pattern as AuthProvider —
  /// see main.dart.
  LocaleProvider? _localeProvider;

  void attachLocaleProvider(LocaleProvider lp) => _localeProvider = lp;

  AppStrings get _strings =>
      AppStrings(_localeProvider?.locale ?? const Locale('en'));
  static const String _localPathKeyPrefix = 'local_path_';
  static const String _cacheKey = 'cached_recordings';

  /// Base key — suffixed with userId so each account's drafts are isolated.
  static const String _localDraftsKeyBase = 'local_draft_recordings';

  /// The user currently active. Set on loadRecordings() / saveLocalDraft().
  String _currentUserId = '';

  /// Per-user draft storage key.
  String get _localDraftsKey => '${_localDraftsKeyBase}_$_currentUserId';

  List<Recording> _recordings = [];
  bool _isLoading = false;
  String? _error;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  /// True while background draft-upload is in progress (used to show
  /// a subtle indicator in the UI without blocking anything).
  bool _isUploadingDrafts = false;

  /// Draft IDs currently being uploaded. Prevents concurrent duplicate uploads
  /// of the same draft when the user taps "Run Analysis" multiple times.
  final Set<String> _uploadingDraftIds = {};

  // Polling
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 12);
  RecordingStatusCallback? onStatusChanged;

  // Track which recording IDs we've already notified about so we don't
  // fire duplicate notifications for the same terminal state.
  final Set<String> _notifiedIds = {};

  List<Recording> get recordings => _recordings;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isUploading => _isUploading;
  double get uploadProgress => _uploadProgress;
  bool get isUploadingDrafts => _isUploadingDrafts;

  /// Returns true while the specific draft is actively being uploaded.
  /// Used by LessonCard to show an 'Uploading…' badge immediately.
  bool isDraftUploading(String draftId) => _uploadingDraftIds.contains(draftId);

  bool get hasProcessingRecordings => _recordings.any(
      (r) => r.isProcessing || r.isPending);

  bool get hasLocalDrafts => _recordings.any((r) => r.isLocalDraft);

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ── Polling ──────────────────────────────────────────────────────────────

  /// Start polling if there are recordings in a non-terminal state.
  void startPollingIfNeeded() {
    if (_pollTimer != null && _pollTimer!.isActive) return;
    if (!hasProcessingRecordings) return;
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollOnce());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollOnce() async {
    if (!hasProcessingRecordings) {
      stopPolling();
      return;
    }

    try {
      final response = await _api.getRecordings();
      final serverRecordings = response.map((r) => Recording.fromJson(r)).toList();

      // Build a map of previous statuses
      final prevMap = {for (var r in _recordings) r.id: r.status};

      // Merge: keep local drafts at the top, replace server recordings
      final drafts = _recordings.where((r) => r.isLocalDraft).toList();
      _recordings = [...drafts, ...serverRecordings];

      // Persist the server portion to cache
      await _prefs?.setString(
          _cacheKey, jsonEncode(serverRecordings.map((r) => r.toJson()).toList()));

      // Use microtask to avoid calling notifyListeners() during a build frame
      Future.microtask(notifyListeners);

      // Fire callbacks and system notifications for status changes.
      // _notifiedIds ensures we fire at most once per terminal event,
      // regardless of which screen is active (including when in background).
      for (final r in serverRecordings) {
        final prev = prevMap[r.id];
        if (prev != null && prev != r.status) {
          // Only act once per terminal state
          final isTerminal = r.isCompleted || r.isFailed || r.isInsufficientAudio;
          if (isTerminal && _notifiedIds.contains(r.id)) continue;
          if (isTerminal) {
            _notifiedIds.add(r.id);
            // ── System notification (works even when user is in another app) ──
            // Text is localized here, not in NotificationService — that service
            // has no BuildContext, and AppStrings builds from a Locale.
            final strings = _strings;
            final notifId = NotificationService.generateNotificationId(r.id);
            final lessonTitle = r.title ?? strings.notifDefaultLessonTitle;
            if (r.isCompleted) {
              NotificationService.showAnalysisSuccess(
                id: notifId,
                title: strings.notifAnalysisReady,
                body: strings.notifBodyAnalysed(lessonTitle),
                payload: r.id,
              );
            } else {
              // Failed or insufficient audio
              NotificationService.showAnalysisFailure(
                id: notifId,
                title: strings.notifAnalysisUnsuccessful,
                body: strings.notifBodyFailed(
                  lessonTitle,
                  reason: strings.notificationHint(r.failureReason),
                ),
                payload: r.id,
              );
            }
          }
          // ── In-app screen callback (only fires when screen is mounted) ──
          onStatusChanged?.call(r, prev);
        }
      }

      // Stop polling if nothing left to watch
      if (!hasProcessingRecordings) stopPolling();
    } catch (_) {
      // Silently ignore poll errors
    }
  }

  // ── Data loading ─────────────────────────────────────────────────────────

  /// Clears all in-memory data. Call this on logout so the next account
  /// cannot see the previous account's recordings or local drafts.
  void clearForLogout() {
    _recordings = [];
    _currentUserId = '';
    _notifiedIds.clear();
    stopPolling();
    notifyListeners();
  }

  Future<void> loadRecordings({bool silent = false, String? userId}) async {
    await _initPrefs();

    // Scope all draft operations to this user.
    if (userId != null && userId.isNotEmpty) {
      _currentUserId = userId;
    }

    // ── Step 1: Render from cache immediately ─────────────────────────────
    // Load local drafts + cached server recordings so the list is visible
    // right away, even before the network responds.
    await _loadLocalDrafts();
    await _loadFromServerCache();

    final hasCachedData = _recordings.isNotEmpty;

    // Only show the spinner if there is absolutely nothing to display yet.
    if (!hasCachedData && !silent) {
      _isLoading = true;
      _error = null;
    }
    if (!silent) notifyListeners(); // Paint whatever we have now

    // ── Step 2: Refresh from network silently in the background ───────────
    try {
      final response = await _api.getRecordings();
      final serverRecordings =
          response.map((r) => Recording.fromJson(r)).toList();

      // Persist fresh data to cache
      await _prefs?.setString(
          _cacheKey,
          jsonEncode(serverRecordings.map((r) => r.toJson()).toList()));

      // Merge: local drafts first, then server recordings
      final drafts = _recordings.where((r) => r.isLocalDraft).toList();
      _recordings = [...drafts, ...serverRecordings];

      _isLoading = false;
      _error = null;
      notifyListeners();
      startPollingIfNeeded();
    } catch (e) {
      _isLoading = false;
      // Keep whatever was loaded from cache — don't wipe the list.
      // Only surface an error if we have nothing at all to show.
      if (!hasCachedData) _error = e.toString();
      notifyListeners();
    }
  }

  /// Restores server-backed recordings from local SharedPreferences cache.
  Future<void> _loadFromServerCache() async {
    await _initPrefs();
    final raw = _prefs?.getString(_cacheKey);
    if (raw != null) {
      try {
        final List decoded = jsonDecode(raw);
        final serverRecordings = decoded.map((r) => Recording.fromJson(r)).toList();
        final drafts = _recordings.where((r) => r.isLocalDraft).toList();
        _recordings = [...drafts, ...serverRecordings];
      } catch (_) {
        // Ignore malformed cache
      }
    }
  }

  // ── Local-draft management ────────────────────────────────────────────────

  /// Saves a recording as a local draft without touching the network.
  /// Returns the created [Recording] so callers can navigate to My Lessons.
  Future<Recording> saveLocalDraft({
    required String localFilePath,
    required String userId,
    required String title,
    String? description,
    String? subject,
    String? observedTeacherName,
    String? gradeLevel,
    required String language,
    required int durationSeconds,
  }) async {
    await _initPrefs();

    // Scope draft storage to this user.
    if (userId.isNotEmpty) _currentUserId = userId;

    final draft = Recording.localDraft(
      localFilePath: localFilePath,
      userId: userId,
      title: title,
      description: description,
      subject: subject,
      observedTeacherName: observedTeacherName,
      gradeLevel: gradeLevel,
      language: language,
      durationSeconds: durationSeconds,
    );

    // Insert at the front of the list so it appears first in My Lessons
    _recordings = [draft, ..._recordings];
    notifyListeners();

    // Persist the full drafts list
    await _persistLocalDrafts();

    return draft;
  }

  /// Loads all persisted local drafts into [_recordings].
  Future<void> _loadLocalDrafts() async {
    await _initPrefs();
    final raw = _prefs?.getString(_localDraftsKey);
    if (raw == null) return;

    try {
      final List decoded = jsonDecode(raw);
      final drafts = decoded
          .map((e) => Recording.fromLocalJson(e as Map<String, dynamic>))
          .toList();

      // Remove old drafts from the list and re-add freshly loaded ones
      _recordings = [
        ...drafts,
        ..._recordings.where((r) => !r.isLocalDraft),
      ];
    } catch (_) {
      // Ignore malformed draft cache
    }
  }

  /// Persists the current in-memory local drafts to SharedPreferences.
  Future<void> _persistLocalDrafts() async {
    await _initPrefs();
    final drafts = _recordings.where((r) => r.isLocalDraft).toList();
    await _prefs?.setString(
      _localDraftsKey,
      jsonEncode(drafts.map((r) => r.toLocalJson()).toList()),
    );
  }

  /// Attempts to upload all local drafts. Called automatically when the
  /// device comes online.  Silently skips drafts that fail (they stay in
  /// the list for the teacher to retry manually).
  Future<void> uploadPendingDrafts() async {
    final drafts = _recordings.where((r) => r.isLocalDraft).toList();
    if (drafts.isEmpty) return;

    _isUploadingDrafts = true;
    notifyListeners();

    for (final draft in drafts) {
      if (draft.localFilePath == null) continue;
      try {
        await _uploadDraft(draft);
      } catch (_) {
        // Silently keep this draft for manual retry
      }
    }

    _isUploadingDrafts = false;
    notifyListeners();
  }

  /// Uploads a single local draft, triggers analysis, replaces it with the
  /// server recording on success, and removes it from the persisted draft list.
  /// Public so individual screens can target a specific draft.
  Future<void> uploadDraft(Recording draft) => _uploadDraft(draft);

  /// Uploads a single local draft, triggers analysis, replaces it with the
  /// server recording on success, and removes it from the persisted draft list.
  Future<void> _uploadDraft(Recording draft) async {
    // ── Concurrent-upload guard ───────────────────────────────────────────────
    // Prevents the same draft from being uploaded multiple times when the user
    // taps "Run Analysis" rapidly or retries before the first attempt finishes.
    if (_uploadingDraftIds.contains(draft.id)) return;
    _uploadingDraftIds.add(draft.id);
    // Notify immediately so My Lessons shows 'Uploading…' badge right away
    // rather than keeping the 'Not uploaded' badge during the upload.
    notifyListeners();

    try {
      final metadata = {
        'title': draft.title ?? 'Untitled Lesson',
        if (draft.description != null) 'description': draft.description!,
        if (draft.subject != null) 'subject': draft.subject!,
        if (draft.observedTeacherName != null)
          'observed_teacher_name': draft.observedTeacherName!,
        if (draft.gradeLevel != null) 'grade_level': draft.gradeLevel!,
        'language': draft.language,
        'duration_seconds': (draft.durationSeconds ?? 0).toString(),
      };

      // Step 1 — Upload the audio file
      final response = await _api.uploadRecording(draft.localFilePath!, metadata);
      final serverRecording = Recording.fromJson(response);

      // Save local path so audio remains playable
      await _initPrefs();
      await _prefs?.setString(
          '$_localPathKeyPrefix${serverRecording.id}', draft.localFilePath!);

      // Replace the draft with the server recording in-place
      _recordings = _recordings
          .map((r) => r.id == draft.id ? serverRecording : r)
          .toList();

      // Remove from persisted drafts
      await _persistLocalDrafts();
      notifyListeners();

      // Step 2 — Trigger the AI analysis pipeline.
      // Without this call the recording sits at "pending" forever and the
      // polling loop never terminates.
      try {
        await _api.analyzeRecording(serverRecording.id);
      } catch (_) {
        // Analysis trigger failed — recording stays at "pending".
        // The teacher can retry from My Lessons.
      }

      startPollingIfNeeded();
    } finally {
      // Always release the lock so the teacher can retry if something went wrong.
      _uploadingDraftIds.remove(draft.id);
    }
  }

  // ── Upload (online / immediate path) ────────────────────────────────────

  Future<bool> uploadRecording(
    String filePath,
    String title,
    String? description,
    String? subject,
    String? gradeLevel,
    String language,
    int durationSeconds, {
    // Named and optional so existing positional callers are unaffected.
    String? observedTeacherName,
  }) async {
    _isUploading = true;
    _uploadProgress = 0.0;
    _error = null;
    notifyListeners();

    try {
      final metadata = {
        'title': title,
        if (description != null) 'description': description,
        if (subject != null) 'subject': subject,
        if (observedTeacherName != null)
          'observed_teacher_name': observedTeacherName,
        if (gradeLevel != null) 'grade_level': gradeLevel,
        'language': language,
        'duration_seconds': durationSeconds.toString(),
      };

      final response = await _api.uploadRecording(filePath, metadata);
      final recording = Recording.fromJson(response);

      // Save local path for retry capabilities
      await _initPrefs();
      await _prefs?.setString('$_localPathKeyPrefix${recording.id}', filePath);

      _recordings.insert(0, recording);
      _isUploading = false;
      _uploadProgress = 1.0;
      notifyListeners();

      // Trigger AI analysis pipeline — without this the recording stays
      // in "pending" forever. Fire-and-forget; polling will track progress.
      try {
        await _api.analyzeRecording(recording.id);
        startPollingIfNeeded();
      } catch (_) {
        // Analysis trigger failed — recording stays pending.
        // Teacher can retry from My Lessons.
      }

      return true;
    } catch (e) {
      _error = e.toString();
      _isUploading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRecording(String id) async {
    final recording = _recordings.firstWhere(
      (r) => r.id == id,
      orElse: () => throw Exception('Not found'),
    );

    // Local drafts can be deleted without any network call
    if (recording.isLocalDraft) {
      _recordings.removeWhere((r) => r.id == id);
      await _persistLocalDrafts();
      notifyListeners();
      return true;
    }

    try {
      await _api.deleteRecording(id);

      await _initPrefs();
      await _prefs?.remove('$_localPathKeyPrefix$id');

      _recordings.removeWhere((r) => r.id == id);
      _notifiedIds.remove(id);
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

  String? getLocalFilePath(String id) {
    // Check in-memory first (covers local drafts and recordings we've cached)
    final recording = getRecordingById(id);
    if (recording?.localFilePath != null) return recording!.localFilePath;
    return _prefs?.getString('$_localPathKeyPrefix$id');
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
