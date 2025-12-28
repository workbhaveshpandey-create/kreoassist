import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:background_downloader/background_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'notification_service.dart';

/// Self-hosted OTA Update Service
/// Checks GitHub for new versions and prompts user to update
class UpdateService {
  // GitHub raw URL for version check
  static const String _versionUrl =
      'https://raw.githubusercontent.com/workbhaveshpandey-create/kreoassist/master/version.json';

  /// Check for updates and show dialog if available
  static Future<void> checkForUpdates(BuildContext context) async {
    // Silent check - only show notification if update is available or error occurs

    try {
      // Add cache-bust parameter to prevent stale cached responses
      final cacheBustUrl =
          '$_versionUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('Update check URL: $cacheBustUrl');

      final response = await http.get(Uri.parse(cacheBustUrl)).timeout(
            const Duration(seconds: 15),
          );

      debugPrint('Update check response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final remoteVersion = json.decode(response.body);
        final packageInfo = await PackageInfo.fromPlatform();

        final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
        final remoteBuild = remoteVersion['build'] as int? ?? 0;

        debugPrint("Update check: Remote=$remoteBuild, Current=$currentBuild");

        if (remoteBuild > currentBuild) {
          // New version available!
          if (context.mounted) {
            _showUpdateDialog(
              context,
              currentVersion: packageInfo.version,
              newVersion: remoteVersion['version'] as String? ?? 'Unknown',
              releaseNotes: remoteVersion['release_notes'] as String? ?? '',
              downloadUrl: remoteVersion['download_url'] as String? ?? '',
            );
          }
        } else {
          // Silent - app is up to date, no notification needed
          debugPrint("App is up to date (v${packageInfo.version})");
        }
      } else {
        if (context.mounted) {
          _showSnackBar(context,
              "Update check failed: HTTP ${response.statusCode}", Colors.red);
        }
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
      if (context.mounted) {
        _showSnackBar(context, "Update error: $e", Colors.red);
      }
    }
  }

  /// Helper to show floating notification at TOP (more visible than bottom SnackBar)
  static OverlayEntry? _overlayEntry;

  static void _showSnackBar(BuildContext context, String message, Color color) {
    // Remove existing overlay if any
    _overlayEntry?.remove();
    _overlayEntry = null;

    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, -20 * (1 - value)),
                child: child,
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.5)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 16,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      color == Colors.green
                          ? Icons.check_circle
                          : color == Colors.red
                              ? Icons.error
                              : Icons.info,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);

    // Auto-dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  /// Check for updates in background (Headless)
  static Future<void> checkForUpdatesInBackground() async {
    try {
      // Cache-bust to ensure fresh response
      final cacheBustUrl =
          '$_versionUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      final response = await http
          .get(Uri.parse(cacheBustUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final remoteVersion = json.decode(response.body);
        final packageInfo = await PackageInfo.fromPlatform();

        final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
        final remoteBuild = remoteVersion['build'] as int? ?? 0;

        if (remoteBuild > currentBuild) {
          await NotificationService.showUpdateNotification(
              version: remoteVersion['version'] as String? ?? 'Unknown');
        }
      }
    } catch (e) {
      debugPrint("Background update check failed: $e");
    }
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String currentVersion,
    required String newVersion,
    required String releaseNotes,
    required String downloadUrl,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.system_update, color: Color(0xFF4CAF50)),
            ),
            const SizedBox(width: 12),
            const Text(
              'Update Available!',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'v$currentVersion → v$newVersion',
              style: const TextStyle(
                color: Color(0xFF4CAF50),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            if (releaseNotes.isNotEmpty) ...[
              const Text(
                "What's New:",
                style: TextStyle(
                    color: Colors.white70, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                releaseNotes,
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your data will be preserved after update.',
                      style: TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              if (downloadUrl.isNotEmpty) {
                _startDownload(context, downloadUrl, newVersion);
              }
            },
            icon: const Icon(Icons.download),
            label: const Text('Download Now'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }

  /// Download APK with progress dialog
  static Future<void> _startDownload(
    BuildContext context,
    String downloadUrl,
    String version,
  ) async {
    // Show download progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DownloadProgressDialog(
        downloadUrl: downloadUrl,
        version: version,
      ),
    );
  }
}

/// Download Progress Dialog Widget
class _DownloadProgressDialog extends StatefulWidget {
  final String downloadUrl;
  final String version;

  const _DownloadProgressDialog({
    required this.downloadUrl,
    required this.version,
  });

  @override
  State<_DownloadProgressDialog> createState() =>
      _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<_DownloadProgressDialog> {
  double _progress = 0.0;
  String _status = 'Starting download...';
  bool _isComplete = false;
  bool _hasError = false;
  String? _filePath;

  @override
  void initState() {
    super.initState();
    _downloadApk();
  }

  Future<void> _downloadApk() async {
    try {
      final fileName = 'kreoassist-${widget.version}.apk';

      final task = DownloadTask(
        url: widget.downloadUrl,
        filename: fileName,
        directory: 'updates',
        baseDirectory: BaseDirectory.applicationDocuments,
        updates: Updates.statusAndProgress,
        requiresWiFi: false,
        retries: 3,
      );

      // Start download with progress tracking
      final result = await FileDownloader().download(
        task,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _status = 'Downloading... ${(progress * 100).toInt()}%';
            });
          }
        },
        onStatus: (status) {
          if (mounted) {
            if (status == TaskStatus.complete) {
              setState(() {
                _isComplete = true;
                _status = 'Download complete! Tap to install.';
              });
            } else if (status == TaskStatus.failed) {
              setState(() {
                _hasError = true;
                _status = 'Download failed. Please try again.';
              });
            }
          }
        },
      );

      if (result.status == TaskStatus.complete) {
        // Get the file path
        final dir = await getApplicationDocumentsDirectory();
        _filePath = '${dir.path}/updates/$fileName';

        if (mounted) {
          setState(() {
            _isComplete = true;
            _status = 'Download complete! Tap to install.';
          });
        }
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _status = 'Download failed: $e';
        });
      }
    }
  }

  Future<void> _installApk() async {
    if (_filePath != null) {
      try {
        final result = await OpenFilex.open(_filePath!);
        if (result.type != ResultType.done) {
          debugPrint('Failed to open APK: ${result.message}');
        }
      } catch (e) {
        debugPrint('Install error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            _hasError
                ? Icons.error_outline
                : _isComplete
                    ? Icons.check_circle
                    : Icons.downloading,
            color: _hasError
                ? Colors.red
                : _isComplete
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF2196F3),
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            _hasError
                ? 'Download Failed'
                : _isComplete
                    ? 'Ready to Install'
                    : 'Downloading Update',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isComplete && !_hasError) ...[
            LinearProgressIndicator(
              value: _progress,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            _status,
            style: TextStyle(
              color: _hasError ? Colors.red : Colors.white70,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          if (_isComplete) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.install_mobile,
                      color: Color(0xFF4CAF50), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tap Install to update the app',
                      style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        if (_hasError || _isComplete)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              _hasError ? 'Close' : 'Later',
              style: const TextStyle(color: Colors.white54),
            ),
          ),
        if (_isComplete)
          FilledButton.icon(
            onPressed: _installApk,
            icon: const Icon(Icons.install_mobile),
            label: const Text('Install'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
          ),
        if (_hasError)
          FilledButton.icon(
            onPressed: () {
              setState(() {
                _hasError = false;
                _progress = 0;
                _status = 'Retrying...';
              });
              _downloadApk();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2196F3),
            ),
          ),
      ],
    );
  }
}
