import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import '../../../data/providers/recording_provider.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/connectivity_provider.dart';
import '../../../data/services/file_storage_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_strings.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final AudioRecorder _recorder = AudioRecorder();
  final FileStorageService _storageService = FileStorageService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _subjectController = TextEditingController();
  final _gradeLevelController = TextEditingController();
  
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _duration = Duration.zero;
  Timer? _timer;
  String? _recordingPath;

  /// True while the save/upload operation is running.
  bool _isSaving = false;

  @override
  void dispose() {
    _recorder.dispose();
    _timer?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _subjectController.dispose();
    _gradeLevelController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (await _recorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(const RecordConfig(), path: path);
      
      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordingPath = path;
      });
      _startTimer();
    }
  }

  Future<void> _pauseRecording() async {
    await _recorder.pause();
    setState(() {
      _isPaused = true;
    });
    _timer?.cancel();
  }

  Future<void> _resumeRecording() async {
    await _recorder.resume();
    setState(() {
      _isPaused = false;
    });
    _startTimer();
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    _timer?.cancel();
    
    if (path != null) {
      // Save permanently to device storage
      final filename = 'ai_coach_recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final permanentPath = await _storageService.saveRecordingToPhone(path, filename);
      
      if (!mounted) return;
      
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _recordingPath = permanentPath ?? path;
      });
      
      if (permanentPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).recordingSavedToDevice)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to save to device storage. Please check permissions.',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _duration = Duration(seconds: _duration.inSeconds + 1);
      });
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null) {
      setState(() {
        _recordingPath = result.files.single.path;
      });
    }
  }

  /// Saves the lesson as a local draft only. No upload, no analysis.
  /// The teacher can come back and run analysis later from My Lessons.
  Future<void> _saveLater() async {
    if (_isSaving) return; // double-tap guard
    if (!_formKey.currentState!.validate() || _recordingPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).pleaseRecordOrSelect)),
      );
      return;
    }

    setState(() => _isSaving = true);

    final recordingProvider = context.read<RecordingProvider>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id ?? '';

    await recordingProvider.saveLocalDraft(
      localFilePath: _recordingPath!,
      userId: userId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      subject: _subjectController.text.trim().isEmpty
          ? null
          : _subjectController.text.trim(),
      gradeLevel: _gradeLevelController.text.trim().isEmpty
          ? null
          : _gradeLevelController.text.trim(),
      language: 'en',
      durationSeconds: _duration.inSeconds,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.of(context).lessonSaved),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Uploads the lesson immediately and triggers AI analysis.
  /// Saves a local draft first (safety net) then uploads it right away.
  Future<void> _saveAndAnalyze() async {
    if (_isSaving) return; // double-tap guard
    if (!_formKey.currentState!.validate() || _recordingPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).pleaseRecordOrSelect)),
      );
      return;
    }

    final isOnline = context.read<ConnectivityProvider>().isOnline;
    if (!isOnline) {
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

    setState(() => _isSaving = true);

    final recordingProvider = context.read<RecordingProvider>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.user?.id ?? '';

    // Step 1 — Save as local draft so it's visible in My Lessons immediately.
    // If the upload fails, the draft stays and the teacher can retry.
    final draft = await recordingProvider.saveLocalDraft(
      localFilePath: _recordingPath!,
      userId: userId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      subject: _subjectController.text.trim().isEmpty
          ? null
          : _subjectController.text.trim(),
      gradeLevel: _gradeLevelController.text.trim().isEmpty
          ? null
          : _gradeLevelController.text.trim(),
      language: 'en',
      durationSeconds: _duration.inSeconds,
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    // Step 2 — Navigate to My Lessons where the draft is already visible.
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.of(context).uploadingForAnalysis),
        duration: const Duration(seconds: 4),
      ),
    );

    // Step 3 — Upload this specific draft and trigger analysis.
    // On success the draft is replaced by the server recording automatically.
    recordingProvider.uploadDraft(draft);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppStrings.of(context).newRecording,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textMain,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Recording card ────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isDark ? Colors.transparent : Colors.grey.shade100),
                  boxShadow: isDark
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    // Mic icon with pulsing animation when recording
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording
                            ? Colors.red.withValues(alpha: 0.1)
                            : Theme.of(context).primaryColor.withValues(alpha: 0.08),
                      ),
                      child: Icon(
                        _isRecording ? Icons.mic_rounded : Icons.mic_none_rounded,
                        size: 64,
                        color: _isRecording
                            ? Colors.red
                            : Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _formatDuration(_duration),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _isRecording
                                ? Colors.red
                                : (isDark ? Colors.white : AppTheme.textMain),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRecording
                          ? (_isPaused ? 'Paused' : 'Recording…')
                          : (_recordingPath != null
                              ? 'Recording ready'
                              : 'Tap to start recording'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                isDark ? Colors.grey[400] : AppTheme.textSub,
                          ),
                    ),
                    const SizedBox(height: 28),
                    if (!_isRecording)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _startRecording,
                            icon: const Icon(Icons.mic_rounded),
                            label: Text(AppStrings.of(context).startRecordingButton),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _pickFile,
                            icon: const Icon(Icons.upload_file_rounded),
                            label: Text(AppStrings.of(context).uploadFile),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).primaryColor,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                              side: BorderSide(
                                  color: Theme.of(context).primaryColor),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildControlButton(
                            icon: _isPaused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded,
                            color: Theme.of(context).primaryColor,
                            onTap: _isPaused ? _resumeRecording : _pauseRecording,
                          ),
                          const SizedBox(width: 24),
                          _buildControlButton(
                            icon: Icons.stop_rounded,
                            color: Colors.red,
                            onTap: _stopRecording,
                            size: 64,
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // ── Details form (visible once a recording is ready) ──────────
              if (_recordingPath != null) ...[
                const SizedBox(height: 28),
                Text(
                  'Lesson Details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textMain,
                      ),
                ),
                const SizedBox(height: 16),
                _buildField(
                  controller: _titleController,
                  label: AppStrings.of(context).lessonTitle,
                  hint: 'e.g., Math Lesson — Fractions',
                  icon: Icons.title_rounded,
                  isDark: isDark,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 12),
                _buildField(
                  controller: _descriptionController,
                  label: AppStrings.of(context).descriptionOptional,
                  hint: 'Brief description of the lesson',
                  icon: Icons.notes_rounded,
                  isDark: isDark,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _buildField(
                  controller: _subjectController,
                  label: AppStrings.of(context).subjectOptional,
                  hint: 'e.g., Mathematics, Science',
                  icon: Icons.school_rounded,
                  isDark: isDark,
                ),
                const SizedBox(height: 12),
                _buildField(
                  controller: _gradeLevelController,
                  label: AppStrings.of(context).gradeLevelOptional,
                  hint: 'e.g., 3rd Grade',
                  icon: Icons.grade_rounded,
                  isDark: isDark,
                ),
                const SizedBox(height: 28),

                // ── Action Buttons ─────────────────────────────────────────
                // Offline notice
                Consumer<ConnectivityProvider>(
                  builder: (_, connectivity, __) {
                    if (connectivity.isOnline) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.wifi_off_rounded,
                              color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You\'re offline. Use "Save for later" — you can run analysis when you reconnect.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade900,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Save & Analyze Now (primary)
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveAndAnalyze,
                  icon: _isSaving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.analytics_rounded),
                  label: Text(_isSaving ? 'Saving…' : 'Save & Analyse Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 12),

                // Save for Later (secondary)
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _saveLater,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(AppStrings.of(context).saveForLater),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? Colors.grey[300]
                        : AppTheme.textSub,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(
                        color: isDark
                            ? Colors.grey[600]!
                            : Colors.grey.shade300),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    double size = 52,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.12),
        ),
        child: Icon(icon, color: color, size: size * 0.55),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      style: TextStyle(color: isDark ? Colors.white : AppTheme.textMain),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon:
            Icon(icon, color: isDark ? Colors.grey[500] : Colors.grey.shade400),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? Colors.grey[700]! : Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
              color: isDark ? Colors.grey[700]! : Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor),
        ),
      ),
    );
  }
}
