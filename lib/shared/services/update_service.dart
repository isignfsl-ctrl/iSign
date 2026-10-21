import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_service.dart';

class UpdateInfo {
  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String notes;
  final bool force;

  const UpdateInfo({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.notes,
    required this.force,
  });
}

enum UpdateCheckStatus { upToDate, unavailable, updateAvailable }

class UpdateCheckResult {
  final UpdateCheckStatus status;
  final UpdateInfo? info;

  const UpdateCheckResult(this.status, [this.info]);
}

/// Thrown when the user cancels an in-progress download.
class UpdateCancelled implements Exception {
  const UpdateCancelled();
}

/// Checks Firestore `config/appVersion` for a newer release and downloads +
/// installs the APK. All checks are best-effort: offline or misconfigured
/// devices simply never see the dialog.
class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static const _channel = MethodChannel('isign.installer');
  static const _skipKey = 'skipped_update_version_code';

  var _cancelRequested = false;

  /// Aborts an in-progress [download] (takes effect on the next chunk).
  void cancelDownload() {
    _cancelRequested = true;
  }

  /// Checks for a newer version. Never throws. [ignoreSkip] re-checks a
  /// version the user previously dismissed with "Later".
  Future<UpdateCheckResult> check({bool ignoreSkip = false}) async {
    try {
      final fb = FirebaseService();
      if (!fb.isInitialized) {
        return const UpdateCheckResult(UpdateCheckStatus.unavailable);
      }

      final doc = await fb.firestore
          .collection('config')
          .doc('appVersion')
          .get()
          .timeout(const Duration(seconds: 8));
      final data = doc.data();
      final remoteCode = (data?['versionCode'] as num?)?.toInt();
      final apkUrl = (data?['apkUrl'] as String?) ?? '';
      if (remoteCode == null || apkUrl.isEmpty) {
        return const UpdateCheckResult(UpdateCheckStatus.upToDate);
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final localCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      if (remoteCode <= localCode) {
        return const UpdateCheckResult(UpdateCheckStatus.upToDate);
      }

      final force = data?['force'] == true;
      if (!force && !ignoreSkip) {
        final prefs = await SharedPreferences.getInstance();
        if ((prefs.getInt(_skipKey) ?? -1) == remoteCode) {
          return const UpdateCheckResult(UpdateCheckStatus.upToDate);
        }
      }

      return UpdateCheckResult(
        UpdateCheckStatus.updateAvailable,
        UpdateInfo(
          versionCode: remoteCode,
          versionName: (data?['versionName'] as String?) ?? '',
          apkUrl: apkUrl,
          notes: (data?['notes'] as String?) ?? '',
          force: force,
        ),
      );
    } catch (_) {
      return const UpdateCheckResult(UpdateCheckStatus.unavailable);
    }
  }

  /// Remembers that the user dismissed this version (ignored when force).
  Future<void> skipVersion(int versionCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_skipKey, versionCode);
  }

  Future<String> _updatesDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/updates');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  /// Already-downloaded APK for this version, if present (so a cancelled
  /// install doesn't force a full re-download).
  Future<File?> existingApk(UpdateInfo info) async {
    final file = File('${await _updatesDir()}/iSign-${info.versionCode}.apk');
    if (file.existsSync() && file.lengthSync() > 0) return file;
    return null;
  }

  /// Downloads the APK; [onProgress] gets 0..1 (or null if total unknown)
  /// and the received byte count.
  Future<File> download(
    UpdateInfo info,
    void Function(double? progress, int received) onProgress,
  ) async {
    _cancelRequested = false;
    final dirPath = await _updatesDir();

    // Drop partial or stale downloads from previous attempts.
    for (final f in Directory(dirPath).listSync().whereType<File>()) {
      try {
        f.deleteSync();
      } catch (_) {}
    }

    final partFile = File('$dirPath/iSign-${info.versionCode}.apk.part');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 30);
    try {
      final request = await client.getUrl(Uri.parse(info.apkUrl));
      request.followRedirects = true;
      final response = await request.close();
      if (response.statusCode != 200) {
        throw HttpException('Server returned ${response.statusCode}');
      }

      final total = response.contentLength; // -1 when unknown
      var received = 0;
      final sink = partFile.openWrite();
      try {
        await for (final chunk in response) {
          if (_cancelRequested) throw const UpdateCancelled();
          sink.add(chunk);
          received += chunk.length;
          onProgress(total > 0 ? received / total : null, received);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }

      final apkFile = File('$dirPath/iSign-${info.versionCode}.apk');
      await partFile.rename(apkFile.path);
      return apkFile;
    } catch (_) {
      if (partFile.existsSync()) {
        try {
          partFile.deleteSync();
        } catch (_) {}
      }
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  Future<bool> canInstall() async {
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the system "Install unknown apps" toggle for this app.
  Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod('openSettings');
    } catch (_) {}
  }

  /// Hands the file to Android's package installer.
  Future<void> install(File apk) async {
    await _channel.invokeMethod('install', {'path': apk.path});
  }
}
