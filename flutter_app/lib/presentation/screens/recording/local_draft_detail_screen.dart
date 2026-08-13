import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import '../../../data/models/recording.dart';
import '../../../data/providers/recording_provider.dart';
import '../../../data/providers/connectivity_provider.dart';
import '../../../data/services/api_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../widgets/offline_banner.dart';
import '../../widgets/app_toast.dart';
import '../../../core/l10n/app_strings.dart';


/// Shown when a teacher taps a lesson that needs action:
///   • Local draft (not yet uploaded)
///   • Failed server recording
///   • Pending server recording (uploaded but analyze not triggered)
///
/// Shows lesson details + audio player + state-appropriate action button.
class LocalDraftDetailScreen extends StatefulWidget {
  final Recording recording;
  /// Cached local audio path for server recordings. Null for remote-only.
  final String? localFilePath;

  const LocalDraftDetailScreen({
    super.key,
    required this.recording,
    this.localFilePath,
  });

  @override
  State<LocalDraftDetailScreen> createState() => _LocalDraftDetailScreenState();
}

class _LocalDraftDetailScreenState extends State<LocalDraftDetailScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isPlaying = false;
  Duration _playbackDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  bool _isTriggering = false;

  /// Effective audio path: prefer the passed localFilePath, fall back to the
  /// one stored on the Recording model (set for local drafts).
  String? get _audioPath => widget.localFilePath ?? widget.recording.localFilePath;

  @override
  void initState() {
    super.initState();
    _initAudio();

    // Pre-set duration from metadata
    if (widget.recording.durationSeconds != null &&
        widget.recording.durationSeconds! > 0) {
      _playbackDuration =
          Duration(seconds: widget.recording.durationSeconds!);
    }
  }

  void _initAudio() {
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _playbackDuration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _playbackPosition = p);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playbackPosition = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    final path = _audioPath;
    if (path == null) return;

    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.play(DeviceFileSource(path));
      setState(() => _isPlaying = true);
    }
  }

  /// Unified action handler:
  ///   • Local draft → full upload + analysis pipeline
  ///   • Server recording (failed / pending) → re-trigger analysis only
  Future<void> _runAnalysis() async {
    setState(() => _isTriggering = true);

    final recording = widget.recording;
    final provider = context.read<RecordingProvider>();

    try {
      if (recording.isLocalDraft) {
        // Upload the audio file then trigger analysis.
        await provider.uploadDraft(recording);
      } else {
        // Already on the server — just re-trigger the analysis pipeline.
        await ApiService().analyzeRecording(recording.id);
        provider.startPollingIfNeeded();
      }
    } catch (e) {
      if (mounted) setState(() => _isTriggering = false);
      if (mounted) {
        AppToast.show(
          context,
          message: AppStrings.of(context).draftUploadFailed(e.toString()),
          type: ToastType.error,
          duration: const Duration(seconds: 4),
        );
      }
      return;
    }

    if (!mounted) return;

    AppToast.show(
      context,
      message: recording.isLocalDraft
          ? AppStrings.of(context).draftUploadedAnalyzing
          : AppStrings.of(context).draftAnalysisRetriggered,
      type: ToastType.info,
      duration: const Duration(seconds: 4),
    );

    Navigator.of(context).pop();
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
    final isOnline = context.watch<ConnectivityProvider>().isOnline;
    final recording = widget.recording;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          recording.title ?? AppStrings.of(context).untitledLesson,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textMain,
              ),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: AppStrings.of(context).back,
          icon: Icon(Icons.arrow_back_ios_new,
              size: 20, color: isDark ? Colors.white : AppTheme.textMain),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── State-aware status banner ────────────────────────────
                  _buildStatusBanner(isDark),

                  const SizedBox(height: 28),

                  // ── Lesson metadata ─────────────────────────────────────
                  _buildSectionLabel(AppStrings.of(context).draftSectionLessonDetails, isDark),
                  const SizedBox(height: 12),
                  _buildInfoCard(isDark, [
                    _InfoRow(
                      icon: Icons.title_rounded,
                      label: AppStrings.of(context).draftInfoTitle,
                      value: recording.title ?? AppStrings.of(context).untitledLesson,
                    ),
                    if (recording.subject != null)
                      _InfoRow(
                        icon: Icons.school_rounded,
                        label: AppStrings.of(context).draftInfoSubject,
                        value: recording.subject!,
                      ),
                    if (recording.gradeLevel != null)
                      _InfoRow(
                        icon: Icons.grade_rounded,
                        label: AppStrings.of(context).draftInfoGrade,
                        value: recording.gradeLevel!,
                      ),
                    _InfoRow(
                      icon: Icons.calendar_today_rounded,
                      label: AppStrings.of(context).draftInfoRecorded,
                      value: DateFormat('MMM d, yyyy – HH:mm')
                          .format(recording.createdAt),
                    ),
                    if (recording.durationSeconds != null)
                      _InfoRow(
                        icon: Icons.timer_rounded,
                        label: AppStrings.of(context).draftInfoDuration,
                        value: recording.durationDisplay,
                      ),
                    if (recording.description != null &&
                        recording.description!.isNotEmpty)
                      _InfoRow(
                        icon: Icons.notes_rounded,
                        label: AppStrings.of(context).draftInfoNotes,
                        value: recording.description!,
                      ),
                  ]),

                  const SizedBox(height: 28),

                  // ── Audio player ────────────────────────────────────────
                  _buildSectionLabel(AppStrings.of(context).draftSectionLessonAudio, isDark),
                  const SizedBox(height: 12),
                  _buildAudioPlayer(isDark),

                  const SizedBox(height: 32),

                  // ── Analysis CTA ────────────────────────────────────────
                  _buildSectionLabel(AppStrings.of(context).draftSectionAnalysis, isDark),
                  const SizedBox(height: 12),

                  // Drive disabled state from the provider so it survives
                  // the user leaving and returning to this screen mid-upload.
                  Builder(builder: (context) {
                    final providerUploading = widget.recording.isLocalDraft &&
                        context.watch<RecordingProvider>().isDraftUploading(widget.recording.id);
                    final effectivelyBusy = _isTriggering || providerUploading;

                    if (!isOnline) return _buildOfflineNotice(isDark);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildRunAnalysisButton(isDark, effectivelyBusy, providerUploading),

                        // Friendly note while upload is in progress
                        if (providerUploading)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              AppStrings.of(context).draftUploadInProgress,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[500] : Colors.grey.shade500,
                                height: 1.5,
                              ),
                            ),
                          ),

                        // 'Try again later' note — only shown when analysis failed
                        if (!providerUploading &&
                            (widget.recording.isFailed || widget.recording.isInsufficientAudio))
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(
                              AppStrings.of(context).draftIfKeepsFailing,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.grey[500] : Colors.grey.shade500,
                                height: 1.5,
                              ),
                            ),
                          ),
                      ],
                    );
                  }),


                  // ── Data-persistence notice ──────────────────────────────
                  const SizedBox(height: 16),
                  _buildDataPersistenceNotice(isDark),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: isDark ? Colors.grey[400] : AppTheme.textSub,
          ),
    );
  }

  Widget _buildInfoCard(bool isDark, List<_InfoRow> rows) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.transparent : Colors.grey.shade100),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            rows[i].build(context, isDark),
            if (i < rows.length - 1)
              Divider(
                height: 24,
                color: isDark ? Colors.grey[800] : Colors.grey.shade100,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudioPlayer(bool isDark) {
    final maxMs = _playbackDuration.inMilliseconds > 0
        ? _playbackDuration.inMilliseconds.toDouble()
        : (widget.recording.durationSeconds != null &&
                widget.recording.durationSeconds! > 0
            ? widget.recording.durationSeconds! * 1000.0
            : 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? Colors.transparent : Colors.grey.shade100),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              tooltip: _isPlaying ? 'Pause audio' : 'Play audio',
              icon: Icon(_isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded),
              color: Theme.of(context).primaryColor,
              iconSize: 32,
              onPressed: _audioPath != null ? _togglePlayback : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.of(context).draftLessonAudioLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textMain,
                      ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 4,
                    activeTrackColor: Theme.of(context).primaryColor,
                    inactiveTrackColor:
                        isDark ? Colors.grey[700] : Colors.grey.shade200,
                    thumbColor: Theme.of(context).primaryColor,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: _playbackPosition.inMilliseconds
                        .clamp(0, maxMs.toInt())
                        .toDouble(),
                    max: maxMs,
                    onChanged: (v) =>
                        _audioPlayer.seek(Duration(milliseconds: v.toInt())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_playbackPosition),
                        style: TextStyle(
                            fontSize: 10,
                            color:
                                isDark ? Colors.grey[400] : Colors.grey),
                      ),
                      Text(
                        _playbackDuration.inMilliseconds > 0
                            ? _formatDuration(_playbackDuration)
                            : (widget.recording.durationSeconds != null
                                ? _formatDuration(Duration(
                                    seconds:
                                        widget.recording.durationSeconds!))
                                : '--:--'),
                        style: TextStyle(
                            fontSize: 10,
                            color:
                                isDark ? Colors.grey[400] : Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _actionButtonLabel() {
    if (widget.recording.isFailed || widget.recording.isInsufficientAudio) {
      return AppStrings.of(context).draftRetryAnalysis;
    }
    return AppStrings.of(context).runAnalysis;
  }

  Widget _buildStatusBanner(bool isDark) {
    if (widget.recording.isFailed || widget.recording.isInsufficientAudio) {
      final msg = widget.recording.isInsufficientAudio
          ? AppStrings.of(context).draftStatusTooShort
          : AppStrings.of(context).draftStatusFailed;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.errorColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: AppTheme.errorColor, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(msg,
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFFFC8181) : AppTheme.errorColor,
                      height: 1.4)),
            ),
          ],
        ),
      );
    }

    if (widget.recording.isPending) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.hourglass_top_rounded, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(AppStrings.of(context).draftStatusPending,
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                      height: 1.4)),
            ),
          ],
        ),
      );
    }

    // Default: local draft
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF64748B).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF64748B).withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_upload_outlined, color: Color(0xFF64748B), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              AppStrings.of(context).draftStatusSavedLocally,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunAnalysisButton(bool isDark, bool isDisabled, bool isUploading) {
    final String label;
    if (isUploading) {
      label = AppStrings.of(context).draftUploadingWait;
    } else if (isDisabled) {
      label = AppStrings.of(context).draftStarting;
    } else {
      label = _actionButtonLabel();
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isDisabled ? null : _runAnalysis,
        icon: (isDisabled)
            ? const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.analytics_rounded),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.5),
          disabledForegroundColor: Colors.white70,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildOfflineNotice(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.wifi_off_rounded,
              color: Colors.orange.shade700, size: 22),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.of(context).draftNoInternet,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppStrings.of(context).draftNoInternetDetail,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange.shade800,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataPersistenceNotice(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E3A5F).withValues(alpha: 0.4)
            : const Color(0xFFE8F4FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2563EB).withValues(alpha: 0.3)
              : const Color(0xFF93C5FD),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_done_outlined,
              size: 18,
              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              AppStrings.of(context).draftDataPersistenceNotice,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: isDark
                    ? const Color(0xFF93C5FD)
                    : const Color(0xFF1D4ED8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ── Helper data class for info rows ─────────────────────────────────────────
class _InfoRow {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  Widget build(BuildContext context, bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon,
            size: 18,
            color: isDark ? Colors.grey[500] : Colors.grey.shade400),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: isDark ? Colors.grey[500] : Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : AppTheme.textMain,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
