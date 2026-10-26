import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'transfers_list_screen.dart';
import 'stock_audit_screen.dart';
import 'sales_issuance_screen.dart';
import 'returns_management_screen.dart';

/// Enterprise Operations Hub Screen (العمليات المخزنية)
class OperationsHubScreen extends StatelessWidget {
  const OperationsHubScreen({Key? key}) : super(key: key);

  Widget _buildOperationTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.cardTitle(
                          color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: AppTypography.secondary(
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: isDark ? const Color(0xFF64748B) : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العمليات وحركة البضائع'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildOperationTile(
            context,
            title: 'استلام وإرسال الشحنات بين الفروع',
            subtitle: 'متابعة البضاعة الواردة للمستودع وتأكيد استلامها أو إرسال مواد لفرع آخر',
            icon: Icons.local_shipping_rounded,
            accentColor: AppColors.primary,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TransfersListScreen()),
              );
            },
          ),
          _buildOperationTile(
            context,
            title: 'جرد البضاعة الفعلي بالباركود',
            subtitle: 'مطابقة الكميات الحقيقية على الأرفف واكتشاف وتعديل أي عجز أو زيادة',
            icon: Icons.qr_code_scanner_rounded,
            accentColor: AppColors.warning,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StockAuditScreen()),
              );
            },
          ),
          _buildOperationTile(
            context,
            title: 'صرف بضاعة وفواتير بيع',
            subtitle: 'تسليم المواد للعملاء والمقاولين وخصمها فوراً من رصيد المستودع',
            icon: Icons.outbox_rounded,
            accentColor: AppColors.success,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SalesIssuanceScreen()),
              );
            },
          ),
          _buildOperationTile(
            context,
            title: 'استلام بضاعة مرتجعة من عميل',
            subtitle: 'فحص المواد المعادة من العميل وإرجاعها لحساب المستودع',
            icon: Icons.assignment_return_rounded,
            accentColor: AppColors.error,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReturnsManagementScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
