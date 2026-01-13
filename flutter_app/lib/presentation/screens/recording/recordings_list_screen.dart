import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/recording_provider.dart';
import '../../../data/providers/analysis_provider.dart';
import 'package:intl/intl.dart';

class RecordingsListScreen extends StatelessWidget {
  const RecordingsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RecordingProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.recordings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mic_none,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No recordings yet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('Start by recording a lesson'),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.loadRecordings,
          child: ListView.builder(
            itemCount: provider.recordings.length,
            itemBuilder: (context, index) {
              final recording = provider.recordings[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: recording.isCompleted
                        ? Colors.green
                        : recording.isProcessing
                            ? Colors.orange
                            : Colors.grey,
                    child: Icon(
                      recording.isCompleted
                          ? Icons.check
                          : recording.isProcessing
                              ? Icons.hourglass_empty
                              : Icons.mic,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(recording.title ?? 'Untitled Recording'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (recording.subject != null)
                        Text('Subject: ${recording.subject}'),
                      Text(
                        'Status: ${recording.statusDisplay}',
                        style: TextStyle(
                          color: recording.isCompleted
                              ? Colors.green
                              : recording.isFailed
                                  ? Colors.red
                                  : null,
                        ),
                      ),
                      Text(
                        DateFormat('MMM d, y').format(recording.createdAt),
                      ),
                    ],
                  ),
                  trailing: PopupMenuButton(
                    itemBuilder: (context) => [
                      if (recording.isCompleted)
                        PopupMenuItem(
                          child: const ListTile(
                            leading: Icon(Icons.analytics),
                            title: Text('View Analysis'),
                          ),
                          onTap: () async {
                            final analysisProvider =
                                context.read<AnalysisProvider>();
                            await analysisProvider.loadAnalyses();
                            // Find analysis for this recording
                            // Navigate to analysis screen
                          },
                        ),
                      if (recording.isPending)
                        PopupMenuItem(
                          child: const ListTile(
                            leading: Icon(Icons.play_arrow),
                            title: Text('Analyze'),
                          ),
                          onTap: () async {
                            final analysisProvider =
                                context.read<AnalysisProvider>();
                            await analysisProvider.analyzeRecording(recording.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Analysis started!'),
                                ),
                              );
                            }
                          },
                        ),
                      PopupMenuItem(
                        child: const ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text('Delete'),
                        ),
                        onTap: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Recording'),
                              content: const Text(
                                'Are you sure you want to delete this recording?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true && context.mounted) {
                            await provider.deleteRecording(recording.id);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
