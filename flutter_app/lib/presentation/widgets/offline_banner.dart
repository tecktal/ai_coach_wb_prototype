import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/providers/connectivity_provider.dart';
import '../../core/l10n/app_strings.dart';

/// A compact amber banner that slides in below the AppBar (or at the top of
/// the screen body) whenever the device has no internet connection.
///
/// Uses [AnimatedContainer] to animate height 0 → 36 (and back) so that
/// the surrounding content is gently pushed down rather than abruptly jumping.
///
/// **Usage**: place it as the *first child* in any screen's body Column.
///
/// ```dart
/// Column(
///   children: [
///     const OfflineBanner(),
///     Expanded(child: ...),
///   ],
/// )
/// ```
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityProvider>().isOnline;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      // Collapses to 0 when online; expands to 36px when offline
      height: isOnline ? 0.0 : 36.0,
      // ClipRect prevents text from peeking out during the 0-height collapse
      child: ClipRect(
        child: Container(
          color: const Color(0xFFF59E0B), // Amber-500
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                AppStrings.of(context).offlineMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
