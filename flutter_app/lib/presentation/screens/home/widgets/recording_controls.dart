import 'package:flutter/material.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';

class RecordingControls extends StatelessWidget {
  final bool isPaused;
  final bool isLocked;
  final VoidCallback onPauseResume;
  final VoidCallback onStop;

  const RecordingControls({
    super.key,
    required this.isPaused,
    required this.isLocked,
    required this.onPauseResume,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pause/Resume Button
        Semantics(
          button: true,
          label: isPaused ? 'Resume recording' : 'Pause recording',
          child: InkWell(
            onTap: onPauseResume,
            borderRadius: BorderRadius.circular(50),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300, width: 2),
              ),
              child: Icon(
                isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                size: 40,
                color: AppTheme.textMain,
              ),
            ),
          ),
        ),
        const SizedBox(width: 40),
        
        // Stop Button
        Semantics(
          button: true,
          label: AppStrings.of(context).stopRecordingLabel,
          child: InkWell(
             onTap: isLocked ? null : onStop,
             borderRadius: BorderRadius.circular(50),
             child: Container(
               width: 80,
               height: 80,
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 color: isLocked ? Colors.grey.shade300 : const Color(0xFFEF4444), // Red
                 boxShadow: [
                   if (!isLocked)
                   BoxShadow(
                     color: Colors.red.withValues(alpha: 0.3),
                     blurRadius: 15,
                     offset: const Offset(0, 8),
                   ),
                 ],
               ),
               child: const Icon(
                 Icons.stop_rounded,
                 size: 40,
                 color: Colors.white,
               ),
             ),
          ),
        ),
      ],
    );
  }
}
