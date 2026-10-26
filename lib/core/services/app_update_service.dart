import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../../presentation/widgets/enterprise/enterprise_button.dart';

class AppVersionInfo {
  final String version;
  final int buildNumber;
  final String releaseDate;
  final String title;
  final List<String> releaseNotes;
  final String apkUrl;
  final String webUrl;
  final bool forceUpdate;

  AppVersionInfo({
    required this.version,
    required this.buildNumber,
    required this.releaseDate,
    required this.title,
    required this.releaseNotes,
    required this.apkUrl,
    required this.webUrl,
    this.forceUpdate = false,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      version: json['version']?.toString() ?? '1.0.0',
      buildNumber: json['buildNumber'] is int ? json['buildNumber'] : int.tryParse(json['buildNumber']?.toString() ?? '1') ?? 1,
      releaseDate: json['releaseDate']?.toString() ?? '',
      title: json['title']?.toString() ?? 'تحديث جديد متاح',
      releaseNotes: (json['releaseNotes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      apkUrl: json['apkUrl']?.toString() ?? 'https://web-nine-rho-39.vercel.app/benaa-release.apk',
      webUrl: json['webUrl']?.toString() ?? 'https://web-nine-rho-39.vercel.app/',
      forceUpdate: json['forceUpdate'] == true,
    );
  }
}

class AppUpdateService {
  // Current client build metadata
  static const String currentVersion = '1.0.4';
  static const int currentBuildNumber = 5;

  static const String _versionEndpoint = 'https://web-nine-rho-39.vercel.app/version.json';
  static bool _hasPromptedThisSession = false;

  /// Check for updates silently on app startup (Dashboard)
  static Future<void> checkForUpdateSilent(BuildContext context) async {
    if (kIsWeb) return; // Web clients automatically run the latest deployed server code
    if (_hasPromptedThisSession) return;
    try {
      final update = await fetchRemoteVersion();
      if (update != null && update.buildNumber > currentBuildNumber) {
        _hasPromptedThisSession = true;
        if (context.mounted) {
          _showUpdateDialog(context, update);
        }
      }
    } catch (_) {}
  }

  static Future<AppVersionInfo?> checkForUpdate() async {
    try {
      final update = await fetchRemoteVersion();
      if (update != null && update.buildNumber > currentBuildNumber) {
        return update;
      }
    } catch (_) {}
    return null;
  }

  static void showUpdateDialog(BuildContext context, AppVersionInfo update) {
    _showUpdateDialog(context, update);
  }

  /// Check for updates manually from "المزيد" screen
  static Future<void> checkForUpdateManual(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 3),
                SizedBox(width: 16),
                Text('جاري التحقق من التحديثات السحابية...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final update = await fetchRemoteVersion();
      if (context.mounted) Navigator.pop(context); // Dismiss loading

      if (update != null && update.buildNumber > currentBuildNumber) {
        if (context.mounted) _showUpdateDialog(context, update);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.success,
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text('أنت تستخدم أحدث إصدار متاح حالياً (v$currentVersion).'),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.error,
            content: Text('تعذر الاتصال بخادم التحديثات، يرجى التحقق من اتصالك بالإنترنت.'),
          ),
        );
      }
    }
  }

  /// Fetch remote version.json
  static Future<AppVersionInfo?> fetchRemoteVersion() async {
    try {
      final res = await http.get(
        Uri.parse('$_versionEndpoint?t=${DateTime.now().millisecondsSinceEpoch}'),
      ).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        return AppVersionInfo.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Show the corporate In-App Update dialog
  static void _showUpdateDialog(BuildContext context, AppVersionInfo update) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: !update.forceUpdate,
      builder: (ctx) => PopScope(
        canPop: !update.forceUpdate,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header with Badge
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            update.title,
                            style: AppTypography.cardTitle(),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'الإصدار الجديد: v${update.version} • الحالي: v$currentVersion',
                            style: AppTypography.smallLabel(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Release notes list
                if (update.releaseNotes.isNotEmpty) ...[
                  Text(
                    'أبرز التحسينات والميزات الجديدة:',
                    style: AppTypography.smallLabel(color: AppColors.primary),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDark ? AppColors.borderDark : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: update.releaseNotes.map((note) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('⚡ ', style: TextStyle(fontSize: 12)),
                              Expanded(
                                child: Text(
                                  note,
                                  style: AppTypography.secondary(),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Action buttons
                Row(
                  children: [
                    if (!update.forceUpdate) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('لاحقاً'),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      flex: 2,
                      child: EnterpriseButton.primary(
                        label: kIsWeb ? 'تحديث المتصفح الآن' : 'تحميل وتثبيت التحديث',
                        icon: Icons.download_rounded,
                        onPressed: () async {
                          Navigator.pop(ctx);
                          if (kIsWeb) {
                            final uri = Uri.parse(update.webUrl);
                            await launchUrl(uri, webOnlyWindowName: '_self');
                          } else {
                            final uri = Uri.parse(update.apkUrl);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
