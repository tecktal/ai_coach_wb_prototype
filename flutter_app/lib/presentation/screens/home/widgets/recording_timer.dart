import 'package:flutter/material.dart';
// import 'dart:ui';
import '../../../../core/theme/app_theme.dart';

class RecordingTimer extends StatelessWidget {
  final Duration duration;

  const RecordingTimer({super.key, required this.duration});

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes);
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          _formatDuration(duration),
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.textMain,
            fontFeatures: [const FontFeature.tabularFigures()],
            fontSize: 80, // Really big as per design
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
              SizedBox(width: 8),
              Text(
                'REC',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
