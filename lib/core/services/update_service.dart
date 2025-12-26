import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Self-hosted OTA Update Service
/// Checks GitHub for new versions and prompts user to update
class UpdateService {
  // GitHub raw URL for version check
  static const String _versionUrl =
      'https://raw.githubusercontent.com/workbhaveshpandey-create/kreoassist/main/version.json';

  /// Check for updates and show dialog if available
  static Future<void> checkForUpdates(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(_versionUrl)).timeout(
            const Duration(seconds: 10),
          );

      if (response.statusCode == 200) {
        final remoteVersion = json.decode(response.body);
        final packageInfo = await PackageInfo.fromPlatform();

        final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
        final remoteBuild = remoteVersion['build'] as int? ?? 0;

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
        }
      }
    } catch (e) {
      // Silently fail - don't interrupt user experience
      debugPrint('Update check failed: $e');
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
            onPressed: () async {
              Navigator.pop(ctx);
              if (downloadUrl.isNotEmpty) {
                final uri = Uri.parse(downloadUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
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
}
