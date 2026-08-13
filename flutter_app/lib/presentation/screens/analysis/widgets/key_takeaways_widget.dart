import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/l10n/app_strings.dart';

class KeyTakeawaysWidget extends StatelessWidget {
  final List<String> strengths;
  final List<String> growthAreas;
  final Function(String text, String sectionId)? onSpeak;
  final bool isSpeaking;
  final String? currentSection;

  const KeyTakeawaysWidget({
    super.key,
    required this.strengths,
    required this.growthAreas,
    this.onSpeak,
    this.isSpeaking = false,
    this.currentSection,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSection(
          context,
          title: AppStrings.of(context).strengths,
          items: strengths,
          icon: Icons.check_circle_rounded,
          color: Colors.green,
          bgColor: Colors.green.shade50,
        ),
        const SizedBox(height: 16),
        _buildSection(
          context,
          title: AppStrings.of(context).growthAreas,
          items: growthAreas,
          icon: Icons.trending_up,
          color: Colors.orange,
          bgColor: Colors.orange.shade50,
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<String> items,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMain,
                  ),
                ),
              ),
              if (onSpeak != null && items.isNotEmpty)
                IconButton(
                  icon: Icon(
                    isSpeaking && currentSection == 'takeaways_$title'
                        ? Icons.stop_circle_outlined
                        : Icons.volume_up_outlined,
                    color: isSpeaking && currentSection == 'takeaways_$title'
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade600,
                  ),
                  onPressed: () {
                    final combinedText = items.join('. ');
                    onSpeak!(combinedText, 'takeaways_$title');
                  },
                  tooltip: isSpeaking && currentSection == 'takeaways_$title'
                      ? 'Stop reading'
                      : 'Read aloud',
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Text(
              AppStrings.of(context).noneIdentified,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            ...items.take(3).map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: CircleAvatar(
                          radius: 3, 
                          backgroundColor: color.withValues(alpha: 0.5)
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: MarkdownBody(
                          data: item,
                          styleSheet: MarkdownStyleSheet(
                            p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.textMain,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
