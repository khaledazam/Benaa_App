import 'package:flutter/material.dart';
import 'package:benaa_flutter_mobile/core/theme/app_colors.dart';
import 'package:benaa_flutter_mobile/core/theme/app_typography.dart';
import 'package:benaa_flutter_mobile/core/services/benaa_ai_service.dart';
import 'package:benaa_flutter_mobile/presentation/screens/ai_notification_center_screen.dart';

/// Compact Enterprise AI Section for Benaa ERP Dashboard
class DashboardAiWidget extends StatelessWidget {
  const DashboardAiWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE2E8F0);

    return ListenableBuilder(
      listenable: BenaaAiService(),
      builder: (context, _) {
        final ai = BenaaAiService();
        final latestInsight = ai.insights.isNotEmpty ? ai.insights.first : null;
        final unreadCount = ai.unreadCount;
        final highCount = ai.highSeverityCount;
        final isOffline = ai.isOffline;

        Color severityColor;
        String severityText;
        if (latestInsight?.severity == AiSeverity.high) {
          severityColor = AppColors.error;
          severityText = 'حرج جداً';
        } else if (latestInsight?.severity == AiSeverity.medium) {
          severityColor = AppColors.warning;
          severityText = 'تنبيه متوسط';
        } else {
          severityColor = AppColors.primary;
          severityText = 'فرصة ونمو';
        }

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AiNotificationCenterScreen()),
                );
              },
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.auto_awesome_rounded,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'ذكاء بناء | Benaa Intelligence',
                                      style: AppTypography.cardTitle(
                                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                      ).copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: isDark ? AppColors.borderDark : const Color(0xFFBFDBFE),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        'NaraRouter AI',
                                        style: AppTypography.smallLabel(
                                          color: isDark ? AppColors.primaryLight : AppColors.primary,
                                        ).copyWith(fontSize: 10, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  isOffline
                                      ? 'نسخة محفوظة محلياً (غير متصل)'
                                      : 'تحليل سحابي حي • ${ai.lastAnalysisTime}',
                                  style: AppTypography.smallLabel(
                                    color: isOffline
                                        ? AppColors.warning
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ).copyWith(fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$unreadCount جديد',
                              style: AppTypography.smallLabel(color: Colors.white).copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Latest Insight Highlight Box
                    if (latestInsight != null)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: severityColor.withOpacity(0.5), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: severityColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    severityText,
                                    style: AppTypography.smallLabel(color: severityColor).copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 10.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    latestInsight.title,
                                    style: AppTypography.cardTitle(
                                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                    ).copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              latestInsight.description,
                              style: AppTypography.secondary(
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              ).copyWith(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 10),

                    // Actions Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AiNotificationCenterScreen()),
                            );
                          },
                          icon: const Icon(Icons.notifications_active_outlined, size: 16),
                          label: Text(
                            highCount > 0 ? '$highCount تنبيهات حرجة متوفرة' : 'عرض كافة التحليلات',
                            style: AppTypography.smallLabel(
                              color: highCount > 0 ? AppColors.error : AppColors.primary,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        InkWell(
                          onTap: ai.isLoading ? null : () => ai.fetchInsights(forceRefresh: true),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Row(
                              children: [
                                if (ai.isLoading)
                                  const SizedBox(
                                    width: 13,
                                    height: 13,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                  )
                                else
                                  const Icon(Icons.refresh_rounded, size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  ai.isLoading ? 'جارٍ التحليل...' : 'تحليل فوري',
                                  style: AppTypography.smallLabel(color: AppColors.primary).copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
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
      },
    );
  }
}
