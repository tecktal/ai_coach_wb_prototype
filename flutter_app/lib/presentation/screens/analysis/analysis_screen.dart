import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../data/models/analysis.dart';
import '../../../data/models/recording.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/teach/teach_elements.dart';
import '../../../data/providers/analysis_provider.dart';
import '../../../data/providers/recording_provider.dart';
import '../../../data/providers/auth_provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import '../chat/chat_screen.dart';
import '../coach/focal_skill_screen.dart';
import '../../widgets/offline_banner.dart';
import '../../../../core/l10n/app_strings.dart';

// Widgets
import 'widgets/hero_score.dart';
import 'widgets/key_takeaways_widget.dart';
import 'widgets/teach_grid_widget.dart';
import 'widgets/sticky_action_card.dart';

class AnalysisScreen extends StatefulWidget {
  final String analysisId;

  const AnalysisScreen({super.key, required this.analysisId});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  Analysis? _analysis;
  Recording? _recording;

  bool _isPlaying = false;
  Duration _playbackDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;

  // TTS State
  bool _isSpeaking = false;
  String? _currentlySpeakingSection;

  /// True if a content_warning was present the moment the screen first loaded.
  /// Prevents the banner from appearing on a pull-to-refresh after the teacher
  /// has already reviewed the analysis (the delayed-banner bug).
  bool? _hasContentWarningAtLoad; // null = not yet checked

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
    _initAudioPlayer();
  }

  void _initAudioPlayer() {
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

  Future<void> _loadAnalysis() async {
    final provider = context.read<AnalysisProvider>();
    await provider.loadAnalysis(widget.analysisId);
    
    final analysis = provider.currentAnalysis;
    Recording? recording;
    
    if (analysis != null) {
       if (!mounted) return;
       final recProvider = context.read<RecordingProvider>();
       recording = recProvider.getRecordingById(analysis.recordingId);
    }

    if (mounted) {
      setState(() {
        _analysis = analysis;
        _recording = recording;
        if (recording != null && recording.durationSeconds != null && recording.durationSeconds! > 0) {
          _playbackDuration = Duration(seconds: recording.durationSeconds!);
        }
        // Lock the banner to whatever was present on first load only
        if (_hasContentWarningAtLoad == null && analysis != null) {
          final cw = analysis.timeOnLearning['content_warning'];
          _hasContentWarningAtLoad = (cw != null && cw is Map);
        }
      });
    }
  }

  /// Compiles the full analysis as plain text and copies it to the clipboard.
  void _copyAllFeedback() {
    if (_analysis == null) return;
    final buf = StringBuffer();
    buf.writeln(AppStrings.of(context).lessonAnalysis.toUpperCase());
    buf.writeln('Lesson: ${_recording?.title ?? _analysis!.id}');
    buf.writeln('Date:   ${DateFormat("MMMM d, yyyy").format(_analysis!.createdAt)}');
    buf.writeln();

    if (_analysis!.strengths.isNotEmpty) {
      buf.writeln(AppStrings.of(context).strengths.toUpperCase());
      for (final s in _analysis!.strengths) {
        buf.writeln('\u2022 $s');
      }
      buf.writeln();
    }

    if (_analysis!.areasForImprovement.isNotEmpty) {
      buf.writeln(AppStrings.of(context).areasForImprovement.toUpperCase());
      for (final a in _analysis!.areasForImprovement) {
        buf.writeln('\u2022 $a');
      }
      buf.writeln();
    }

    if (_analysis!.recommendations.isNotEmpty) {
      buf.writeln(AppStrings.of(context).recommendations.toUpperCase());
      for (int i = 0; i < _analysis!.recommendations.length; i++) {
        final r = _analysis!.recommendations[i];
        buf.writeln('${i + 1}. ${r.title}');
        if (r.description.isNotEmpty) buf.writeln('   ${r.description}');
        buf.writeln();
      }
    }

    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppStrings.of(context).analysisCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _speak(String? text, String sectionId) async {
    if (text == null || text.isEmpty) return;

    if (_isSpeaking && _currentlySpeakingSection == sectionId) {
      await _tts.stop();
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _currentlySpeakingSection = null;
        });
      }
      return;
    }

    if (_isSpeaking) {
      await _tts.stop();
    }

    if (mounted) {
      setState(() {
        _isSpeaking = true;
        _currentlySpeakingSection = sectionId;
      });
    }

    final cleanText = text
        .replaceAll('*', '')
        .replaceAll('#', '')
        .replaceAll('**', '')
        .replaceAll('_', '');

    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _currentlySpeakingSection = null;
        });
      }
    });

    await _tts.speak(cleanText);
  }

  @override
  void dispose() {
    _tts.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _navigateToElementDetail(
    String canonicalKey,
    String label,
    ElementAnalysis? element,
    TeachDomain domain,
  ) {
    if (element == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ElementDetailScreen(
          canonicalKey: canonicalKey,
          elementName: label,
          element: element,
          domain: domain,
          analysisId: widget.analysisId,
        ),
      ),
    );
  }

  /// Returns a visible banner when the analysis succeeded but the audio had
  /// limited content. Returns [SizedBox.shrink] when there is no warning.
  Widget _buildContentWarningBanner() {
    if (_analysis == null) return const SizedBox.shrink();

    final cw = _analysis!.timeOnLearning['content_warning'];
    if (cw == null || cw is! Map) return const SizedBox.shrink();

    final type    = cw['type']    as String? ?? '';
    final message = cw['message'] as String? ?? '';
    if (message.isEmpty) return const SizedBox.shrink();

    // Visual style per warning type
    Color bannerColor;
    IconData bannerIcon;
    String bannerTitle;
    switch (type) {
      case 'too_short':
        bannerColor = const Color(0xFFFF6D00); // deep orange
        bannerIcon  = Icons.timer_off_rounded;
        bannerTitle = AppStrings.of(context).shortRecording;
        break;
      case 'limited_teaching':
        bannerColor = const Color(0xFFF9A825); // amber
        bannerIcon  = Icons.school_outlined;
        bannerTitle = AppStrings.of(context).limitedTeachingActivity;
        break;
      case 'poor_audio':
        bannerColor = const Color(0xFFD32F2F); // red
        bannerIcon  = Icons.mic_off_rounded;
        bannerTitle = AppStrings.of(context).lowAudioQuality;
        break;
      default:
        bannerColor = const Color(0xFF1565C0); // blue
        bannerIcon  = Icons.info_outline_rounded;
        bannerTitle = AppStrings.of(context).analysisNote;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: double.infinity,
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.12),
        border: Border(bottom: BorderSide(color: bannerColor.withOpacity(0.4), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(bannerIcon, color: bannerColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bannerTitle,
                  style: TextStyle(
                    color: bannerColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    color: bannerColor.withOpacity(0.9),
                    fontSize: 12,
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

  @override
  Widget build(BuildContext context) {
    if (_analysis == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(title: Text(AppStrings.of(context).analysis), backgroundColor: Colors.transparent),
        body: Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor)),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          AppStrings.of(context).lessonAnalysis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textMain
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: AppStrings.of(context).back,
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: isDark ? Colors.white : AppTheme.textMain),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.copy_all_rounded, size: 20,
                color: isDark ? Colors.white70 : AppTheme.textSub),
            tooltip: AppStrings.of(context).copyAllFeedback,
            onPressed: _copyAllFeedback,
          ),
        ],
      ),
      body: Column(
        children: [
          // Offline indicator — slides in when no internet (always sticky)
          const OfflineBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAnalysis,
              color: Theme.of(context).primaryColor,
              child: SelectionArea(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Content warning banner — only if it was present on first load
                    if (_hasContentWarningAtLoad == true) _buildContentWarningBanner(),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                    // 1. Hero Score
                    HeroScore(
                      score: _analysis!.overallScore ?? 0.0,
                      date: DateFormat('MMMM d, yyyy').format(_analysis!.createdAt),
                      title: _recording?.title ?? AppStrings.of(context).untitledLesson,
                    ),
              const SizedBox(height: 32),
              
              // Audio Player
              _buildAudioPlayerCard(isDark),
              const SizedBox(height: 32),

              // 2. Key Takeaways
              _buildSectionTitle(AppStrings.of(context).keyTakeaways, isDark),
              const SizedBox(height: 16),
              KeyTakeawaysWidget(
                strengths: _analysis!.strengths,
                growthAreas: _analysis!.areasForImprovement,
                onSpeak: _speak,
                isSpeaking: _isSpeaking,
                currentSection: _currentlySpeakingSection,
              ),
              const SizedBox(height: 32),

              // 2.5 Transcript Placeholder
              _buildSectionTitle(AppStrings.of(context).transcript, isDark),
              const SizedBox(height: 16),
              _buildTranscriptPlaceholder(isDark),
              const SizedBox(height: 32),

              // 3. TEACH Framework
              _buildSectionTitle(AppStrings.of(context).teachFramework, isDark),
              const SizedBox(height: 16),
              TeachGridWidget(
                analysis: _analysis!,
                onElementTap: _navigateToElementDetail,
              ),
              const SizedBox(height: 32),

              // Coordinator-only: prepare a coaching conversation. Teachers
              // reading their own feedback have no one to coach, so this is
              // hidden for them entirely.
              if (context.watch<AuthProvider>().user?.isCoordinatorAudience ??
                  false) ...[
                _buildCoachEntryCard(isDark),
                const SizedBox(height: 32),
              ],

              // 4. Coaching section — cognitive-science areas by default, or the
              //    deployment's priority skills where those are configured.
              if (_analysis!.scienceOfLearning?.isNotEmpty ?? false) ...[
                _buildSectionTitle(_coachSectionTitle(), isDark),
                const SizedBox(height: 16),
                _buildScienceOfLearning(isDark),
                const SizedBox(height: 32),
              ],
              
              // 5. Recommendations (up to 3)
              if (_analysis!.recommendations.isNotEmpty) ...[
                ..._analysis!.recommendations.take(3).toList().asMap().entries.map((entry) {
                  final i = entry.key;
                  final rec = entry.value;
                  return Padding(
                    padding: EdgeInsets.only(bottom: i < _analysis!.recommendations.take(3).length - 1 ? 12 : 0),
                    child: StickyActionCard(
                      index: i + 1,
                      title: rec.title,
                      description: rec.description,
                      example: rec.example,
                    ),
                  );
                }),
                const SizedBox(height: 32),
              ],

              
              const SizedBox(height: 80), 
                  ],            // closes inner Padding Column children
                ),              // closes inner Padding Column
              ),                // closes Padding
            ],                  // closes outer scroll Column children
          ),                    // closes outer scroll Column
        ),                      // closes SingleChildScrollView
      ),                        // closes SelectionArea
    ),                          // closes RefreshIndicator
  ),                            // closes Expanded
  ],                            // closes body Column children
),                              // closes body Column
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_analysis != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(analysisId: _analysis!.id),
              ),
            );
          }
        },
        icon: const Icon(Icons.support_agent_rounded),
        label: Text(AppStrings.of(context).talkToCoach),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  /// Entry point into the coordinator coaching flow. Shown only when the
  /// signed-in user's feedback audience is `coordinator`.
  Widget _buildCoachEntryCard(bool isDark) {
    final strings = AppStrings.of(context);
    final primary = Theme.of(context).primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primary.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.record_voice_over_rounded, color: primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  strings.coachConversation,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textMain,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            strings.coachConversationSubtitle,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: isDark ? Colors.grey[400] : AppTheme.textSub,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(strings.coachPrepareButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FocalSkillScreen(
                      recordingId: _analysis!.recordingId,
                      analysis: _analysis!,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: isDark ? Colors.grey[400] : AppTheme.textSub,
        ),
      ),
    );
  }

  Widget _buildTranscriptPlaceholder(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.blue.shade900 : Colors.blue.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade500, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.of(context).comingSoon,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDark ? Colors.blue.shade200 : Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.of(context).transcriptComingSoon,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.blue.shade100 : Colors.blue.shade800,
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
  
  Widget _buildAudioPlayerCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade100),
        boxShadow: isDark ? [] : [
           BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ]
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
              icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
              color: Theme.of(context).primaryColor,
              iconSize: 32,
              onPressed: () async {
                if (_isPlaying) {
                  await _audioPlayer.pause();
                  setState(() => _isPlaying = false);
                } else {
                  if (_recording != null) {
                    final authProvider = context.read<AuthProvider>();
                    await _audioPlayer.pause();
                    
                    Source audioSource;
                    if (_recording!.fileUrl.startsWith('http')) {
                      final token = await authProvider.getToken();
                      String finalUrl = _recording!.fileUrl;
                      if (token != null) {
                         final separator = finalUrl.contains('?') ? '&' : '?';
                         finalUrl = '$finalUrl${separator}token=$token';
                      }
                      audioSource = UrlSource(finalUrl);
                    } else {
                      audioSource = DeviceFileSource(_recording!.fileUrl);
                    }
                    await _audioPlayer.play(audioSource);
                    setState(() => _isPlaying = true);
                  }
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.of(context).lessonAudio,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textMain
                  ),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    trackHeight: 4,
                    activeTrackColor: Theme.of(context).primaryColor,
                    inactiveTrackColor: isDark ? Colors.grey[700] : Colors.grey.shade200,
                    thumbColor: Theme.of(context).primaryColor,
                    overlayShape: SliderComponentShape.noOverlay,
                  ),
                  child: Slider(
                    value: _playbackPosition.inMilliseconds.toDouble(),
                    max: (_playbackDuration.inMilliseconds > 0 
                        ? _playbackDuration.inMilliseconds 
                        : (_recording?.durationSeconds ?? 0) * 1000).toDouble() > 0 
                        ? (_playbackDuration.inMilliseconds > 0 
                            ? _playbackDuration.inMilliseconds.toDouble() 
                            : (_recording?.durationSeconds ?? 1) * 1000.0) 
                        : 1.0,
                    onChanged: (v) => _audioPlayer.seek(Duration(milliseconds: v.toInt())),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_playbackPosition), style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey)),
                      if (_playbackDuration.inMilliseconds > 0 || (_recording?.durationSeconds ?? 0) > 0)
                        Text(
                          _playbackDuration.inMilliseconds > 0 
                            ? _formatDuration(_playbackDuration)
                            : _formatDuration(Duration(seconds: _recording!.durationSeconds!)),
                          style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey)
                        )
                      else
                        Text('--:--', style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey)),
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

  /// Renders whatever coaching areas the analysis actually carries.
  ///
  /// Iterating rather than reading three fixed fields is what lets an older
  /// analysis (three cognitive-science areas) and a Brazilian one (two priority
  /// skills) both render correctly with no migration.
  Widget _buildScienceOfLearning(bool isDark) {
    final areas = _analysis!.scienceOfLearning!.areas;
    final entries = areas.entries.toList();

    return Column(
      children: [
        for (int i = 0; i < entries.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _buildScienceCard(
            _coachAreaLabel(entries[i].key),
            entries[i].value,
            isDark,
          ),
        ],
      ],
    );
  }

  /// Heading for the coaching section.
  ///
  /// "Science of Learning" describes the three cognitive-science areas. Where a
  /// deployment has configured its own priority skills the section is about
  /// teaching practices, not cognitive science, so the heading changes with it.
  String _coachSectionTitle() {
    final keys = _analysis!.scienceOfLearning?.areas.keys.toSet() ?? {};
    const defaultKeys = {
      'clarity_and_cognitive_load',
      'student_engagement_and_retrieval_practice',
      'feedback_and_metacognition',
    };
    final isDefault = keys.isEmpty || keys.intersection(defaultKeys).isNotEmpty;
    return isDefault
        ? AppStrings.of(context).scienceOfLearning
        : AppStrings.of(context).prioritySkills;
  }

  /// Localized name for a coaching area, by convention `coachArea_<key>`.
  ///
  /// Falls back to a de-slugified key so a deployment can add an area before
  /// anyone has translated it, rather than rendering a raw snake_case string.
  String _coachAreaLabel(String key) {
    final localized = AppStrings.of(context).byKey('coachArea_$key');
    if (localized != 'coachArea_$key') return localized;

    return key
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Widget _buildScienceCard(String title, dynamic area, bool isDark) {
    if (area == null) return const SizedBox.shrink();
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade100),
        boxShadow: isDark ? [] : [
           BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))
        ]
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedIconColor: isDark ? Colors.grey[400] : Colors.grey[600],
          iconColor: isDark ? Colors.white : AppTheme.textMain,
          title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : AppTheme.textMain)),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.psychology, color: Colors.blue.shade500, size: 20),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: _isSpeaking && _currentlySpeakingSection == 'science_$title' ? 'Stop speaking' : 'Speak feedback',
                icon: Icon(
                  _isSpeaking && _currentlySpeakingSection == 'science_$title'
                      ? Icons.stop_circle_outlined
                      : Icons.volume_up_outlined,
                  color: _isSpeaking && _currentlySpeakingSection == 'science_$title'
                      ? Theme.of(context).primaryColor
                      : (isDark ? Colors.grey[400] : Colors.grey.shade600),
                  size: 20,
                ),
                onPressed: () {
                  final combinedText = '${area.pros}. ${area.cons}. ${area.feedback}';
                  _speak(combinedText, 'science_$title');
                },
              ),
              Icon(
                Icons.expand_more,
                color: isDark ? Colors.grey[400] : Colors.grey.shade600,
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Divider(height: 1, color: isDark ? Colors.grey[700] : Colors.grey[200]),
            const SizedBox(height: 16),
            _buildScienceRow(AppStrings.of(context).pros, area.pros, Colors.green, isDark),
            const SizedBox(height: 16),
            _buildScienceRow(AppStrings.of(context).cons, area.cons, Colors.orange, isDark),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tips_and_updates, size: 16, color: Colors.blue.shade500),
                      const SizedBox(width: 8),
                      Text(AppStrings.of(context).coachFeedback, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade500, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  MarkdownBody(
                    data: area.feedback,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(color: isDark ? Colors.grey[300] : AppTheme.textMain),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScienceRow(String label, String content, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(radius: 3, backgroundColor: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        MarkdownBody(
          data: content,
          styleSheet: MarkdownStyleSheet(
            p: TextStyle(color: isDark ? Colors.grey[300] : AppTheme.textMain),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

// DETAILED SCREEN FOR EVIDENCE
class ElementDetailScreen extends StatefulWidget {
  /// Stable element identity (e.g. 'supportive_environment'). Used for tip and
  /// label lookups — never derive a key from [elementName], which is translated.
  final String canonicalKey;

  /// Already-translated display name.
  final String elementName;

  final ElementAnalysis element;

  /// Drives the TEACH manual colour coding, carried through from the grid so
  /// the association doesn't break on the detail screen.
  final TeachDomain domain;

  final String analysisId;

  const ElementDetailScreen({
    super.key,
    required this.canonicalKey,
    required this.elementName,
    required this.element,
    required this.domain,
    required this.analysisId,
  });

  @override
  State<ElementDetailScreen> createState() => _ElementDetailScreenState();
}

class _ElementDetailScreenState extends State<ElementDetailScreen> {
  final FlutterTts _tts = FlutterTts();
  String _selectedBehavior = 'All';
  
  bool _isSpeaking = false;
  String? _currentlySpeakingSection;

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak(String? text, String sectionId) async {
    if (text == null || text.isEmpty) return;

    if (_isSpeaking && _currentlySpeakingSection == sectionId) {
      await _tts.stop();
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _currentlySpeakingSection = null;
        });
      }
      return;
    }

    if (_isSpeaking) {
      await _tts.stop();
    }

    if (mounted) {
      setState(() {
        _isSpeaking = true;
        _currentlySpeakingSection = sectionId;
      });
    }

    final cleanText = text
        .replaceAll('*', '')
        .replaceAll('#', '')
        .replaceAll('**', '')
        .replaceAll('_', '')
        .replaceAll('`', '');

    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
          _currentlySpeakingSection = null;
        });
      }
    });

    await _tts.speak(cleanText);
  }

  /// LEGACY COMPATIBILITY SHIM — see the fuller note on the same heuristic in
  /// widgets/teach_grid_widget.dart.
  ///
  /// Maps pre-Phase-0 analyses (which stored N/A as a score of 1) back to N/A.
  /// Analyses created after the fix store N/A as null and do not need this.
  /// Safe to delete once pre-fix analyses are gone or backfilled.
  int _getEffectiveScore(ElementAnalysis element) {
    if (element.score == 1) {
      if (element.behaviors.isEmpty) {
         return 0;
      }
      bool hasActualRating = false;
      for (var b in element.behaviors.values) {
        if (b.rating.toUpperCase() != 'N/A' && b.rating != '0') {
          hasActualRating = true;
          break;
        }
      }
      if (!hasActualRating) return 0;
    }
    return element.score;
  }

  @override
  Widget build(BuildContext context) {
    final sortedKeys = widget.element.behaviors.keys.toList()..sort();
    final effectiveScore = _getEffectiveScore(widget.element);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final displayedKeys = _selectedBehavior == 'All' 
        ? sortedKeys 
        : sortedKeys.where((k) => k == _selectedBehavior).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(widget.elementName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : AppTheme.textMain)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : AppTheme.textMain),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Score Hero
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: BoxShape.circle,
                boxShadow: isDark ? [] : [
                  BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))
                ],
                border: isDark ? Border.all(color: Colors.grey[700]!) : null,
              ),
              child: Column(
                children: [
                  effectiveScore > 0
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              effectiveScore >= 3
                                  ? Icons.check_circle_outline
                                  : Icons.trending_up,
                              color: AppTheme.getScoreColor(effectiveScore),
                              size: 32,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              effectiveScore >= 4
                                  ? AppStrings.of(context).scoreStrong
                                  : effectiveScore >= 3
                                      ? AppStrings.of(context).scoreGood
                                      : effectiveScore >= 2
                                          ? AppStrings.of(context).scoreDeveloping
                                          : AppStrings.of(context).scoreNeedsFocus,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.getScoreColor(effectiveScore),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : const Text(
                          'N/A',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Rationale
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Theme.of(context).primaryColor),
                          const SizedBox(width: 12),
                          Text(AppStrings.of(context).rationale, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.textMain)),
                        ],
                      ),
                      IconButton(
                        icon: Icon(
                          _isSpeaking && _currentlySpeakingSection == 'rationale'
                              ? Icons.stop_circle_outlined
                              : Icons.volume_up_outlined,
                          color: _isSpeaking && _currentlySpeakingSection == 'rationale'
                              ? Theme.of(context).primaryColor
                              : (isDark ? Colors.grey[400] : Colors.grey.shade600),
                        ),
                        onPressed: () => _speak(widget.element.rationale, 'rationale'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  MarkdownBody(
                    data: widget.element.rationale,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(color: isDark ? Colors.grey[300] : AppTheme.textMain),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // Behavior Chips (only show if there are behaviors to filter)
            if (sortedKeys.isNotEmpty) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildChip('All', isDark),
                    ...sortedKeys.map((key) => _buildChip(key, isDark)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ── Element-level N/A card (no behaviors at all) ───────────────
            if (displayedKeys.isEmpty) ...[
              _NotObservedCard(
                // Canonical key, NOT derived from the display name — the name is
                // translated, and deriving a key from it silently broke every
                // tip lookup in non-English builds.
                behaviorKey: widget.canonicalKey,
                behaviorLabel: widget.elementName,
                analysisId: widget.analysisId,
                rationale: widget.element.rationale,
              ),
            ],

            // ── Behavior cards ──────────────────────────────────────────────
            ...displayedKeys.map((key) {
              final behavior = widget.element.behaviors[key]!;
              final sectionId = 'behavior_$key';

              return Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey.shade100),
                  boxShadow: isDark ? [] : [
                     BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
                  ]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getRatingColor(behavior.rating).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            // Localized letter (B/M/A in Portuguese). Colour
                            // still keys off the stored H/M/L value.
                            AppStrings.of(context).ratingLabel(behavior.rating),
                            style: TextStyle(
                              color: _getRatingColor(behavior.rating),
                              fontWeight: FontWeight.bold
                            )
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _behaviorTitle(context, key),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : AppTheme.textMain),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _isSpeaking && _currentlySpeakingSection == sectionId
                                ? Icons.stop_circle_outlined
                                : Icons.volume_up_outlined,
                            color: _isSpeaking && _currentlySpeakingSection == sectionId
                                ? Theme.of(context).primaryColor
                                : (isDark ? Colors.grey[400] : Colors.grey.shade600),
                            size: 20,
                          ),
                          onPressed: () {
                            String textToRead =
                                "${AppStrings.of(context).rating}: ${AppStrings.of(context).ratingLabel(behavior.rating)}. ";
                            if (behavior.instancesFound.isNotEmpty) {
                              textToRead += "${AppStrings.of(context).evidenceFound}: ${behavior.instancesFound.join('. ')}";
                            } else {
                              textToRead += behavior.evidence;
                            }
                            _speak(textToRead, sectionId);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(height: 1, color: isDark ? Colors.grey[700] : Colors.grey[200]),
                    const SizedBox(height: 16),

                    // Evidence / Not-Observed section
                    Builder(builder: (_) {
                      final isNotObserved =
                          behavior.rating.toUpperCase() == 'N/A' ||
                          behavior.rating.toUpperCase() == 'NOT OBSERVED' ||
                          behavior.rating == '0';

                      if (isNotObserved) {
                        return _NotObservedCard(
                          behaviorKey: key,
                          behaviorLabel: _behaviorChipLabel(context, key),
                          analysisId: widget.analysisId,
                          rationale: behavior.evidence,
                        );
                      }

                      // Normal evidence timeline
                      if (behavior.instancesFound.isNotEmpty) {
                        return Column(
                          children: [
                            ...behavior.instancesFound.asMap().entries.map((entry) {
                              final isLast = entry.key == behavior.instancesFound.length - 1;
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Theme.of(context).primaryColor, width: 2),
                                        ),
                                      ),
                                      if (!isLast)
                                        Container(
                                          width: 2,
                                          height: 40,
                                          color: isDark ? Colors.grey[700] : Colors.grey.shade200,
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 16.0),
                                      child: Text(
                                        '"${entry.value}"',
                                        style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: isDark ? Colors.grey[300] : AppTheme.textMain,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ],
                        );
                      }

                      // Fallback: plain evidence quote
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.format_quote_rounded, color: Colors.grey, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              behavior.evidence,
                              style: const TextStyle(
                                fontStyle: FontStyle.italic, color: Colors.grey),
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, bool isDark) {
    final isSelected = _selectedBehavior == label;
    final displayLabel = label == 'All'
        ? AppStrings.of(context).all
        : _behaviorChipLabel(context, label);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(displayLabel),
        selected: isSelected,
        onSelected: (selected) {
           if (selected) setState(() => _selectedBehavior = label);
        },
        selectedColor: Theme.of(context).primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : (isDark ? Colors.grey[400] : AppTheme.textSub),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.transparent : (isDark ? Colors.grey[700]! : Colors.grey.shade200))),
      ),
    );
  }

  /// Short behavior label for the filter chips — number plus name, no caps.
  String _behaviorChipLabel(BuildContext context, String behaviorKey) {
    final behavior = teachBehaviorByKey(behaviorKey);
    if (behavior == null) return behaviorKey.replaceAll('_', ' ');
    return '${behavior.number} ${AppStrings.of(context).byKey(behavior.labelKey)}';
  }

  /// Display title for a behavior, e.g. "1.3 · RESPONDS TO STUDENT NEEDS".
  ///
  /// The TEACH form number is included because coordinators work from the paper
  /// form and refer to behaviors by number.
  ///
  /// Falls back to the raw key when the AI emits a behavior we have no label
  /// for — an unrecognised key must degrade, never fail.
  String _behaviorTitle(BuildContext context, String behaviorKey) {
    final behavior = teachBehaviorByKey(behaviorKey);
    if (behavior == null) {
      return behaviorKey.replaceAll('_', ' ').toUpperCase();
    }
    final label = AppStrings.of(context).byKey(behavior.labelKey);
    return '${behavior.number} · ${label.toUpperCase()}';
  }

  /// Colour for a rating. Keys off the STORED value ("H"/"M"/"L"), not the
  /// localized display letter, so translations never change the colour.
  Color _getRatingColor(String rating) {
    final r = rating.toUpperCase();
    if (r.contains('H')) return AppTheme.successColor;
    if (r.contains('M')) return AppTheme.warningColor;
    if (r.contains('L')) return AppTheme.errorColor;
    return Colors.grey;
  }
}

// Coaching tips now live in the translation maps, keyed 'teachTip_<canonicalKey>',
// and are read via AppStrings.teachTip(). The previous hardcoded English map was
// keyed on a mix of invented behavior names, element display labels and domain
// names — it matched none of the 28 behavior keys the AI actually emits and only
// 5 of the 9 element labels, so it mostly fell through to the generic tip.


// ── _NotObservedCard widget ───────────────────────────────────────────────────

class _NotObservedCard extends StatelessWidget {
  /// Canonical element key or raw behavior key — used for the tip lookup.
  /// Never derived from a display label, which is translated.
  final String behaviorKey;

  /// Already-translated name, shown to the teacher.
  final String behaviorLabel;

  final String analysisId;
  final String rationale;

  const _NotObservedCard({
    required this.behaviorKey,
    required this.behaviorLabel,
    required this.analysisId,
    required this.rationale,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool rationaleOk = rationale.isNotEmpty &&
        !rationale.toLowerCase().contains('not provided') &&
        !rationale.toLowerCase().contains('n/a') &&
        !rationale.toLowerCase().contains('no analysis') &&
        rationale.length > 25;
    final tip = AppStrings.of(context).teachTip(behaviorKey) ??
        (rationaleOk
            ? rationale
            : AppStrings.of(context).askCoachTip);
    final coachQuestion =
        'Can you give me concrete examples of how to implement "$behaviorLabel" in my classroom? What does it look like in practice?';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.visibility_off_outlined, size: 16, color: Colors.grey),
            const SizedBox(width: 6),
            Text(
              AppStrings.of(context).notObserved,
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A2744) : const Color(0xFFEFF4FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF2D4070) : const Color(0xFFBFD0F7),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('\u{1F4A1}', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.of(context).tryThis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? const Color(0xFF93B4F8) : const Color(0xFF3B63CC),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                tip,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: isDark ? Colors.grey[300] : const Color(0xFF2C3E6B),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    analysisId: analysisId,
                    initialMessage: coachQuestion,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
            label: Text(AppStrings.of(context).askTheCoach),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).primaryColor,
              side: BorderSide(color: Theme.of(context).primaryColor.withValues(alpha: 0.4)),
              padding: const EdgeInsets.symmetric(vertical: 10),
              textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }
}
