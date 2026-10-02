import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';

import 'widgets/pulsing_mic_button.dart';
import 'widgets/recording_timer.dart';
import 'widgets/wave_visualizer.dart';
import '../../widgets/design/custom_text_field.dart';
import '../../widgets/design/primary_button.dart';
import '../../widgets/app_toast.dart';
import '../../../../core/theme/app_theme.dart';
import '../../widgets/country_customization.dart';
import '../../widgets/country_dropdown.dart';
import '../../widgets/offline_banner.dart';

import '../../../data/services/file_storage_service.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/recording_provider.dart';
import '../../../data/providers/analysis_provider.dart';
import '../../../data/providers/connectivity_provider.dart';

import '../recording/recordings_list_screen.dart';
import '../chat/chats_list_screen.dart';
import '../profile/profile_screen.dart';
import 'package:ai_coach/core/l10n/app_strings.dart';
import '../../../core/roles/role_copy.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isRecordingActive = false;

  List<Widget> get _screens => [
    _RecordingTab(
      onRecordingStateChanged: _onRecordingStateChanged,
      onBackRequested: _onRecordingBackRequested,
    ),
    const RecordingsListScreen(),
    const ChatsListScreen(),
    const ProfileScreen(),
  ];

  void _onRecordingStateChanged(bool isRecording) {
    setState(() {
      _isRecordingActive = isRecording;
    });
  }

  // Stored by the recording tab so we can call _confirmDiscard from outside
  VoidCallback? _confirmDiscardCallback;

  void _onRecordingBackRequested() {
    _confirmDiscardCallback?.call();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final recordingProvider = context.read<RecordingProvider>();
    final analysisProvider = context.read<AnalysisProvider>();
    final userId = context.read<AuthProvider>().user?.id;
    await Future.wait([
      recordingProvider.loadRecordings(userId: userId),
      analysisProvider.loadAnalyses(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final needsVerification = user != null && !user.emailVerified;

    Widget profileIcon(bool selected) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            selected ? Icons.person_rounded : Icons.person_outline_rounded,
            color: selected ? Theme.of(context).primaryColor : null,
          ),
          if (needsVerification)
            Positioned(
              top: -2,
              right: -4,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    width: 1.5,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return PopScope(
      // Prevent default back while recording — show discard dialog instead
      canPop: !_isRecordingActive,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isRecordingActive) {
          _onRecordingBackRequested();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: IndexedStack(
          index: _selectedIndex,
          children: _screens,
        ),
        bottomNavigationBar: _isRecordingActive ? null : NavigationBar(
          selectedIndex: _selectedIndex,
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          indicatorColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
          surfaceTintColor: Colors.transparent,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.mic_none_rounded),
              selectedIcon: Icon(Icons.mic_rounded, color: Theme.of(context).primaryColor),
              label: RoleCopy.of(context).navRecord,
            ),
            NavigationDestination(
              icon: const Icon(Icons.analytics_outlined),
              selectedIcon: Icon(Icons.analytics_rounded, color: Theme.of(context).primaryColor),
              label: RoleCopy.of(context).navLessons,
            ),
            NavigationDestination(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded, color: Theme.of(context).primaryColor),
              label: AppStrings.of(context).navChats,
            ),
            NavigationDestination(
              icon: profileIcon(false),
              selectedIcon: profileIcon(true),
              label: AppStrings.of(context).navProfile,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingTab extends StatefulWidget {
  final ValueChanged<bool>? onRecordingStateChanged;
  final VoidCallback? onBackRequested;
  
  const _RecordingTab({
    this.onRecordingStateChanged,
    this.onBackRequested,
  });

  @override
  State<_RecordingTab> createState() => _RecordingTabState();
}

class _RecordingTabState extends State<_RecordingTab> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FileStorageService _storageService = FileStorageService();

  bool _isRecording = false;
  bool _isPaused = false;
  bool _isLocked = false;
  bool _isProcessing = false;
  /// Tracks which CTA button is actively running so each shows its own state.
  bool _savingNow = false;
  bool _savingLater = false;

  // bool _isPlaying = false;
  // Duration _playbackDuration = Duration.zero;
  // Duration _playbackPosition = Duration.zero;

  Duration _duration = Duration.zero;
  Timer? _timer;

  String? _recordingPath;

  final _titleController = TextEditingController();
  final _subjectController = TextEditingController(); // Used as grade or dropdown logic
  /// Name of the teacher whose lesson this is, when a coordinator recorded it.
  final _observedTeacherController = TextEditingController();
  final _gradeController = TextEditingController();
  
  String _selectedSubject = 'Math';
  final List<String> _subjects = ['Math', 'Science', 'English', 'History', 'Art', 'Other'];
  final TextEditingController _customSubjectController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    /*
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _playbackDuration = d);
    });
    
    _audioPlayer.onPositionChanged.listen((p) {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastPositionUpdate < 250) return; 
      
      _lastPositionUpdate = now;
      if (mounted) {
        setState(() => _playbackPosition = p);
      }
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playbackPosition = Duration.zero;
        });
      }
    });
    */
  }

  @override
  void dispose() {
    _recorder.dispose();
    _audioPlayer.dispose();
    _timer?.cancel();
    _titleController.dispose();
    _subjectController.dispose();
    _observedTeacherController.dispose();
    _customSubjectController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  String _getLocalizedSubject(BuildContext context, String subjectKey) {
    final strings = AppStrings.of(context);
    switch (subjectKey) {
      case 'Math': return strings.subjectMath;
      case 'Science': return strings.subjectScience;
      case 'English': return strings.subjectEnglish;
      case 'History': return strings.subjectHistory;
      case 'Art': return strings.subjectArt;
      case 'Other': return strings.subjectOther;
      default: return subjectKey;
    }
  }

  Future<void> _startRecording() async {
    try {
      final user = context.read<AuthProvider>().user;
      if (await _recorder.hasPermission()) {
        if (!mounted) return;
        final dir = await getTemporaryDirectory();
        
        final timestamp = DateTime.now();
        final formattedDate = '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';
        final formattedTime = '${timestamp.hour.toString().padLeft(2, '0')}-${timestamp.minute.toString().padLeft(2, '0')}-${timestamp.second.toString().padLeft(2, '0')}';
        
        String sanitize(String text) => text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        
        final firstName = sanitize(user?.firstName ?? 'Teacher');
        final lastName = sanitize(user?.lastName ?? 'User');
        
        final filename = '${firstName}_${lastName}_${formattedDate}_$formattedTime.m4a';
        final path = '${dir.path}/$filename';

        await _recorder.start(const RecordConfig(), path: path);

        setState(() {
          _isRecording = true;
          _isPaused = false;
          _recordingPath = path;
          if (_titleController.text.isEmpty) {
            _titleController.text = 'Lesson ${DateTime.now().toString().split('.')[0]}';
          }
        });
        
        widget.onRecordingStateChanged?.call(true);
        _startTimer();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).genericError(e))));
      }
    }
  }

  Future<void> _pauseRecording() async {
    await _recorder.pause();
    setState(() => _isPaused = true);
    _timer?.cancel();
  }

  Future<void> _resumeRecording() async {
    await _recorder.resume();
    setState(() => _isPaused = false);
    _startTimer();
  }

  Future<void> _stopRecording() async {
    if (_isLocked) return;

    try {
      final isRecording = await _recorder.isRecording();
      if (!isRecording) {
        setState(() { _isRecording = false; _isPaused = false; });
        widget.onRecordingStateChanged?.call(false);
        return;
      }

      final path = await _recorder.stop();
      _timer?.cancel();      
      String? permanentPath;
      if (path != null) {
        // Save permanently
        final filename = 'ai_coach_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
        permanentPath = await _storageService.saveRecordingToPhone(path, filename);
        
        if (permanentPath != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.of(context).recordingSavedToDevice)),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.of(context).couldNotSaveRecording,
                  style: const TextStyle(color: Colors.white)),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      Duration? duration;
      final activePath = permanentPath ?? path;
      if (activePath != null) {
        try {
          await _audioPlayer.setSource(DeviceFileSource(activePath));
          duration = await _audioPlayer.getDuration();
        } catch (e) {
          // ignore audio load error
        }
      }

      setState(() {
        _isRecording = false;
        _isPaused = false;
        _recordingPath = activePath;
        if (duration != null) _duration = duration;
      });
      widget.onRecordingStateChanged?.call(false);
      _initPlayback();
    } catch (e) {
      setState(() { _isRecording = false; _isPaused = false; });
      widget.onRecordingStateChanged?.call(false);
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _duration = Duration(seconds: _duration.inSeconds + 1));
    });
  }

  Future<void> _importAudio() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m4a', 'mp3', 'wav', 'aac'],
      );

      if (result != null && result.files.single.path != null) {
        final rawPath = result.files.single.path!;
        
        // Save permanently so retries don't fail when cache clears
        final filename = 'ai_coach_imported_${DateTime.now().millisecondsSinceEpoch}.${result.files.single.extension ?? 'm4a'}';
        final permanentPath = await _storageService.saveRecordingToPhone(rawPath, filename);
        final activePath = permanentPath ?? rawPath;
        
        if (permanentPath != null && mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(AppStrings.of(context).importedAudioCopied)),
           );
        }

        await _audioPlayer.setSource(DeviceFileSource(activePath));
        final duration = await _audioPlayer.getDuration() ?? Duration.zero;

        setState(() {
          _recordingPath = activePath;
          _isRecording = false;
          _duration = duration; 
          if (_titleController.text.isEmpty) {
             _titleController.text = result.files.single.name;
          }
        });
        _initPlayback();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).errorImportingFile(e))));
      }
    }
  }

  /// Saves the recording as a local draft only — no upload, no analysis.
  /// The teacher can come back and trigger analysis from My Lessons.
  Future<void> _saveLater() async {
    if (_isProcessing || _savingLater) return; // double-tap guard
    if (_recordingPath == null) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _savingLater = true);

    final recordingProvider = context.read<RecordingProvider>();
    final userId = context.read<AuthProvider>().user?.id ?? '';

    try {
      await recordingProvider.saveLocalDraft(
        localFilePath: _recordingPath!,
        userId: userId,
        title: _titleController.text.trim(),
        subject: _selectedSubject == 'Other'
            ? _customSubjectController.text.trim()
            : _selectedSubject,
        gradeLevel: _gradeController.text.trim(),
        observedTeacherName: _observedTeacherController.text.trim().isEmpty
            ? null
            : _observedTeacherController.text.trim(),
        language: Localizations.localeOf(context).languageCode,
        durationSeconds: _duration.inSeconds,
      );

      if (!mounted) return;

      setState(() {
        _savingLater = false;
        _isProcessing = false;
        _recordingPath = null;
        _duration = Duration.zero;
        _isPlaying = false;
        _playbackPosition = Duration.zero;
        _playbackDuration = Duration.zero;
        _titleController.clear();
        _gradeController.clear();
        // Must be cleared too: a coordinator's next lesson is usually a
        // different teacher, and a stale name would file it against the wrong
        // person without anything on screen suggesting it had carried over.
        _observedTeacherController.clear();
        _customSubjectController.clear();
      });
      widget.onRecordingStateChanged?.call(false);

      AppToast.show(
        context,
        message: AppStrings.of(context).lessonSaved,
        type: ToastType.info,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      if (mounted) {
        setState(() { _savingLater = false; _isProcessing = false; });
        AppToast.show(context, message: '${AppStrings.of(context).failedToSave}: $e', type: ToastType.error);
      }
    }
  }

  /// Saves the recording as a local draft, then immediately uploads and
  /// triggers AI analysis. The draft is visible in My Lessons right away;
  /// if the upload fails it stays there so the teacher can retry.
  Future<void> _saveAndAnalyze() async {
    if (_isProcessing || _savingNow || _savingLater) return; // double-tap guard
    if (_recordingPath == null) return;
    if (!_formKey.currentState!.validate()) return;

    final isOnline = context.read<ConnectivityProvider>().isOnline;
    if (!isOnline) {
      // Offer to save for later instead
      final saveLater = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppStrings.of(context).noInternetTitle),
          content: Text(AppStrings.of(context).noInternetAnalysis),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.of(context).cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppStrings.of(context).saveForLater),
            ),
          ],
        ),
      );
      if (saveLater == true) _saveLater();
      return;
    }

    setState(() => _savingNow = true);

    final recordingProvider = context.read<RecordingProvider>();
    final userId = context.read<AuthProvider>().user?.id ?? '';

    try {
      // Step 1 — Save as local draft first so it's visible in My Lessons
      // immediately. If the upload fails the draft stays and the teacher can retry.
      final draft = await recordingProvider.saveLocalDraft(
        localFilePath: _recordingPath!,
        userId: userId,
        title: _titleController.text.trim(),
        subject: _selectedSubject == 'Other'
            ? _customSubjectController.text.trim()
            : _selectedSubject,
        gradeLevel: _gradeController.text.trim(),
        observedTeacherName: _observedTeacherController.text.trim().isEmpty
            ? null
            : _observedTeacherController.text.trim(),
        language: Localizations.localeOf(context).languageCode,
        durationSeconds: _duration.inSeconds,
      );

      if (!mounted) return;

      // Reset the UI — lesson is now safe in My Lessons as a draft.
      setState(() {
        _savingNow = false;
        _isProcessing = false;
        _recordingPath = null;
        _duration = Duration.zero;
        _isPlaying = false;
        _playbackPosition = Duration.zero;
        _playbackDuration = Duration.zero;
        _titleController.clear();
        _gradeController.clear();
        // Must be cleared too: a coordinator's next lesson is usually a
        // different teacher, and a stale name would file it against the wrong
        // person without anything on screen suggesting it had carried over.
        _observedTeacherController.clear();
        _customSubjectController.clear();
      });
      widget.onRecordingStateChanged?.call(false);

      AppToast.show(
        context,
        message: AppStrings.of(context).uploadingForAnalysis,
        type: ToastType.success,
        duration: const Duration(seconds: 4),
      );

      // Step 2 — Upload THIS specific draft only and trigger analysis.
      // On success the draft is replaced by the server recording automatically.
      recordingProvider.uploadDraft(draft);
    } catch (e) {
      if (mounted) {
        setState(() { _savingNow = false; _isProcessing = false; });
        AppToast.show(context, message: '${AppStrings.of(context).failedToSaveLesson}: $e', type: ToastType.error);
      }
    }
  }

  // ── Playback state ──
  bool _isPlaying = false;
  Duration _playbackDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;

  Future<void> _togglePlayback() async {
    if (_recordingPath == null) return;
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.play(DeviceFileSource(_recordingPath!));
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _initPlayback() async {
    if (_recordingPath == null) return;
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _playbackDuration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _playbackPosition = p);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() { _isPlaying = false; _playbackPosition = Duration.zero; });
    });
    await _audioPlayer.setSource(DeviceFileSource(_recordingPath!));
    final dur = await _audioPlayer.getDuration();
    if (dur != null && mounted) setState(() => _playbackDuration = dur);
  }

  String _formatDur(Duration d) =>
      '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Future<void> _confirmDiscard() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.of(context).discardRecording),
        content: Text(AppStrings.of(context).discardRecordingMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.of(context).keep)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppStrings.of(context).discard, style: const TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      if (_isRecording) {
        await _recorder.stop();
        _timer?.cancel();
        widget.onRecordingStateChanged?.call(false);
      }
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _recordingPath = null;
        _duration = Duration.zero;
        _isPlaying = false;
        _playbackPosition = Duration.zero;
        _playbackDuration = Duration.zero;
      });
    }
  }

  // ── LOADING OVERLAY ───────────────────────────────────────────────────────
  Widget _buildLoadingOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textMain;
    final subColor = isDark ? Colors.white60 : AppTheme.textSub;

    return Container(
      color: bg,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pulsing icon
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.85, end: 1.0),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeInOut,
                  builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.3), width: 2),
                    ),
                    child: Icon(Icons.cloud_upload_rounded, color: Theme.of(context).primaryColor, size: 44),
                  ),
                ),
                const SizedBox(height: 32),

                Text(
                  AppStrings.of(context).uploadingLesson,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: textColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  AppStrings.of(context).uploadingSubtitle,
                  style: TextStyle(fontSize: 15, color: subColor, height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Animated dots
                _AnimatedDots(color: Theme.of(context).primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return _buildLoadingOverlay();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isActiveState = _isRecording || _recordingPath != null;

    // Register our discard callback so HomeScreen can call it on back gesture
    if (widget.onBackRequested != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // We expose _confirmDiscard via the parent's stored reference
        (context.findAncestorStateOfType<_HomeScreenState>())?._confirmDiscardCallback = _confirmDiscard;
      });
    }

    Widget content;
    if (_isRecording) {
      content = _buildRecordingScreen(isDark);
    } else if (_recordingPath != null) {
      content = _buildReviewScreen(isDark);
    } else {
      return _buildIdleScreen(isDark);
    }

    return content;
  }

  // ── IDLE SCREEN ──────────────────────────────────────────────────────────
  Widget _buildIdleScreen(bool isDark) {
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textMain;
    final subColor = isDark ? Colors.white60 : AppTheme.textSub;

    final user = context.watch<AuthProvider>().user;
    final country = user?.country;
    final isCustomizedCountry = CountryCustomization.isCustomized(country);
    final accentColor = CountryCustomization.getAccentColor(country);

    return Container(
      color: bg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Offline indicator — slides in when device has no internet
            const OfflineBanner(),
            if (isCustomizedCountry) ...[

              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(countryFlag(country), style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(
                      country!,
                      style: TextStyle(
                        color: isDark ? Colors.white : accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Spacer(flex: 3),

            // ── Mic button ──
            PulsingMicButton(
              onTap: _startRecording,
              isRecording: false,
              showLabel: false,
              accentColor: isCustomizedCountry ? accentColor : null,
            ),
            const SizedBox(height: 36),

            Text(
              RoleCopy.of(context).recordPrompt,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                RoleCopy.of(context).recordPromptSub,
                style: TextStyle(fontSize: 16, color: subColor, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ),

            const Spacer(flex: 3),

            // ── OR divider + import ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  Expanded(child: Divider(color: isDark ? Colors.grey[700] : Colors.grey.shade300)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('OR', style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey.shade500, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  Expanded(child: Divider(color: isDark ? Colors.grey[700] : Colors.grey.shade300)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: OutlinedButton.icon(
                onPressed: _importAudio,
                icon: Icon(Icons.upload_file_rounded, size: 20),
                label: Text(AppStrings.of(context).importAudio, style: const TextStyle(fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  side: BorderSide(color: isDark ? Colors.grey[600]! : AppTheme.borderLight),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  foregroundColor: isDark ? Colors.white : AppTheme.textMain,
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // ── RECORDING SCREEN ─────────────────────────────────────────────────────
  Widget _buildRecordingScreen(bool isDark) {
    final bg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textMain;
    final hintColor = isDark ? Colors.white38 : AppTheme.textSub.withValues(alpha: 0.5);

    return Container(
      color: bg,
      child: SafeArea(
        child: Stack(
          children: [
            // ── All content absorbed when locked (except the lock toggle below) ──
            AbsorbPointer(
              absorbing: _isLocked,
              child: Column(
                children: [
                  // ── Back button — hidden when locked to avoid banner overlap ──
                  if (!_isLocked)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8, left: 8),
                        child: IconButton(
                          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white70 : AppTheme.textSub),
                          onPressed: _confirmDiscard,
                          tooltip: AppStrings.of(context).discardRecordingTooltip,
                        ),
                      ),
                    ),

                  // ── Floating lock badge — sits between back btn and timer ──
                  AnimatedOpacity(
                    opacity: _isLocked ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: IgnorePointer(
                      child: Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded, size: 13,
                                color: Theme.of(context).primaryColor),
                            const SizedBox(width: 6),
                            Text(
                              AppStrings.of(context).screenLocked,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).primaryColor,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Timer
                  Text(
                    _formatDur(_duration),
                    style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w200,
                      color: textColor,
                      letterSpacing: 4,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Status indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isPaused ? Colors.amber : AppTheme.errorColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isPaused
                            ? AppStrings.of(context).recordingPaused.toUpperCase()
                            : AppStrings.of(context).recording.toUpperCase(),
                        style: TextStyle(
                          color: _isPaused ? Colors.amber : AppTheme.errorColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),

                  const Spacer(flex: 1),

                  // Wave visualizer
                  WaveVisualizer(isRecording: _isRecording, isPaused: _isPaused),

                  const Spacer(flex: 1),

                  // Controls row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Pause / Resume
                      _RecordingControlBtn(
                        icon: _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        size: 64,
                        isDark: isDark,
                        onTap: _isPaused ? _resumeRecording : _pauseRecording,
                      ),
                      const SizedBox(width: 32),
                      // Stop
                      GestureDetector(
                        onTap: _stopRecording,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: _isLocked ? Colors.grey : AppTheme.errorColor,
                            shape: BoxShape.circle,
                            boxShadow: _isLocked ? [] : [
                              BoxShadow(
                                color: AppTheme.errorColor.withValues(alpha: 0.4),
                                blurRadius: 24,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: Icon(Icons.stop_rounded, color: Colors.white, size: 36),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Spacer placeholder so lock toggle (positioned outside) stays in flow
                  const SizedBox(height: 56),

                  const Spacer(flex: 1),
                ],
              ),
            ),

            // ── Lock toggle — always interactive, sits on top ──
            Positioned(
              bottom: MediaQuery.of(context).size.height * 0.10,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() => _isLocked = !_isLocked),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      color: _isLocked
                          ? Theme.of(context).primaryColor.withValues(alpha: 0.15)
                          : (isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.06)),
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        width: 1.5,
                        color: _isLocked
                            ? Theme.of(context).primaryColor.withValues(alpha: 0.6)
                            : (isDark ? Colors.white30 : Colors.black.withValues(alpha: 0.15)),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                          size: 20,
                          color: _isLocked ? Theme.of(context).primaryColor : (isDark ? Colors.white70 : AppTheme.textSub),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _isLocked
                              ? AppStrings.of(context).unlockTooltip
                              : AppStrings.of(context).lockTooltip,
                          style: TextStyle(
                            fontSize: 15,
                            color: _isLocked ? Theme.of(context).primaryColor : (isDark ? Colors.white70 : AppTheme.textSub),
                            fontWeight: _isLocked ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // (banner replaced by inline pill badge above)
          ],
        ),
      ),
    );
  }

  // ── REVIEW SCREEN ────────────────────────────────────────────────────────
  Widget _buildReviewScreen(bool isDark) {
    final totalSecs = _playbackDuration.inSeconds;
    final posSecs = _playbackPosition.inSeconds.clamp(0, totalSecs > 0 ? totalSecs : 1);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                AppStrings.of(context).reviewRecording,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textMain,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                AppStrings.of(context).uploadingSubtitle,
                style: TextStyle(color: isDark ? Colors.grey[400] : AppTheme.textSub),
              ),
              const SizedBox(height: 24),

              // ── Audio Player ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Theme.of(context).primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _togglePlayback,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                  activeTrackColor: Theme.of(context).primaryColor,
                                  inactiveTrackColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                                  thumbColor: Theme.of(context).primaryColor,
                                ),
                                child: Slider(
                                  value: posSecs.toDouble(),
                                  max: totalSecs > 0 ? totalSecs.toDouble() : 1,
                                  onChanged: (v) async {
                                    await _audioPlayer.seek(Duration(seconds: v.toInt()));
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(_formatDur(_playbackPosition), style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : AppTheme.textSub)),
                                    Text(_formatDur(_playbackDuration), style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : AppTheme.textSub)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    CustomTextField(
                      label: AppStrings.of(context).lessonTitle,
                      controller: _titleController,
                      hint: 'e.g., Algebra 101',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.of(context).subject.toUpperCase(),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSub, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : AppTheme.surfaceLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? Colors.transparent : AppTheme.borderLight),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedSubject,
                              isExpanded: true,
                              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                              items: _subjects.map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  _getLocalizedSubject(context, s),
                                  style: TextStyle(color: isDark ? Colors.white : AppTheme.textMain),
                                ),
                              )).toList(),
                              onChanged: (v) => setState(() => _selectedSubject = v!),
                            ),
                          ),
                        ),
                        // Free-text input revealed when "Other" is selected
                        AnimatedCrossFade(
                          duration: const Duration(milliseconds: 200),
                          crossFadeState: _selectedSubject == 'Other'
                              ? CrossFadeState.showSecond
                              : CrossFadeState.showFirst,
                          firstChild: const SizedBox.shrink(),
                          secondChild: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: TextFormField(
                              controller: _customSubjectController,
                              decoration: InputDecoration(
                                hintText: AppStrings.of(context).subjectHint,
                                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey.shade400),
                                filled: true,
                                fillColor: isDark ? const Color(0xFF1E293B) : AppTheme.surfaceLight,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: isDark ? Colors.transparent : AppTheme.borderLight),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: isDark ? Colors.transparent : AppTheme.borderLight),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                              style: TextStyle(color: isDark ? Colors.white : AppTheme.textMain),
                              validator: (v) => _selectedSubject == 'Other' && (v == null || v.trim().isEmpty)
                                  ? 'Please enter the subject'
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: AppStrings.of(context).gradeLevel,
                      controller: _gradeController,
                      hint: 'e.g., 9th Grade',
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    // Coordinators record lessons someone else taught, so the
                    // teacher has to be named. A teacher recording her own
                    // lesson has no one to name — hence the audience check.
                    if (context.read<AuthProvider>().user?.isCoordinatorAudience ??
                        false) ...[
                      const SizedBox(height: 16),
                      CustomTextField(
                        label: AppStrings.of(context).observedTeacher,
                        controller: _observedTeacherController,
                        hint: AppStrings.of(context).observedTeacherHint,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // ── Offline notice ──
              Consumer<ConnectivityProvider>(
                builder: (_, connectivity, __) {
                  if (connectivity.isOnline) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off_rounded, color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AppStrings.of(context).offlineMessage,
                              style: TextStyle(fontSize: 13, color: Colors.orange.shade900, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // ── Save & Analyse Now (primary, animated) ─────────────────────
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _savingLater ? 0.45 : 1.0,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_savingNow || _savingLater) ? null : _saveAndAnalyze,
                    icon: _savingNow
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.analytics_rounded),
                    label: Text(_savingNow ? '${AppStrings.of(context).uploadingLesson}…' : AppStrings.of(context).saveAndAnalyze),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          Theme.of(context).primaryColor.withValues(alpha: _savingNow ? 0.85 : 0.45),
                      disabledForegroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Save for Later (secondary, animated) ───────────────────────
              Consumer<ConnectivityProvider>(
                builder: (_, connectivity, __) => AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _savingNow ? 0.45 : 1.0,
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: (_savingNow || _savingLater) ? null : _saveLater,
                      icon: _savingLater
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFF64748B)),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_savingLater ? '${AppStrings.of(context).saveLater}…' : AppStrings.of(context).saveForLater),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSub,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: BorderSide(
                            color: _savingNow
                                ? Colors.grey.shade200
                                : Colors.grey.shade300),
                        textStyle:
                            const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: _confirmDiscard,
                  child: Text(AppStrings.of(context).discard, style: const TextStyle(color: AppTheme.errorColor)),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Small helper widget for recording control buttons ─────────────────────
class _RecordingControlBtn extends StatelessWidget {
  final IconData icon;
  final double size;
  final bool isDark;
  final VoidCallback onTap;

  const _RecordingControlBtn({required this.icon, required this.size, required this.isDark, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
          shape: BoxShape.circle,
          border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
        ),
        child: Icon(icon, color: isDark ? Colors.white : AppTheme.textMain, size: size * 0.45),
      ),
    );
  }
}


//  Animated loading dots 
class _AnimatedDots extends StatefulWidget {
  final Color color;
  const _AnimatedDots({required this.color});

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
      Future.delayed(Duration(milliseconds: i * 180), () {
        if (mounted) ctrl.repeat(reverse: true);
      });
      return ctrl;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (_, __) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 5),
            width: 10,
            height: 10 + _controllers[i].value * 10,
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.4 + _controllers[i].value * 0.6),
              borderRadius: BorderRadius.circular(50),
            ),
          ),
        );
      }),
    );
  }
}
