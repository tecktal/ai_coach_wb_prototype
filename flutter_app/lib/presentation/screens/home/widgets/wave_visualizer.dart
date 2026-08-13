import 'package:flutter/material.dart';
import 'dart:math';
import '../../../../core/theme/app_theme.dart';

class WaveVisualizer extends StatefulWidget {
  final bool isRecording;
  final bool isPaused;

  const WaveVisualizer({
    super.key,
    required this.isRecording,
    this.isPaused = false,
  });

  @override
  State<WaveVisualizer> createState() => _WaveVisualizerState();
}

class _WaveVisualizerState extends State<WaveVisualizer>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  final int _barCount = 12;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(_barCount, (index) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + _random.nextInt(600)),
      );
    });
    
    _updateAnimationState();
  }

  @override
  void didUpdateWidget(WaveVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording || 
        widget.isPaused != oldWidget.isPaused) {
      _updateAnimationState();
    }
  }

  void _updateAnimationState() {
    final shouldAnimate = widget.isRecording && !widget.isPaused;
    
    for (var controller in _controllers) {
      if (shouldAnimate) {
        if (!controller.isAnimating) {
          controller.repeat(reverse: true);
        }
      } else {
        if (controller.isAnimating) {
          controller.stop();
          // Reset to initial state for clean look
          controller.animateTo(0, duration: const Duration(milliseconds: 200));
        }
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        height: 120,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(_barCount, (index) {
            return AnimatedBuilder(
              animation: _controllers[index],
              builder: (context, child) {
                // When stopped, value will be 0 (or animating to 0)
                // When running, value oscillates 0..1
                final double height = 10.0 + (_controllers[index].value * 70);
                    
                return Container(
                  width: 6,
                  height: height,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.6 + (index % 3) * 0.1),
                    borderRadius: BorderRadius.circular(50),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
