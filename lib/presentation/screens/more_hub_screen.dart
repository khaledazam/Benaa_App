import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../providers/theme_provider.dart';
import '../providers/inventory_provider.dart';
import 'sync_manager_screen.dart';
import 'user_management_screen.dart';
import '../widgets/decoration_estimator_dialog.dart';
import '../widgets/printer_selection_dialog.dart';
import '../widgets/invoice_ocr_scanner_dialog.dart';
import '../widgets/absher_hawsu_dialog.dart';
import '../widgets/packaging_unit_converter_dialog.dart';
import '../../core/services/biometric_auth_service.dart';
import '../../core/services/cloud_auth_service.dart';
import '../../core/utils/download_helper.dart';
import 'login_screen.dart';

/// Enterprise More Hub Screen (المزيد والإعدادات والأدوات)
class MoreHubScreen extends StatelessWidget {
  const MoreHubScreen({Key? key}) : super(key: key);

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج من النظام؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await CloudAuthService.logout();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8, right: 4),
      child: Text(
        title,
        style: AppTypography.smallLabel(
          color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Material(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        child: ListTile(
          onTap: onTap,
          dense: true,
          leading: Icon(
            icon,
            size: 20,
            color: isDark ? AppColors.primaryLight : AppColors.primary,
          ),
          title: Text(
            title,
            style: AppTypography.cardTitle(
              color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
            ),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle,
                  style: AppTypography.secondary(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                  ),
                )
              : null,
          trailing: trailing ??
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDark ? const Color(0xFF64748B) : AppColors.textMuted,
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProv = Provider.of<ThemeProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = CloudAuthService.currentUser;
    final cardBg = isDark ? const Color(0xFF1E293B) : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;

    return Scaffold(
      appBar: AppBar(
        title: const Text('المزيد والأدوات'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Active User & Subscription Profile Card ---
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      child: Text(
                        (user?.name.isNotEmpty ?? false) ? user!.name[0] : 'U',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user?.name ?? 'المستخدم',
                                  style: AppTypography.cardTitle(
                                    color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  user?.role ?? 'STOREKEEPER',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: AppTypography.smallLabel(
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                      tooltip: 'تسجيل الخروج',
                      onPressed: () => _showLogoutDialog(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.warehouse_outlined, size: 16, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text(
                          user?.primaryWarehouseName ?? 'المستودع الرئيسي',
                          style: AppTypography.smallLabel(
                            color: isDark ? const Color(0xFFCBD5E1) : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (user?.isSubscriptionActive ?? true)
                            ? AppColors.success.withOpacity(0.1)
                            : AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            (user?.isSubscriptionActive ?? true)
                                ? Icons.verified_user_outlined
                                : Icons.warning_amber_rounded,
                            size: 14,
                            color: (user?.isSubscriptionActive ?? true) ? AppColors.success : AppColors.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            (user?.isSubscriptionActive ?? true)
                                ? 'الاشتراك مفعل'
                                : 'الاشتراك منتهي',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: (user?.isSubscriptionActive ?? true) ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          _buildSectionHeader(context, 'المزامنة والنظام السحابي'),
          _buildListTile(
            context,
            title: 'قاعدة بيانات MongoDB والمزامنة السحابية',
            subtitle: 'الاتصال المباشر مع buildstock_db ومزامنة المخزون والحسابات',
            icon: Icons.cloud_sync_rounded,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncManagerScreen()),
              );
            },
          ),
          _buildListTile(
            context,
            title: 'إدارة المستخدمين والصلاحيات (Super Admin)',
            subtitle: 'إنشاء حسابات فريق المستودع والمشتركين داخل الشركة',
            icon: Icons.admin_panel_settings_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserManagementScreen()),
              );
            },
          ),

          _buildSectionHeader(context, 'أدوات المستودع الذكية'),
          _buildListTile(
            context,
            title: 'حاسبة تقدير الأسقف والديكور',
            subtitle: 'حساب كميات بلاط الجبس، أوميجا، زوايا، وقضبان التعليق لمساحة المشروع',
            icon: Icons.calculate_outlined,
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => DecorationEstimatorDialog(
                  onAddItemsToCart: (estimatedItems) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.success,
                        content: Text('تم تقدير وإضافة ${estimatedItems.length} صنف للطلب'),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          _buildListTile(
            context,
            title: 'محول وحدات التعبئة والتجزئة',
            subtitle: 'التحويل بين الكرتون، الحبة، والمتر المربع',
            icon: Icons.swap_horiz_rounded,
            onTap: () {
              final invProv = Provider.of<InventoryProvider>(context, listen: false);
              showDialog(
                context: context,
                builder: (_) => PackagingUnitConverterDialog(
                  items: invProv.localItems,
                ),
              );
            },
          ),
          _buildListTile(
            context,
            title: 'مسح واستخراج الفواتير (OCR)',
            subtitle: 'تصوير الفاتورة الورقية وقراءة الأصناف والكميات تلقائياً',
            icon: Icons.document_scanner_outlined,
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => const InvoiceOcrScannerDialog(),
              );
            },
          ),
          _buildListTile(
            context,
            title: 'طابعة الباركود الحرارية (Bluetooth)',
            subtitle: 'إدارة وتوصيل طابعات الملصقات المحمولة بالمستودع',
            icon: Icons.print_outlined,
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => const PrinterSelectionDialog(),
              );
            },
          ),

          _buildSectionHeader(context, 'الأمان والمظهر'),
          _buildListTile(
            context,
            title: 'المظهر الليلي (Dark Mode)',
            subtitle: isDark ? 'المظهر الداكن مفعل' : 'المظهر الفاتح التجاري مفعل',
            icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            trailing: Switch.adaptive(
              value: isDark,
              activeTrackColor: AppColors.primary,
              onChanged: (_) => themeProv.toggleTheme(),
            ),
            onTap: () => themeProv.toggleTheme(),
          ),
          _buildListTile(
            context,
            title: 'التحقق البيومتري (بصمة الإصبع)',
            subtitle: 'التحقق من هوية أمين المستودع للمصادقة على العمليات الحساسة',
            icon: Icons.fingerprint_rounded,
            onTap: () async {
              final authSuccess = await BiometricAuthService.authenticate(
                reason: 'يرجى تأكيد بصمة الإصبع لمطابقة صلاحيات المستودع',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: authSuccess ? AppColors.success : AppColors.error,
                    content: Text(
                      authSuccess
                          ? 'تمت المصادقة البيومترية بنجاح'
                          : 'تعذرت المصادقة أو تم الإلغاء',
                    ),
                  ),
                );
              }
            },
          ),

          _buildSectionHeader(context, 'حول النظام'),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.border,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.business_outlined, size: 18, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نظام بناء لإدارة المخازن والديكور',
                          style: AppTypography.cardTitle(
                            color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'الإصدار 1.0.3 (Enterprise Build)',
                          style: AppTypography.smallLabel(
                            color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'مصمم خصيصاً للشركات السعودية لتسهيل إدارة المستودعات، مطابقة الجرد، وحساب كميات مواد التشطيب والجبس.',
                  style: AppTypography.secondary(
                    color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      triggerApkDownload();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: AppColors.success,
                          content: Text('جاري بدء تنزيل ملف التثبيت للأندرويد (benaa-release.apk)...'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.android_rounded, size: 18, color: Color(0xFF10B981)),
                    label: Text(
                      'تحميل تطبيق الأندرويد (APK)',
                      style: AppTypography.caption(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      side: BorderSide(color: isDark ? AppColors.borderDark : AppColors.border),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.verified_outlined, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      'حقوق الملكية خاصة بـ sir.duckld',
                      style: AppTypography.smallLabel(
                        color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                      ).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
