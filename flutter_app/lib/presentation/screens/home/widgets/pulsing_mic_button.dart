import 'package:flutter/material.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/theme/app_theme.dart';

class PulsingMicButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isRecording;
  final bool showLabel;
  final Color? accentColor;

  const PulsingMicButton({
    super.key,
    required this.onTap,
    this.isRecording = false,
    this.showLabel = true,
    this.accentColor,
  });

  @override
  State<PulsingMicButton> createState() => _PulsingMicButtonState();
}

class _PulsingMicButtonState extends State<PulsingMicButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppStrings.of(context).startRecordingLabel,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Pulse Effect 1
                if (!widget.isRecording)
                ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.2).animate(
                    CurvedAnimation(parent: _controller, curve: Curves.easeOut),
                  ),
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 0.5, end: 0.0).animate(
                      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
                    ),
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (widget.accentColor ?? AppTheme.primaryColor).withValues(alpha: 0.2),
                      ),
                    ),
                  ),
                ),
                // Pulse Effect 2 (Delayed)
                if (!widget.isRecording)
                ScaleTransition(
                  scale: Tween<double>(begin: 0.8, end: 1.2).animate(
                    CurvedAnimation(
                        parent: _controller,
                        curve: const Interval(0.5, 1.0, curve: Curves.easeOut)),
                  ),
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 0.5, end: 0.0).animate(
                      CurvedAnimation(
                          parent: _controller,
                          curve: const Interval(0.5, 1.0, curve: Curves.easeOut)),
                    ),
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (widget.accentColor ?? AppTheme.primaryColor).withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                // Main Button
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.accentColor != null
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              widget.accentColor!,
                              widget.accentColor!.withValues(alpha: 0.7),
                            ],
                          )
                        : AppTheme.micGradient,
                    boxShadow: [
                      BoxShadow(
                        color: (widget.accentColor ?? AppTheme.primaryColor).withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 4),
                  ),
                  child: const Icon(
                    Icons.mic,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ],
            ),
          ),
          if (widget.showLabel) ...[
            const SizedBox(height: 24),
            Text(
              'Tap to Record',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Capture your classroom audio',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
      ),
    );
  }
}
