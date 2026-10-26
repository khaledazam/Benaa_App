import 'projects_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../providers/inventory_provider.dart';
import 'transfers_list_screen.dart';
import 'transfer_audit_detail_screen.dart';
import 'stock_audit_screen.dart';
import 'local_stock_screen.dart';
import 'sales_issuance_screen.dart';
import 'sync_manager_screen.dart';
import 'user_management_screen.dart';
import '../widgets/enterprise/kpi_card.dart';
import '../widgets/enterprise/stock_badge.dart';
import '../widgets/enterprise/section_header.dart';
import '../widgets/enterprise/enterprise_empty_state.dart';
import '../widgets/create_transfer_dialog.dart';
import '../widgets/barcode_print_picker_dialog.dart';
import '../widgets/packaging_unit_converter_dialog.dart';
import '../widgets/warehouse_location_dialog.dart';
import '../widgets/customer_statement_dialog.dart';
import '../widgets/invoice_ocr_scanner_dialog.dart';
import '../../core/services/pdf_report_service.dart';
import '../../core/services/share_service.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/benaa_ai_service.dart';
import '../widgets/ai/dashboard_ai_widget.dart';
import 'ai_notification_center_screen.dart';

/// Clean Operational Enterprise Dashboard for Benaa Warehouse ERP
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = Provider.of<InventoryProvider>(context, listen: false);
      provider.loadTransfers();
      provider.loadLocalItems();

      // Silent opportunistic background update check
      final updateInfo = await AppUpdateService.checkForUpdate();
      if (updateInfo != null && mounted) {
        AppUpdateService.showUpdateDialog(context, updateInfo);
      }
    });
  }

  Widget _buildWarehouseContextCard(BuildContext context, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.1),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.borderDark : const Color(0xFFBFDBFE),
                width: 1,
              ),
            ),
            child: const Center(
              child: Icon(Icons.warehouse_rounded, color: AppColors.primary, size: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  children: [
                    Text(
                        'مستودع مواد البناء والديكور الرئيسي',
                        style: AppTypography.cardTitle(
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                        ).copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'WH-01',
                        style: AppTypography.smallLabel(
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'فرع القصيم • الوردية الأولى • المشرف: أمين المستودع',
                  style: AppTypography.secondary(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncManagerScreen()),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.success.withOpacity(0.25), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'متصل سحابياً',
                    style: AppTypography.smallLabel(color: AppColors.success).copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String badgeText,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE2E8F0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.1),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.25), width: 1),
                ),
                child: Center(
                  child: Icon(icon, color: color, size: 24),
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
                            title,
                            style: AppTypography.cardTitle(
                              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                            ).copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badgeText,
                            style: AppTypography.smallLabel(color: color).copyWith(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTypography.secondary(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryActionCard(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE2E8F0);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    style: AppTypography.cardTitle(
                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                    ).copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE2E8F0);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'بناء — إدارة المستودع',
          style: AppTypography.screenTitle(
            color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
          ).copyWith(fontSize: 19),
        ),
        actions: [
          ListenableBuilder(
            listenable: BenaaAiService(),
            builder: (context, _) {
              final unread = BenaaAiService().unreadCount;
              final high = BenaaAiService().highSeverityCount;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                      size: 23,
                      color: unread > 0 ? (high > 0 ? AppColors.error : AppColors.primary) : null,
                    ),
                    tooltip: 'مركز تنبيهات ذكاء بناء',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AiNotificationCenterScreen(),
                        ),
                      );
                    },
                  ),
                  if (unread > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: high > 0 ? AppColors.error : AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            width: 1.5,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, size: 21),
            tooltip: 'تصدير تقرير المستودع',
            onPressed: () async {
              final prov = Provider.of<InventoryProvider>(context, listen: false);
              final totalVal = prov.localItems.fold<double>(0.0, (s, i) => s + (i.currentStock * i.unitPrice));
              final lowCount = prov.localItems.where((i) => i.currentStock <= 15).length;
              await PdfReportService.printOrPreviewReport(
                items: prov.localItems,
                totalValuation: totalVal,
                lowStockCount: lowCount,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 21),
            tooltip: 'مشاركة التقرير',
            onPressed: () async {
              final prov = Provider.of<InventoryProvider>(context, listen: false);
              final totalVal = prov.localItems.fold<double>(0.0, (s, i) => s + (i.currentStock * i.unitPrice));
              final lowCount = prov.localItems.where((i) => i.currentStock <= 15).length;
              await ShareService.shareStockReportPdf(
                items: prov.localItems,
                totalValuation: totalVal,
                lowStockCount: lowCount,
              );
            },
          ),
           IconButton(
            icon: const Icon(Icons.manage_accounts_rounded, size: 22, color: AppColors.primary),
            tooltip: 'إدارة وإنشاء حسابات الموظفين',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserManagementScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 21),
            tooltip: 'خيارات المستودع',
            onSelected: (val) async {
              if (val == 'manage_users') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserManagementScreen()),
                );
                return;
              }
              final prov = Provider.of<InventoryProvider>(context, listen: false);
              if (val == 'seed_30') {
                await prov.seedRealisticTestData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.success,
                      content: Text('تم تهيئة دليل المنتجات (32 صنفاً بمخزون أولي صفري)'),
                    ),
                  );
                }
              } else if (val == 'clear_all') {
                await prov.clearAllDataAndReset();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: AppColors.warning,
                      content: Text('تم تفريغ كافة بيانات المستودع بنجاح'),
                    ),
                  );
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'manage_users',
                child: Row(
                  children: [
                    Icon(Icons.person_add_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('إدارة وإنشاء حسابات الموظفين'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'seed_30',
                child: Row(
                  children: [
                    Icon(Icons.inventory_2_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('تهيئة دليل الأصناف (32 صنفاً - كمية صفرية)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded, size: 18, color: AppColors.error),
                    SizedBox(width: 8),
                    Text('تفريغ المستودع بالكامل'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, child) {
          final pendingCount = provider.transfers.where((t) => t.status == 'pending_audit').length;
          final localItemsCount = provider.localItems.length;
          final lowStockItems = provider.localItems.where((i) => i.currentStock <= 15.0).toList();
          final lowStockCount = lowStockItems.length;
          final totalValuation = provider.localItems.fold<double>(0.0, (sum, i) => sum + (i.currentStock * i.unitPrice));
          final availabilityRatio = localItemsCount == 0 ? 0.0 : ((localItemsCount - lowStockCount) / localItemsCount);

          return RefreshIndicator(
            onRefresh: () async {
              await provider.loadTransfers();
              await provider.loadLocalItems();
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                // 1. Warehouse Context Strip
                _buildWarehouseContextCard(context, isDark),
                const SizedBox(height: 14),

                // 2. Benaa Intelligence AI Section
                const DashboardAiWidget(),
                const SizedBox(height: 14),

                // 3. High-Impact KPI Grid (2x2)
                Row(
                  children: [
                    Expanded(
                      child: KpiCard(
                        title: 'أصناف المستودع',
                        value: '$localItemsCount صنف',
                        badgeText: localItemsCount > 0 ? 'محدّث تلقائياً' : null,
                        icon: Icons.inventory_2_outlined,
                        accentColor: AppColors.primary,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const LocalStockScreen()),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: KpiCard(
                        title: 'بضائع في الطريق',
                        value: '$pendingCount شحنة',
                        badgeText: pendingCount > 0 ? 'بانتظار الاستلام' : 'تم استلام الكل',
                        icon: Icons.local_shipping_outlined,
                        accentColor: AppColors.warning,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TransfersListScreen()),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: KpiCard(
                        title: 'القيمة الإجمالية للبضاعة',
                        value: '${totalValuation.toStringAsFixed(0)} ر.س',
                        badgeText: 'رصيد المستودع',
                        icon: Icons.account_balance_wallet_outlined,
                        accentColor: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: KpiCard(
                        title: 'أصناف قاربت على الانتهاء',
                        value: '$lowStockCount صنف',
                        badgeText: lowStockCount > 0 ? 'تحتاج طلب وشراء' : 'المخزون آمن',
                        icon: Icons.warning_amber_rounded,
                        accentColor: AppColors.error,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LocalStockScreen(showLowStockOnly: true),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                // 3. Operational Stock Health Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Column(
                    children: [
                      Wrap(alignment: WrapAlignment.spaceBetween, spacing: 8, runSpacing: 8,
                        children: [
                          Wrap(children: [ const Icon(Icons.speed_rounded, size: 18, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                'معدل توفر الأصناف بالمستودع',
                                style: AppTypography.cardTitle(
                                  color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                ).copyWith(fontSize: 13.5),
                              ),
                            ],
                          ),
                          Text(
                            '${(availabilityRatio * 100).toStringAsFixed(0)}%',
                            style: AppTypography.tabularNumber(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: availabilityRatio >= 0.8
                                  ? AppColors.success
                                  : (availabilityRatio >= 0.5 ? AppColors.warning : AppColors.error),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: availabilityRatio,
                          minHeight: 6,
                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            availabilityRatio >= 0.8
                                ? AppColors.success
                                : (availabilityRatio >= 0.5 ? AppColors.warning : AppColors.error),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 4. Prioritized Primary Operational Actions
                const SectionHeader(title: 'ماذا تريد أن تفعل اليوم؟ (العمليات السريعة)'),
                _buildPrimaryActionCard(
                  context,
                  title: 'استلام بضاعة جديدة دخلت المستودع',
                  subtitle: 'فحص ومطابقة الكميات التي وصلت وإضافتها لرصيد المستودع فوراً',
                  badgeText: 'بضاعة واردة',
                  icon: Icons.move_to_inbox_rounded,
                  color: AppColors.primary,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TransfersListScreen()),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _buildPrimaryActionCard(
                  context,
                  title: 'صرف بضاعة وخروجها (بيع / تسليم)',
                  subtitle: 'تسليم مواد للعميل بفواتير المبيعات',
                  badgeText: 'تسليم لعميل',
                  icon: Icons.outbox_rounded,
                  color: AppColors.success,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SalesIssuanceScreen()),
                    );
                  },
                ),
                const SizedBox(height: 10),

                // Secondary Action Buttons (Side by Side)
                Row(
                  children: [
                    _buildSecondaryActionCard(
                      context,
                      label: 'نقل بضاعة لفرع آخر',
                      icon: Icons.local_shipping_rounded,
                      color: AppColors.primary,
                      onTap: () async {
                        final transferId = await showDialog<String>(
                          context: context,
                          builder: (ctx) => const CreateTransferDialog(),
                        );
                        if (transferId != null && transferId.isNotEmpty && mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TransferAuditDetailScreen(transferId: transferId),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    _buildSecondaryActionCard(
                      context,
                      label: 'جرد البضاعة بالباركود',
                      icon: Icons.qr_code_scanner_rounded,
                      color: AppColors.warning,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const StockAuditScreen()),
                        );
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // 5. Operational Tools Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Wrap(alignment: WrapAlignment.spaceAround, spacing: 8, runSpacing: 8,
                    children: [
                      _buildInlineTool(context, label: 'المشاريع وصرف المواد', icon: Icons.construction,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsScreen()))),
                      _buildInlineTool(
                        context,
                        label: 'طباعة الباركود',
                        icon: Icons.qr_code_2_rounded,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => BarcodePrintPickerDialog(items: provider.localItems),
                          );
                        },
                      ),
                      Container(width: 1, height: 26, color: borderColor),
                      _buildInlineTool(
                        context,
                        label: 'محول الوحدات',
                        icon: Icons.swap_horiz_rounded,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => PackagingUnitConverterDialog(items: provider.localItems),
                          );
                        },
                      ),
                      Container(width: 1, height: 26, color: borderColor),
                      _buildInlineTool(
                        context,
                        label: 'مواضع الأرفف',
                        icon: Icons.grid_view_rounded,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => WarehouseLocationDialog(items: provider.localItems),
                          );
                        },
                      ),
                      Container(width: 1, height: 26, color: borderColor),
                      _buildInlineTool(
                        context,
                        label: 'كشوف الحساب',
                        icon: Icons.receipt_long_rounded,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => const CustomerStatementDialog(),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // 6. Recent Activity Section (Transfers / Shipments)
                SectionHeader(
                  title: 'أحدث سندات التحويل والشحنات',
                  count: provider.transfers.length,
                  actionLabel: 'عرض الكل',
                  onAction: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TransfersListScreen()),
                    );
                  },
                ),

                if (provider.transfers.isEmpty)
                  EnterpriseEmptyState(
                    icon: Icons.local_shipping_outlined,
                    title: 'لا توجد شحنات أو سندات تحويل حالية',
                    message: 'يمكنك إنشاء سند تحويل جديد بين المستودعات للبدء في تتبع الشحنات',
                    actionLabel: 'إنشاء سند تحويل جديد',
                    onAction: () async {
                      final transferId = await showDialog<String>(
                        context: context,
                        builder: (ctx) => const CreateTransferDialog(),
                      );
                      if (transferId != null && transferId.isNotEmpty && mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TransferAuditDetailScreen(transferId: transferId),
                          ),
                        );
                      }
                    },
                  )
                else
                  ...provider.transfers.take(4).map((transfer) {
                    Widget statusBadge;
                    if (transfer.status == 'audited_matched') {
                      statusBadge = StockBadge.matched();
                    } else if (transfer.status == 'audited_discrepancy') {
                      statusBadge = StockBadge.discrepancy();
                    } else {
                      statusBadge = StockBadge.pending();
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor, width: 1.1),
                        boxShadow: isDark
                            ? []
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TransferAuditDetailScreen(transferId: transfer.id),
                              ),
                            );
                          },
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? AppColors.borderDark : const Color(0xFFBFDBFE),
                                width: 0.8,
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.local_shipping_outlined, size: 20, color: AppColors.primary),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'سند #${transfer.transferNumber}',
                                  style: AppTypography.cardTitle(
                                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                  ).copyWith(fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              statusBadge,
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 3),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${transfer.fromWarehouse} ← ${transfer.toWarehouse}',
                                    style: AppTypography.secondary(
                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '(${transfer.items.length} صنف)',
                                  style: AppTypography.smallLabel(
                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInlineTool(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isDark ? AppColors.primaryLight : AppColors.primary,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.smallLabel(
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
              ).copyWith(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
