import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/l10n/app_strings.dart';

class StickyActionCard extends StatelessWidget {
  final String title;
  final String description;
  final String example;
  /// Optional 1-based position number. When provided, a numbered badge is shown.
  final int? index;

  const StickyActionCard({
    super.key,
    required this.title,
    required this.description,
    required this.example,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMain = isDark ? Colors.white : AppTheme.textMain;
    final textSub = isDark ? Colors.white60 : AppTheme.textSub;
    final innerBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — only shown on first card (index == null or index == 1)
          if (index == null || index == 1) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.rocket_launch, color: Theme.of(context).primaryColor),
                ),
                const SizedBox(width: 12),
                Text(
                  AppStrings.of(context).nextSteps,
                  style: TextStyle(
                    color: Theme.of(context).primaryColor,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Number badge + title row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index != null) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: textMain,
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: textSub,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: innerBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).primaryColor.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.tips_and_updates, color: Theme.of(context).primaryColor, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.of(context).example,
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '"$example"',
                  style: TextStyle(
                    color: textMain,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

