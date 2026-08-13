import 'dart:typed_data';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Professional, channel-aware notification service for AI Coach.
///
/// Android notification guidelines:
///  - Small icon MUST be a monochrome (alpha-only) drawable — we use
///    @drawable/ic_notification (a flat bar-chart icon).
///  - Large icon uses the launcher mipmap (optional; shown in expanded view).
///  - BigTextStyle makes long bodies readable without truncation.
///  - Each semantic category gets its own channel so users can
///    fine-tune which alerts they receive in Android settings.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  // ── Channel IDs ────────────────────────────────────────────────────────────
  static const _channelAnalysis = 'ai_coach_analysis';
  static const _channelErrors   = 'ai_coach_errors';
  static const _channelGeneral  = 'ai_coach_general';

  // ── Initialisation ─────────────────────────────────────────────────────────

  static Future<void> init() async {
    // Use monochrome drawable — NOT the launcher icon
    const androidSettings =
        AndroidInitializationSettings('@drawable/ic_notification');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings);

    // Request OS-level permission (Android 13+ / iOS)
    await Permission.notification.request();
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  // NOTE: [title] and [body] arrive already localized. This service has no
  // BuildContext, so the caller (RecordingProvider, which holds the locale)
  // builds the text via AppStrings.
  //
  // channelName / channelDescription stay English on purpose: Android caches
  // channel metadata at creation and ignores later changes, so translating them
  // would only affect fresh installs. They appear solely in system settings.

  /// Show an "Analysis complete" notification.
  static Future<void> showAnalysisSuccess({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _show(
      id: id,
      channelId: _channelAnalysis,
      channelName: 'Analysis Complete',
      channelDescription: 'Notifies you when a lesson analysis finishes.',
      title: title,
      body: body,
      payload: payload,
    );
  }

  /// Show an "Analysis failed" notification.
  static Future<void> showAnalysisFailure({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _show(
      id: id,
      channelId: _channelErrors,
      channelName: 'Analysis Errors',
      channelDescription: 'Notifies you when an analysis fails.',
      title: title,
      body: body,
      payload: payload,
    );
  }

  /// Generic notification (used for informational messages).
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _show(
      id: id,
      channelId: _channelGeneral,
      channelName: 'General',
      channelDescription: 'General AI Coach notifications.',
      title: title,
      body: body,
      payload: payload,
    );
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  static Future<void> _show({
    required int id,
    required String channelId,
    required String channelName,
    required String channelDescription,
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      // Monochrome icon — renders as pure white in the status bar
      icon: '@drawable/ic_notification',
      // Accent colour shown on the notification card background edge
      color: const Color(0xFF1B8C6E),
      // BigTextStyle prevents the body from being truncated
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'AI Coach',
      ),
      // Vibration pattern: short double-pulse (professional, not annoying)
      vibrationPattern: Int64List.fromList([0, 200, 100, 200]),
      enableVibration: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);
  }

  // ── Utility ────────────────────────────────────────────────────────────────

  /// Derives a stable, positive int32 notification ID from a recording UUID.
  static int generateNotificationId(String recordingId) =>
      recordingId.hashCode.abs() % 2147483647;
}
