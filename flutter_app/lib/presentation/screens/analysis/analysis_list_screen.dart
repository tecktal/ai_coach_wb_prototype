import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../data/providers/analysis_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'analysis_screen.dart';

class AnalysisListScreen extends StatelessWidget {
  const AnalysisListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AnalysisProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.analyses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 80,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No analyses yet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text('Record a lesson and analyze it'),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.loadAnalyses,
          child: ListView.builder(
            itemCount: provider.analyses.length,
            itemBuilder: (context, index) {
              final analysis = provider.analyses[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.getScoreColorDouble(
                      analysis.overallScore ?? 0,
                    ),
                    child: Text(
                      analysis.overallScore?.toStringAsFixed(1) ?? '0.0',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    analysis.summary ?? 'Analysis',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${analysis.strengths.length} strengths, ${analysis.areasForImprovement.length} areas to improve',
                      ),
                      Text(
                        DateFormat('MMM d, y').format(analysis.createdAt),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AnalysisScreen(
                          analysisId: analysis.id,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}
