import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import '../../../data/providers/recording_provider.dart';

class RecordingScreen extends StatefulWidget {
  const RecordingScreen({super.key});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final AudioRecorder _recorder = AudioRecorder();
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
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _recordingPath = path;
    });
    _timer?.cancel();
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

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate() || _recordingPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please record or select an audio file')),
      );
      return;
    }

    final provider = context.read<RecordingProvider>();
    final success = await provider.uploadRecording(
      _recordingPath!,
      _titleController.text.trim(),
      _descriptionController.text.trim().isEmpty 
          ? null 
          : _descriptionController.text.trim(),
      _subjectController.text.trim().isEmpty 
          ? null 
          : _subjectController.text.trim(),
      _gradeLevelController.text.trim().isEmpty 
          ? null 
          : _gradeLevelController.text.trim(),
      'en',
    );

    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording uploaded successfully!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Upload failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes);
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Recording'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        _isRecording ? Icons.mic : Icons.mic_none,
                        size: 80,
                        color: _isRecording ? Colors.red : Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _formatDuration(_duration),
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 24),
                      if (!_isRecording)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _startRecording,
                              icon: const Icon(Icons.mic),
                              label: const Text('Start Recording'),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton.icon(
                              onPressed: _pickFile,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Upload File'),
                            ),
                          ],
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              iconSize: 48,
                              onPressed: _isPaused ? _resumeRecording : _pauseRecording,
                              icon: Icon(
                                _isPaused ? Icons.play_arrow : Icons.pause,
                              ),
                            ),
                            const SizedBox(width: 24),
                            IconButton(
                              iconSize: 48,
                              onPressed: _stopRecording,
                              icon: const Icon(Icons.stop, color: Colors.red),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              if (_recordingPath != null) ...[
                Text(
                  'Recording Details',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'e.g., Math Lesson - Fractions',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'Brief description of the lesson',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Subject (Optional)',
                    hintText: 'e.g., Mathematics, Science',
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _gradeLevelController,
                  decoration: const InputDecoration(
                    labelText: 'Grade Level (Optional)',
                    hintText: 'e.g., 3rd Grade',
                  ),
                ),
                const SizedBox(height: 24),
                Consumer<RecordingProvider>(
                  builder: (context, provider, child) {
                    return ElevatedButton(
                      onPressed: provider.isUploading ? null : _upload,
                      child: provider.isUploading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Upload Recording'),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
