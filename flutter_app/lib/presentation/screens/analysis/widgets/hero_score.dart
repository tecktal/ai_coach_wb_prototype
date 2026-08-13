import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Displays the lesson title and date as a clean, centered header.
/// No score ring, no grade labels — per World Bank feedback.
class HeroScore extends StatelessWidget {
  final double score; // kept for API compatibility but not displayed
  final String date;
  final String title;

  const HeroScore({
    super.key,
    required this.score,
    required this.date,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // "Analysis Complete" pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline_rounded,
                  size: 14, color: primaryColor),
              const SizedBox(width: 6),
              Text(
                'Analysis Complete',
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Lesson title
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textMain,
            height: 1.25,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        // Date
        Text(
          date,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSub,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
