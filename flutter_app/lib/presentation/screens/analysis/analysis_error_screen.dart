import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_strings.dart';
import 'package:provider/provider.dart';
import '../../../data/models/recording.dart';
import '../../../data/providers/recording_provider.dart';
import '../../../data/services/api_service.dart';

class AnalysisErrorScreen extends StatefulWidget {
  final Recording recording;
  final String? localFilePath;

  const AnalysisErrorScreen({
    super.key,
    required this.recording,
    this.localFilePath,
  });

  @override
  State<AnalysisErrorScreen> createState() => _AnalysisErrorScreenState();
}

class _AnalysisErrorScreenState extends State<AnalysisErrorScreen> {
  bool _isRetrying = false;
  /// Once the teacher has triggered a retry, lock the button permanently
  /// to prevent multiple concurrent uploads of the same recording.
  bool _hasRetried = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(AppStrings.of(context).analysisFailed),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: AppTheme.textMain),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: AppTheme.errorColor,
              ),
            ),
            const SizedBox(height: 32),

            // Error Title
            Text(
              AppStrings.of(context).analysisCouldNotCompleteTitle,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textMain,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // Specific Error Message
            Text(
              _getFriendlyErrorMessage(),
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSub,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

            // Action Buttons
            if (_isRetrying)
              const CircularProgressIndicator()
            else
              Column(
                children: [
                  if (_canRetry() && !_hasRetried) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_isRetrying || _hasRetried) ? null : _handleRetry,
                        icon: Icon(Icons.refresh_rounded),
                        label: Text(AppStrings.of(context).retryAnalysis),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _handleDelete,
                      icon: Icon(Icons.delete_outline_rounded),
                      label: Text(AppStrings.of(context).deleteRecordingAction),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorColor,
                        side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(AppStrings.of(context).back),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _getFriendlyErrorMessage() {
    final strings = AppStrings.of(context);
    final reason = widget.recording.failureReason ?? 'unknown';

    // We deliberately do NOT prefer the backend's `error_message` here. It is
    // always English (handlers/analysis.go), so showing it would put English on
    // a Portuguese screen. The localized message is keyed on `failure_reason`,
    // which the backend also sends, and the duration comes from the recording
    // itself — so nothing specific is lost.
    if (strings.hasFailureMessage(reason)) {
      return strings.failureMessage(
        reason,
        seconds: widget.recording.durationSeconds,
      );
    }

    // Unrecognised reason: the server's text, untranslated, still beats nothing.
    final rawMessage = widget.recording.errorMessage;
    if (rawMessage != null && rawMessage.isNotEmpty) return rawMessage;

    return strings.failureMessage('unknown');
  }

  bool _canRetry() {
    // We can always retry:
    // - If local file exists → re-upload fresh
    // - If not → re-trigger analysis on the audio already on S3
    return true;
  }

  Future<void> _handleRetry() async {
    // One-shot guard — prevents double-tap from creating duplicate recordings.
    if (_hasRetried || _isRetrying) return;
    setState(() {
      _isRetrying = true;
      _hasRetried = true; // Lock permanently — teacher must go back and try fresh
    });

    try {
      final provider = Provider.of<RecordingProvider>(context, listen: false);

      // Path A: local file exists → delete old (failed) record and re-upload fresh
      final hasLocalFile = widget.localFilePath != null &&
          File(widget.localFilePath!).existsSync();

      if (hasLocalFile) {
        // Delete the failed recording first so it doesn't accumulate
        await provider.deleteRecording(widget.recording.id);

        final success = await provider.uploadRecording(
          widget.localFilePath!,
          widget.recording.title ?? 'Retried Recording',
          widget.recording.description,
          widget.recording.subject,
          widget.recording.gradeLevel,
          widget.recording.language,
          widget.recording.durationSeconds ?? 0,
        );

        if (!success && mounted) {
          final errMsg = provider.error;
          throw Exception(
            errMsg != null && errMsg.isNotEmpty
                ? errMsg
                : 'Upload failed during retry',
          );
        }
      } else {
        // Path B: audio is already on the server — just re-trigger the analysis
        await ApiService().analyzeRecording(widget.recording.id);
        provider.startPollingIfNeeded();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).analysisResubmitted)),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Re-enable retry on failure so the teacher can try again
      if (mounted) setState(() => _hasRetried = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.of(context).retryFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.of(context).deleteRecording),
        content: Text(AppStrings.of(context).actionCannotBeUndone),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.of(context).delete,
                style: const TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await Provider.of<RecordingProvider>(context, listen: false)
            .deleteRecording(widget.recording.id);
        if (mounted) {
          Navigator.of(context).pop(); // Close error screen
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppStrings.of(context).deleteFailed(e))),
          );
        }
      }
    }
  }
}
