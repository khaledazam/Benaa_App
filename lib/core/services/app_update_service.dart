import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppUpdateInfo {
  final String latestVersion;
  final int buildNumber;
  final String releaseNotes;
  final String downloadUrl;
  final bool isMandatory;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.buildNumber,
    required this.releaseNotes,
    required this.downloadUrl,
    this.isMandatory = false,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      latestVersion: json['latest_version'] ?? '1.0.0',
      buildNumber: json['build_number'] ?? 1,
      releaseNotes: json['release_notes'] ?? 'تحسينات عامة وإصلاحات في النظام.',
      downloadUrl: json['apk_download_url'] ?? '',
      isMandatory: json['is_mandatory'] ?? false,
    );
  }
}

class AppUpdateService {
  static const String currentVersion = '1.0.1';
  static const int currentBuildNumber = 2;

  // Remote version check endpoint
  static const String updateCheckUrl = 'https://raw.githubusercontent.com/khaledazam/Benaa_App/main/version.json';

  /// Check if a newer version is available (Non-blocking & offline-safe)
  static Future<AppUpdateInfo?> checkForUpdate({String? customUrl}) async {
    if (kIsWeb) return null;

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);

      final uri = Uri.parse(customUrl ?? updateCheckUrl);
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/json');

      final response = await request.close().timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        final data = jsonDecode(responseBody) as Map<String, dynamic>;

        final info = AppUpdateInfo.fromJson(data);
        if (info.buildNumber > currentBuildNumber) {
          return info;
        }
      }
    } catch (e) {
      // Silently catch network drops / offline state without interrupting operations
      debugPrint("Offline or unable to check updates: $e");
    }
    return null;
  }

  /// Show the Update Available Dialog
  static void showUpdateDialog(BuildContext context, AppUpdateInfo updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: !updateInfo.isMandatory,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.getCardBg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.primaryAccent, width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.rocket_launch_outlined, color: AppColors.primaryAccent, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'تحديث جديد متوفر (${updateInfo.latestVersion}) 🚀',
                style: TextStyle(
                  color: AppColors.getTextPrimary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الإصدار الحالي: v$currentVersion | الإصدار الجديد: v${updateInfo.latestVersion}',
              style: const TextStyle(color: AppColors.primaryAccent, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'أبرز ما في هذا التحديث:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.getBg(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.getBorder(context)),
              ),
              child: Text(
                updateInfo.releaseNotes,
                style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '🔒 جميع بيانات وفواتير المستودع المحلية تظل محفوظة 100% دون أي تغيير.',
              style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          if (!updateInfo.isMandatory)
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('تذكيري لاحقاً', style: TextStyle(color: AppColors.textSecondary)),
            ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.download, size: 18),
            label: const Text('تحديث وتثبيت الآن', style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () {
              Navigator.pop(ctx);
              debugPrint("Opening download URL: ${updateInfo.downloadUrl}");
            },
          ),
        ],
      ),
    );
  }
}
