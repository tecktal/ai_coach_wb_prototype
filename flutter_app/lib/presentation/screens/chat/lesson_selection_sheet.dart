import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../data/providers/analysis_provider.dart';
import '../../../data/providers/recording_provider.dart';
import '../../../core/theme/app_theme.dart';

class LessonSelectionSheet extends StatelessWidget {
  const LessonSelectionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Text(
              'Start New Coaching Session',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.textMain,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Select a lesson to discuss with your AI Coach',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[400] : AppTheme.textSub,
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          Consumer2<AnalysisProvider, RecordingProvider>(
            builder: (context, analysisProvider, recordingProvider, _) {
              if (analysisProvider.isLoading) {
                return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
              }
              
              if (analysisProvider.analyses.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Icon(Icons.assignment_outlined, size: 48, color: isDark ? Colors.grey[600] : Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'No analyzed lessons yet',
                          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Create a map for fast lookup: RecordingID -> Recording
              final recordingMap = {
                for (var r in recordingProvider.recordings) r.id: r
              };

              return ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: analysisProvider.analyses.length + 1, 
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    
                    if (index == 0) {
                      return Container(
                         decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.transparent : Colors.purple.shade100),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isDark ? Colors.purple.withValues(alpha: 0.2) : Colors.white,
                            child: Icon(Icons.chat_bubble_outline, color: Colors.purple),
                          ),
                          title: Text(
                            'General Coaching',
                            style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                          ),
                          subtitle: Text(
                            'Ask general teaching questions',
                            style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          ),
                          onTap: () => Navigator.pop(context, null), 
                        ),
                      );
                    }

                    final analysis = analysisProvider.analyses[index - 1];
                    final recording = recordingMap[analysis.recordingId];
                    final date = DateFormat('MMM d').format(analysis.createdAt);
                    final title = recording?.title ?? 'Untitled Lesson';
                    final subject = recording?.subject ?? 'General';

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
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
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.analytics_outlined, color: Theme.of(context).primaryColor, size: 24),
                        ),
                        title: Text(
                          title, 
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.textMain
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '$subject • $date • Score: ${analysis.overallScore?.toStringAsFixed(1) ?? "-"}',
                          style: TextStyle(color: isDark ? Colors.grey[400] : AppTheme.textSub, fontSize: 13),
                        ),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                        onTap: () => Navigator.pop(context, analysis.id),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
