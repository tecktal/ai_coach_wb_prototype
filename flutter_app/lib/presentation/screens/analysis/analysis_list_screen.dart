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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<AnalysisProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
        }

        if (provider.analyses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: 80,
                  color: isDark ? Colors.grey[700] : Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'No analyses yet',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: isDark ? Colors.grey[400] : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Record a lesson and analyze it',
                  style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey.shade500),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: provider.loadAnalyses,
          color: Theme.of(context).primaryColor,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.analyses.length,
            itemBuilder: (context, index) {
              final analysis = provider.analyses[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? Colors.transparent : Colors.grey.shade100),
                  boxShadow: isDark ? [] : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.getScoreColorDouble(analysis.overallScore ?? 0).withValues(alpha: 0.3), width: 2),
                    ),
                    child: CircleAvatar(
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
                  ),
                  title: Text(
                    analysis.summary ?? 'Analysis',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textMain,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MMM d, y • h:mm a').format(analysis.createdAt),
                          style: TextStyle(color: isDark ? Colors.grey[400] : AppTheme.textSub, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.thumb_up_rounded, size: 14, color: AppTheme.successColor),
                            const SizedBox(width: 4),
                            Text(
                              '${analysis.strengths.length}',
                              style: TextStyle(color: isDark ? Colors.grey[300] : AppTheme.textMain, fontSize: 12),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.trending_up_rounded, size: 14, color: AppTheme.warningColor),
                            const SizedBox(width: 4),
                            Text(
                              '${analysis.areasForImprovement.length}',
                              style: TextStyle(color: isDark ? Colors.grey[300] : AppTheme.textMain, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: isDark ? Colors.grey[600] : Colors.grey.shade400),
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
