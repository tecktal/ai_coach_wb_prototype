import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';

import '../../../data/models/recording.dart';
import '../../../data/models/analysis.dart';
import '../../../data/providers/auth_provider.dart';
import '../../../data/providers/recording_provider.dart';
import '../../../data/providers/analysis_provider.dart';
import '../recording/recordings_list_screen.dart';
import '../analysis/analysis_list_screen.dart';
import '../analysis/analysis_screen.dart';
import '../auth/login_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../data/services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const _RecordingTab(), // Main tab is now Recording
    const AnalysisListScreen(),
    const RecordingsListScreen(),
    const _DashboardTab(), // Moved Dashboard to end
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final recordingProvider = context.read<RecordingProvider>();
    final analysisProvider = context.read<AnalysisProvider>();

    await Future.wait([
      recordingProvider.loadRecordings(),
      analysisProvider.loadAnalyses(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Teaching Coach'),
        actions: const [],
      ),
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.mic),
            label: 'Record',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics),
            label: 'Analyses',
          ),
          NavigationDestination(
            icon: Icon(Icons.list),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
        ],
      ),
    );
  }
}

class _RecordingTab extends StatefulWidget {
  const _RecordingTab();

  @override
  State<_RecordingTab> createState() => _RecordingTabState();
}

class _RecordingTabState extends State<_RecordingTab> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  bool _isPaused = false;
  bool _isLocked = false; // NEW: Lock mode
  bool _isProcessing = false;

  // Playback State
  bool _isPlaying = false;
  Duration _playbackDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;

  Duration _duration = Duration.zero;
  Timer? _timer;
  String? _recordingPath;

  // Metadata for the recording
  final _titleController = TextEditingController();
  final _subjectController = TextEditingController();
  final _gradeController = TextEditingController();

  @override
  void initState() {
    super.initState();
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
    _recorder.dispose();
    _audioPlayer.dispose();
    _timer?.cancel();
    _titleController.dispose();
    _subjectController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path =
            '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _recorder.start(const RecordConfig(), path: path);

        setState(() {
          _isRecording = true;
          _isPaused = false;
          _recordingPath = path;
          // Clear previous metadata if any, or keep it? Let's clear for new session
          // _titleController.clear(); // Actually nicer to keep default or clear?
          if (_titleController.text.isEmpty) {
            _titleController.text =
                'Lesson ${DateTime.now().toString().split('.')[0]}';
          }
        });
        _startTimer();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: $e')),
      );
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
    if (_isLocked) return; // Prevent stop if locked

    final path = await _recorder.stop();
    _timer?.cancel();
    
    // Load duration so playback works immediately
    Duration? duration;
    if (path != null) {
       try {
         await _audioPlayer.setSource(DeviceFileSource(path));
         duration = await _audioPlayer.getDuration();
       } catch (e) {
         // Ignore setSource errors during stop, will fail on play if bad
       }
    }

    setState(() {
      _isRecording = false;
      _isPaused = false;
      _isLocked = false; // Reset lock
      _recordingPath = path;
      if (duration != null) {
         _playbackDuration = duration;
      }
    });
  }

  // --- NEW METHODS ---

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
    });
  }

  Future<void> _importAudio() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['m4a', 'mp3', 'wav', 'aac'],
      );

      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        
        // Fix: Load duration immediately
        await _audioPlayer.setSource(DeviceFileSource(path));
        final duration = await _audioPlayer.getDuration();

        setState(() {
          _recordingPath = path;
          _isRecording = false; // Ensure not recording
          _duration = duration ?? Duration.zero; 
          _playbackDuration = duration ?? Duration.zero;

          // Auto-fill title with filename
          _titleController.text = result.files.single.name;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Audio imported successfully')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing file: $e')),
        );
      }
    }
  }

  Future<void> _clearRecording() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Recording?'),
        content: const Text('This will discard the current recording and reset the screen. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _recordingPath = null;
        _isRecording = false;
        _isPaused = false;
        _isLocked = false;
        _duration = Duration.zero;
        _playbackDuration = Duration.zero;
        _playbackPosition = Duration.zero;
        _titleController.clear();
        _subjectController.clear();
        _gradeController.clear();
        // Reset player
        _audioPlayer.stop();
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_recordingPath == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() => _isPlaying = false);
      } else {
        // If we are at the end, restart
        if ((_playbackDuration.inMilliseconds > 0 && _playbackPosition >= _playbackDuration)) {
          await _audioPlayer.seek(Duration.zero);
          setState(() => _playbackPosition = Duration.zero);
        }

        await _audioPlayer.play(DeviceFileSource(_recordingPath!));
        setState(() => _isPlaying = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error playing audio: $e')),
        );
      }
    }
  }

  void _seek(double value) {
    final position = Duration(milliseconds: value.toInt());
    _audioPlayer.seek(position);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _duration = Duration(seconds: _duration.inSeconds + 1);
      });
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  void _startPollingForCompletion(String recordingId) {
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      // 1. Refresh Data
      await context.read<RecordingProvider>().loadRecordings();

      // 2. Check Status
      if (!mounted) {
        timer.cancel();
        return;
      }

      final recording =
          context.read<RecordingProvider>().getRecordingById(recordingId);

      if (recording != null) {
        if (recording.status == 'completed') {
          timer.cancel();

          // Show Local Notification
          NotificationService.showNotification(
            id: 1,
            title: 'Analysis Complete!',
            body: 'Your lesson analysis is ready. Tap to view.',
          );

          // Refresh Analysis List too
          if (mounted) context.read<AnalysisProvider>().loadAnalyses();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Analysis completed successfully!')),
          );
        } else if (recording.status == 'failed') {
          timer.cancel();
          NotificationService.showNotification(
            id: 1,
            title: 'Analysis Failed',
            body: 'There was an error analyzing your lesson.',
          );
        }
      }
    });
  }

  Future<void> _analyzeRecording() async {
    if (_recordingPath == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final recordingProvider = context.read<RecordingProvider>();
      final analysisProvider = context.read<AnalysisProvider>();
      final authProvider = context.read<AuthProvider>();

      // Ensure we are authenticated before uploading
      final isAuthenticated = await authProvider.ensureAuthenticated();
      if (!isAuthenticated) {
        throw Exception('Authentication failed. Please check your connection.');
      }

      // 1. Upload
      final success = await recordingProvider.uploadRecording(
        _recordingPath!,
        _titleController.text.isEmpty
            ? 'Untitled Lesson'
            : _titleController.text,
        null, // Description
        _subjectController.text.isEmpty ? null : _subjectController.text,
        _gradeController.text.isEmpty ? null : _gradeController.text,
        'en',
      );

      if (!success) {
        throw Exception(recordingProvider.error ?? 'Upload failed');
      }

      // 2. Trigger Analysis
      // We grab the first recording (newest) assuming it's the one we just uploaded
      final recordingId = recordingProvider.recordings.first.id;

      // This now returns immediately (202 Accepted)
      await analysisProvider.analyzeRecording(recordingId);

      // 3. Notify and Unblock
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Analysis started! You can continue using the app.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Refresh stats/lists in background
        context.read<RecordingProvider>().loadRecordings();
        context.read<AnalysisProvider>().loadAnalyses();

        // Start Polling for Completion
        _startPollingForCompletion(recordingId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Analysis failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analyzing your lesson...\nThis may take a minute.',
                textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header / Welcome logic could go here

          // NEW: Import Button (Top Right of Content)
          if (_recordingPath == null && !_isRecording)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _importAudio,
                icon: const Icon(Icons.upload_file),
                label: const Text('Import Audio'),
              ),
            ),

          // Main Recording Interface
          if (_recordingPath == null || _isRecording) ...[
          Card(
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Text(
                    _isRecording ? 'Recording in Progress' : 'Ready to Record',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 32),

                  InkWell(
                    // Use InkWell for better touch feedback
                    onTap: _isLocked
                        ? null
                        : (_isRecording
                            ? (_isPaused ? _resumeRecording : _pauseRecording)
                            : _startRecording),
                    borderRadius: BorderRadius.circular(60),
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording
                            ? (_isPaused
                                ? Colors.orange.shade100
                                : Colors.red.shade100)
                            : Colors.blue.shade50,
                        border: Border.all(
                          color: _isRecording ? Colors.red : Colors.blue,
                          width: 4,
                        ),
                      ),
                      child: Icon(
                        _isRecording
                            ? (_isPaused ? Icons.play_arrow : Icons.pause)
                            : Icons.mic,
                        size: 64,
                        color: _isRecording ? Colors.red : Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Controls Row: Pause and Lock
                  if (_isRecording)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         // Pause Button
                        IconButton(
                          onPressed: _isPaused ? _resumeRecording : _pauseRecording,
                          icon: Icon(
                            _isPaused ? Icons.play_circle_outline : Icons.pause_circle_outline, 
                            color: Colors.orange,
                            size: 32,
                            ),
                          tooltip: _isPaused ? 'Resume' : 'Pause',
                        ),
                        const SizedBox(width: 24),
                        // Lock Button
                        IconButton(
                          onPressed: _toggleLock,
                          icon: Icon(
                            _isLocked ? Icons.lock : Icons.lock_open,
                            color: _isLocked ? Colors.red : Colors.grey,
                            size: 32,
                          ),
                          tooltip: _isLocked ? 'Unlock to Stop' : 'Lock Recording',
                        ),
                      ],
                    ),

                  const SizedBox(height: 8),
                  Text(
                    _formatDuration(_duration),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontFeatures: [const FontFeature.tabularFigures()],
                    ),
                  ),
                  if (_isRecording) ...[
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _isLocked ? null : _stopRecording,
                      icon: const Icon(Icons.stop),
                      label: Text(
                          _isLocked ? 'Recording Locked' : 'Stop Recording'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isLocked ? Colors.grey : Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
          ],

          const SizedBox(height: 24),

          // Audio Player for Review
          if (_recordingPath != null && !_isRecording) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Review Recording',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: _clearRecording,
                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.grey), 
                          label: const Text('Clear', style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon:
                              Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                          onPressed: _togglePlayback,
                          iconSize: 32,
                          color: Colors.blue,
                        ),
                        Expanded(
                          child: Slider(
                            value: _playbackPosition.inMilliseconds.toDouble(),
                            max: _playbackDuration.inMilliseconds.toDouble() > 0
                                ? _playbackDuration.inMilliseconds.toDouble()
                                : 1.0,
                            onChanged: _seek,
                          ),
                        ),
                        Text(_formatDuration(_playbackPosition)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Metadata inputs (only show if not recording or if recorded)
          if (!_isRecording) ...[
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Lesson Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subjectController,
                    decoration: const InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.book),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _gradeController,
                    decoration: const InputDecoration(
                      labelText: 'Grade',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.school),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Analyze Button (Visible when file is recorded)
            if (_recordingPath != null)
              FilledButton.icon(
                onPressed: _analyzeRecording,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('ANALYZE LESSON'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(20),
                  textStyle: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final recordings = context.watch<RecordingProvider>().recordings;
    final analyses = context.watch<AnalysisProvider>().analyses;
    final user = context.watch<AuthProvider>().user;

    // final completedRecordings = recordings.where((r) => r.isCompleted).length; // Unused

    final avgScore = analyses.isEmpty
        ? 0.0
        : analyses.map((a) => a.overallScore ?? 0).reduce((a, b) => a + b) /
            analyses.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting
          Text(
            'Welcome back, ${user?.firstName ?? 'Teacher'}',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),

          Text(
            'Your Impact',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.mic,
                  title: 'Lessons',
                  value: recordings.length.toString(),
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  icon: Icons.star,
                  title: 'Avg Score',
                  value: avgScore.toStringAsFixed(1),
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // More stats...
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
