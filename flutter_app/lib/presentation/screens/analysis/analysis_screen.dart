import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../data/models/analysis.dart';
import '../../../data/models/recording.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/providers/analysis_provider.dart';
import '../../../data/providers/recording_provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'analysis_radar_chart.dart';

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
       final recProvider = context.read<RecordingProvider>();
       recording = recProvider.getRecordingById(analysis.recordingId);
    }

    setState(() {
      _analysis = analysis;
      _recording = recording;
    });
  }

  Future<void> _speak(String? text) async {
    if (text != null && text.isNotEmpty) {
      // Clean markdown symbols for speech if needed, or let TTS handle it.
      // TTS usually reads * as "asterisk", so simple cleaning is good.
      final cleanText = text.replaceAll('*', '').replaceAll('#', '');
      await _tts.speak(cleanText);
    }
  }

  @override
  void dispose() {
    _tts.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _navigateToElementDetail(String name, ElementAnalysis? element) {
    if (element == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ElementDetailScreen(
          elementName: name,
          element: element,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_analysis == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Analysis')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () => _speak(_analysis?.summary),
            tooltip: 'Read Summary',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAudioAndTranscriptSection(),
            
            // Overall Score
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: CircularPercentIndicator(
                  radius: 80,
                  lineWidth: 16,
                  percent: (_analysis!.overallScore ?? 0) / 5,
                  center: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _analysis!.overallScore?.toStringAsFixed(1) ?? '0.0',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const Text('/ 5.0'),
                    ],
                  ),
                  progressColor: AppTheme.getScoreColorDouble(
                    _analysis!.overallScore ?? 0,
                  ),
                  backgroundColor: Colors.grey.shade300,
                ),
              ),
            ),

            // Confidence Factors
            // Confidence Factors MOVED TO BOTTOM


            const SizedBox(height: 24),
            
            // Time On Learning Section (New)
            if (_analysis!.timeOnLearning.isNotEmpty)
               _buildTimeOnLearningSection(_analysis!.timeOnLearning),

            const SizedBox(height: 24),
            
            // Radar Chart (New)
            if (_analysis != null)
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 16.0),
                 child: Column(
                   children: [
                     Text(
                        'Teach Primary Scores', 
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)
                     ),
                     const SizedBox(height: 32), // Increased spacing to prevent overlap
                     AnalysisRadarChart(analysis: _analysis!),
                     const SizedBox(height: 8),
                   ],
                 ),
               ),

             const SizedBox(height: 24),

            // Element Scores Grid
            Text(
              'TEACH Elements (Tap for Evidence)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                _buildElementCard('Supportive Env.', _analysis!.supportiveEnvironmentScore ?? 0, _analysis!.supportiveEnvironment),
                _buildElementCard('Positive Expect.', _analysis!.positiveExpectationsScore ?? 0, _analysis!.positiveExpectations),
                _buildElementCard('Facilitation', _analysis!.lessonFacilitationScore ?? 0, _analysis!.lessonFacilitation),
                _buildElementCard('Checks Underst.', _analysis!.checksUnderstandingScore ?? 0, _analysis!.checksUnderstanding),
                _buildElementCard('Feedback', _analysis!.feedbackScore ?? 0, _analysis!.feedback),
                _buildElementCard('Critical Think.', _analysis!.criticalThinkingScore ?? 0, _analysis!.criticalThinking),
                _buildElementCard('Autonomy', _analysis!.autonomyScore ?? 0, _analysis!.autonomy),
                _buildElementCard('Perseverance', _analysis!.perseveranceScore ?? 0, _analysis!.perseverance),
                _buildElementCard('Social/Collab', _analysis!.socialCollaborativeScore ?? 0, _analysis!.socialCollaborative),
              ],
            ),
            const SizedBox(height: 24),

            // Qualitative Sections
            _buildQualitativeSection('Summary', _analysis!.summary),
            _buildListSection('Strengths', _analysis!.strengths, Icons.check_circle, AppTheme.successColor),
            _buildListSection('Areas for Improvement', _analysis!.areasForImprovement, Icons.lightbulb, AppTheme.warningColor),
            
            if (_analysis!.recommendations.isNotEmpty) ...[
              Text('Recommendations', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              ..._analysis!.recommendations.map((rec) => Card(
                child: ExpansionTile(
                  title: Row(
                    children: [
                       Expanded(child: MarkdownBody(data: rec.title)),
                       // Speak recommendation
                       IconButton(
                         icon: const Icon(Icons.volume_up, size: 20),
                         onPressed: () => _speak("${rec.title}. ${rec.description}. Example: ${rec.example}"),
                       ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MarkdownBody(data: rec.description),
                          const SizedBox(height: 8),
                          MarkdownBody(
                             data: "_Example:_ ${rec.example}", 
                             styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                               p: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)
                             )
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
            ],

            
            const SizedBox(height: 24),

            // Confidence Factors (Moved to Bottom)
            if (_analysis!.confidenceFactors != null)
              _buildConfidenceSection(_analysis!.confidenceFactors!),
              
            const SizedBox(height: 48), // Bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildAudioAndTranscriptSection() {
    if (_recording == null) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.audiotrack),
            title: const Text('Lesson Recording'),
            subtitle: Text(_formatDuration(_playbackDuration)),
            trailing: IconButton(
               icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
               onPressed: () async {
                 if (_isPlaying) {
                   await _audioPlayer.pause();
                   setState(() => _isPlaying = false);
                 } else {
                   if (_recording!.fileUrl.startsWith('http')) {
                     await _audioPlayer.play(UrlSource(_recording!.fileUrl));
                   } else {
                     await _audioPlayer.play(DeviceFileSource(_recording!.fileUrl));
                   }
                   setState(() => _isPlaying = true);
                 }
               },
            ),
          ),
          if (_analysis?.transcription != null)
            ExpansionTile(
              title: const Text('View Transcript'),
              children: [
                Container(
                  height: 200,
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Text(_analysis!.transcription!.fullText),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildConfidenceSection(ConfidenceFactors factors) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.black87),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('AI Confidence & Context', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              Text.rich(TextSpan(children: [
                const TextSpan(text: 'Audio Quality: ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: factors.audioQuality),
              ])),
              Text.rich(TextSpan(children: [
                const TextSpan(text: 'Evidence Completeness: ', style: TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: factors.evidenceCompleteness),
              ])),
              if (factors.limitations.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Limitations:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...factors.limitations.map((l) => Text('• $l', style: const TextStyle(fontSize: 13))),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTimeOnLearningSection(Map<String, dynamic> tol) {
    // Expected keys: snapshot_4min, snapshot_9min, snapshot_14min
    // Note: 'confidence_factors' might also be in the map if merged, we skip it
    
    final snapshots = tol.entries.where((e) => e.key.startsWith('snapshot')).toList();
    if (snapshots.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Time on Learning Snapshots', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: snapshots.length,
            itemBuilder: (context, index) {
              final kv = snapshots[index];
              final data = kv.value as Map<String, dynamic>;
              final timeLabel = kv.key.replaceAll('snapshot_', '').replaceAll('min', ' Min');
              
              // Parse status
              final bool teacherActive = data['teacher_activity'] ?? false;
              final String studentsOnTask = data['students_on_task'] ?? '?';
              
              Color cardColor = Colors.grey.shade100;
              if (studentsOnTask == 'H') cardColor = Colors.green.shade50;
              if (studentsOnTask == 'L') cardColor = Colors.red.shade50;

              return Container(
                width: 160,
                margin: const EdgeInsets.only(right: 8),
                child: Card(
                  color: cardColor,
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('$timeLabel Snapshot'),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Teacher Active: ${teacherActive ? "YES" : "NO"}'),
                                Text('Students On Task: $studentsOnTask', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const Divider(),
                                const Text('Evidence:', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                Text("${data['evidence'] ?? ''}"),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: DefaultTextStyle(
                        style: const TextStyle(color: Colors.black87),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(timeLabel, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                            const Divider(color: Colors.black26),
                            Text('Teacher Active: ${teacherActive ? "YES" : "NO"}', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                            Text('Students On Task: $studentsOnTask', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87)),
                            const SizedBox(height: 4),
                            Expanded(
                              child: Text(
                                 "${data['evidence'] ?? ''}",
                                 style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.black87),
                                 overflow: TextOverflow.ellipsis,
                                 maxLines: 3,
                              )
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildElementCard(String name, int score, ElementAnalysis? element) {
    return Card(
      color: AppTheme.getScoreColor(score).withOpacity(0.1),
      child: InkWell(
        onTap: () => _navigateToElementDetail(name, element),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                score.toString(),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.getScoreColor(score),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQualitativeSection(String title, String? content) {
    if (content == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            IconButton(
              icon: const Icon(Icons.volume_up, size: 20),
              onPressed: () => _speak(content),
              tooltip: 'Read $title',
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: MarkdownBody(
              data: content,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                 p: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildListSection(String title, List<String> items, IconData icon, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    // Join items for reading
    final fullText = items.join('. ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            IconButton(
               icon: const Icon(Icons.volume_up, size: 20),
               onPressed: () => _speak(fullText),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MarkdownBody(data: item),
                ),
              ],
            ),
          ),
        )),
        const SizedBox(height: 24),
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
class ElementDetailScreen extends StatelessWidget {
  final String elementName;
  final ElementAnalysis element;

  const ElementDetailScreen({
    super.key,
    required this.elementName,
    required this.element,
  });

  @override
  Widget build(BuildContext context) {
    // Sort behaviors by key (1.1, 1.2, etc.)
    final sortedKeys = element.behaviors.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(title: Text(elementName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Score Header
            Center(
              child: Column(
                children: [
                  Text(
                    element.score.toString(),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.getScoreColor(element.score),
                    ),
                  ),
                  const Text('Element Score'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Rationale
            const Text('Rationale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: MarkdownBody(data: element.rationale),
              ),
            ),
            const SizedBox(height: 24),

            // Behaviors List
            const Text('Observed Behaviors', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...sortedKeys.map((key) {
              final behavior = element.behaviors[key]!;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: _getRatingColor(behavior.rating),
                    child: Text(behavior.rating, style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(key.replaceAll('_', ' ').toUpperCase()),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Evidence:', style: TextStyle(fontWeight: FontWeight.bold)),
                          MarkdownBody(data: behavior.evidence),
                          
                          if (behavior.count != null) ...[
                             const SizedBox(height: 8),
                             Text('Count: ${behavior.count} instances'),
                          ],
                          
                          if (behavior.instancesFound.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            const Text('Specific Instances:', style: TextStyle(fontWeight: FontWeight.bold)),
                            ...behavior.instancesFound.map((i) => Text('• $i')),
                          ],
                          
                          if (behavior.limitations != null) ...[
                             const SizedBox(height: 8),
                             Text('Note: ${behavior.limitations!}', style: TextStyle(color: Colors.orange.shade800)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            
            if (element.limitationsNoted != null) ...[
               const SizedBox(height: 24),
               const Text('Element Limitations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
               Card(
                 color: AppTheme.warningColor.withOpacity(0.1),
                 child: Padding(
                   padding: const EdgeInsets.all(16),
                   child: MarkdownBody(data: element.limitationsNoted!),
                 ),
               ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getRatingColor(String rating) {
    switch (rating.toUpperCase()) {
      case 'H': return AppTheme.successColor;
      case 'M': return AppTheme.warningColor;
      case 'L': return AppTheme.errorColor;
      default: return Colors.grey;
    }
  }
}
