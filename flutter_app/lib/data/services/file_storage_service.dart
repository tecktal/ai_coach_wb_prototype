import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class FileStorageService {
  /// Saves a recording file to the app's own storage and returns the saved
  /// path, or null on failure.
  ///
  /// Uses scoped, app-specific storage so the app needs **no** broad storage
  /// permissions (required for Google Play). On Android this is the app's
  /// external files dir (e.g. Android/data/<pkg>/files/Recordings); on iOS and
  /// elsewhere it's the app documents dir. Recordings are also uploaded to the
  /// backend, so they don't need to live in a public folder.
  Future<String?> saveRecordingToPhone(String sourcePath, String filename) async {
    try {
      final targetDir = await _recordingsDir();
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final targetPath = '${targetDir.path}/$filename';
      await File(sourcePath).copy(targetPath);
      return targetPath;
    } catch (e) {
      debugPrint('File storage error: $e');
      return null;
    }
  }

  /// Returns the app-specific directory where recordings are stored.
  Future<Directory> _recordingsDir() async {
    Directory base;
    if (Platform.isAndroid) {
      // App-specific external storage; no runtime permission required.
      base = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
    } else {
      base = await getApplicationDocumentsDirectory();
    }
    return Directory('${base.path}/Recordings');
  }

  /// Storage no longer requires any runtime permission (app-scoped storage).
  Future<bool> hasStoragePermission() async => true;
}
