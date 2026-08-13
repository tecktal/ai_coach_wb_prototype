import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class LockToggle extends StatelessWidget {
  final bool isLocked;
  final ValueChanged<bool> onChanged;

  const LockToggle({
    super.key,
    required this.isLocked,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            isLocked ? Icons.lock : Icons.lock_open,
            color: isLocked ? Theme.of(context).primaryColor : Colors.grey,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text(
                   'Screen Lock',
                   style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                     fontWeight: FontWeight.bold,
                     color: AppTheme.textMain,
                   ),
                 ),
                 Text(
                   isLocked ? 'Prevent touches' : 'Unlocked',
                   style: Theme.of(context).textTheme.bodySmall?.copyWith(
                     color: AppTheme.textSub,
                   ),
                   overflow: TextOverflow.ellipsis,
                 ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch.adaptive(
            value: isLocked,
            onChanged: onChanged,
            activeTrackColor: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}
