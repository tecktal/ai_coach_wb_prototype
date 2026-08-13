/// In-app log buffer for debugging on physical devices without USB.
///
/// Usage:
///   AppLogger.log('my message');   // instead of debugPrint
///   AppLogger.capture();           // intercepts all debugPrint calls
///
/// To view: a "Copy Logs" button in the chat screen copies all logs
/// to clipboard so you can paste them into the chat.
library;

import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static final List<String> _logs = [];
  static const int _maxLines = 300;

  /// Call once in main() to intercept all debugPrint calls.
  static void capture() {
    debugPrint = (String? message, {int? wrapWidth}) {
      final line = '[${_timestamp()}] ${message ?? ''}';
      _logs.add(line);
      if (_logs.length > _maxLines) _logs.removeAt(0);
      // Also print to console so ADB logcat still works when connected.
      if (kDebugMode) {
        // ignore: avoid_print
        print(line);
      }
    };
  }

  static void log(String message) {
    debugPrint(message);
  }

  static String dump() => _logs.join('\n');

  static void clear() => _logs.clear();

  static String _timestamp() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';
  }
}
