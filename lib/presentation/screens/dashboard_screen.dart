import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_responsive.dart';
import '../providers/inventory_provider.dart';
import 'transfers_list_screen.dart';
import 'transfer_audit_detail_screen.dart';
import 'stock_audit_screen.dart';
import 'local_stock_screen.dart';
import 'sales_issuance_screen.dart';
import 'sync_manager_screen.dart';
import 'returns_management_screen.dart';
import '../widgets/create_transfer_dialog.dart';
import '../../core/services/pdf_report_service.dart';
import '../../core/services/share_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/haptics_service.dart';
import '../widgets/inventory_chart_widget.dart';
import '../widgets/barcode_print_picker_dialog.dart';
import '../widgets/packaging_unit_converter_dialog.dart';
import '../widgets/warehouse_location_dialog.dart';
import '../widgets/customer_statement_dialog.dart';
import '../widgets/customer_payment_dialog.dart';
import '../widgets/absher_hawsu_dialog.dart';
import '../widgets/hawsu_loading_overlay.dart';
import '../../core/services/biometric_auth_service.dart';
import '../../core/services/app_update_service.dart';
import '../providers/theme_provider.dart';

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

      // Silent opportunistic background update check (Zero interruption)
      final updateInfo = await AppUpdateService.checkForUpdate();
      if (updateInfo != null && mounted) {
        AppUpdateService.showUpdateDialog(context, updateInfo);
      }
    });
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return Builder(
      builder: (context) {
        final iconSize = AppResponsive.iconSize(context, 30);
        final titleFontSize = AppResponsive.fontSize(context, 13);
        final valueFontSize = AppResponsive.fontSize(context, 19);

        return Card(
          elevation: 2,
          color: AppColors.getCardBg(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.getBorder(context)),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: color, size: iconSize),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: AppColors.getTextSecondary(context),
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            value,
                            style: TextStyle(
                              color: AppColors.getTextPrimary(context),
                              fontSize: valueFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Builder(
      builder: (context) {
        final iconSize = AppResponsive.iconSize(context, 26);
        final titleFontSize = AppResponsive.fontSize(context, 15);
        final subtitleFontSize = AppResponsive.fontSize(context, 12);

        return Card(
          color: AppColors.getCardBg(context),
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.getBorder(context)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: iconSize),
            ),
            title: Text(
              title,
              style: TextStyle(
                color: AppColors.getTextPrimary(context),
                fontWeight: FontWeight.bold,
                fontSize: titleFontSize,
              ),
              textAlign: TextAlign.right,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.getTextSecondary(context),
                  fontSize: subtitleFontSize,
                  height: 1.3,
                ),
                textAlign: TextAlign.right,
              ),
            ),
            trailing: Icon(
              Icons.arrow_forward_ios,
              color: AppColors.getTextSecondary(context),
              size: AppResponsive.iconSize(context, 18),
            ),
            onTap: () {
              HapticsService.lightImpact();
              onTap();
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBg(context),
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            'نظام الجرد والمخازن',
            style: TextStyle(fontSize: AppResponsive.fontSize(context, 16), fontWeight: FontWeight.bold),
          ),
        ),
        actions: [
          Consumer<ThemeProvider>(
            builder: (ctx, themeProv, _) => IconButton(
              icon: Icon(
                themeProv.isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round,
                color: AppColors.primaryAccent,
                size: AppResponsive.iconSize(context, 22),
              ),
              tooltip: 'المظهر',
              onPressed: () => themeProv.toggleTheme(),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Offline',
                  style: TextStyle(
                    color: AppColors.success,
                    fontSize: AppResponsive.fontSize(context, 10),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, child) {
          final pendingCount = provider.transfers.where((t) => t.status == 'pending_audit').length;
          final localItemsCount = provider.localItems.length;
          final lowStockItems = provider.localItems.where((i) => i.currentStock <= 15.0).toList();
          final lowStockCount = lowStockItems.length;
          final totalValuation = provider.localItems.fold<double>(0.0, (sum, i) => sum + (i.currentStock * 50.0));

          return SingleChildScrollView(
            padding: EdgeInsets.all(AppResponsive.space(context, 14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Supervisor Banner with Export & Quick Action Buttons (Responsive Wrap)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.bgSurface],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.borderDark),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 10,
                      spacing: 8,
                      children: [
                        ElevatedButton.icon(
                          icon: Icon(Icons.picture_as_pdf, size: AppResponsive.iconSize(context, 16)),
                          label: Text(
                            'PDF / Excel',
                            style: TextStyle(fontSize: AppResponsive.fontSize(context, 11), fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            minimumSize: const Size(80, 36),
                          ),
                          onPressed: () async {
                            await PdfReportService.printOrPreviewReport(
                              items: provider.localItems,
                              totalValuation: totalValuation,
                              lowStockCount: lowStockCount,
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.fingerprint, color: AppColors.primaryAccent, size: AppResponsive.iconSize(context, 24)),
                          tooltip: '🔐 التحقق بالبصمة',
                          onPressed: () async {
                            final success = await BiometricAuthService.authenticate(
                              reason: 'تأكيد بصمة الإصبع أو الوجه لتأمين الوصول للسيستم',
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  backgroundColor: success ? AppColors.success : AppColors.danger,
                                  content: Text(
                                    success
                                        ? '🟢 تم التحقق من بصمة الإصبع/الوجه بنجاح!'
                                        : '🔴 فشل التحقق من البصمة أو تم إلغاؤه',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_forever, color: Colors.redAccent, size: AppResponsive.iconSize(context, 22)),
                          tooltip: '🚨 تصفير قاعدة البيانات',
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: AppColors.getCardBg(context),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                title: const Text(
                                  '⚠️ تأكيد تصفير البيانات للبدء الفعلي',
                                  style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.right,
                                ),
                                content: const Text(
                                  'هل أنت متأكد من مسح جميع المنتجات التجريبية، الفواتير، المرتجعات، وحركات المخزن للبدء بنسخة نظيفة وخالية تماماً؟',
                                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
                                  textAlign: TextAlign.right,
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('إلغاء', style: TextStyle(color: AppColors.textSecondary)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                                    onPressed: () async {
                                      Navigator.pop(ctx);
                                      await Provider.of<InventoryProvider>(context, listen: false).clearAllDataAndReset();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            backgroundColor: AppColors.success,
                                            content: Text('تم مسح جميع البيانات والفواتير بنجاح! التطبيق الآن نظيف وجاهز للبدء الفعلي 🚀'),
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text('نعم، مسح وتصفير الكل'),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.share, color: Colors.white, size: AppResponsive.iconSize(context, 20)),
                          tooltip: 'مشاركة التقرير',
                          onPressed: () async {
                            await ShareService.shareStockReportPdf(
                              items: provider.localItems,
                              totalValuation: totalValuation,
                              lowStockCount: lowStockCount,
                            );
                          },
                        ),
                        InkWell(
                            onTap: () => AbsherHawsuDialog.show(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF005C36), Color(0xFF00A86B)],
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00A86B).withOpacity(0.4),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome, color: const Color(0xFFFFD700), size: AppResponsive.iconSize(context, 18)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'أبشر حوس ⚡',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: AppResponsive.fontSize(context, 14),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'مستودع الفرع: القصيم / بريدة',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: AppResponsive.fontSize(context, 11),
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

                const SizedBox(height: 16),

                // Statistics Grid (Responsive Column Layout)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 600;
                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'أصناف بريدة',
                                '$localItemsCount صنف',
                                Icons.inventory_2_outlined,
                                AppColors.info,
                                onTap: () => Navigator.push(
                                  context,
                                  HawsuPageRoute(page: const LocalStockScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatCard(
                                'تحويلات قادمة',
                                '$pendingCount فاتورة',
                                Icons.local_shipping_outlined,
                                AppColors.warning,
                                onTap: () => Navigator.push(
                                  context,
                                  HawsuPageRoute(page: const TransfersListScreen()),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                'قيمة المخزون',
                                '${totalValuation.toStringAsFixed(0)} ر.س',
                                Icons.monetization_on_outlined,
                                AppColors.success,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildStatCard(
                                'وشيك النفاذ ⚠️',
                                '$lowStockCount صنف',
                                Icons.warning_amber_outlined,
                                AppColors.danger,
                                onTap: () => Navigator.push(
                                  context,
                                  HawsuPageRoute(page: const LocalStockScreen(showLowStockOnly: true)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),

                // 📊 Interactive Inventory & Analytics Chart
                InventoryChartWidget(items: provider.localItems),

                const SizedBox(height: 20),

                Text(
                  'المهام والإجراءات الرئيسية',
                  style: TextStyle(
                    color: AppColors.getTextPrimary(context),
                    fontSize: AppResponsive.fontSize(context, 17),
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                // Action Cards List with Enriched Icons & Touch Targets
                _buildActionCard(
                  title: '🏷️ طباعة ملصقات الباركود (Thermal Label)',
                  subtitle: 'طباعة ستيكرات باركود الأصناف لطابعات الملصقات الحرارية',
                  icon: Icons.qr_code_2,
                  color: AppColors.info,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => BarcodePrintPickerDialog(items: provider.localItems),
                    );
                  },
                ),

                _buildActionCard(
                  title: '📦 حاسبة ومحول التعبئة والوحدات الكبرى',
                  subtitle: 'تحويل الكراتين والطبليات إلى حبات وأمتار قياسية على الفور',
                  icon: Icons.calculate_outlined,
                  color: AppColors.warning,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => PackagingUnitConverterDialog(items: provider.localItems),
                    );
                  },
                ),

                _buildActionCard(
                  title: '📍 خريطة مواضع الأرفف والممرات بالمستودع',
                  subtitle: 'تحديد ممر ورف وكابينة التخزين لكل صنف لسهولة السحب',
                  icon: Icons.place_outlined,
                  color: AppColors.info,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => WarehouseLocationDialog(items: provider.localItems),
                    );
                  },
                ),

                _buildActionCard(
                  title: '📜 كشوفات حساب العملاء التفصيلية',
                  subtitle: 'استخراج كشف حساب مالي تفصيلي بالمدين والدائن ومشاركته PDF / واتساب',
                  icon: Icons.receipt_long_outlined,
                  color: AppColors.primaryAccent,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => const CustomerStatementDialog(),
                    );
                  },
                ),

                _buildActionCard(
                  title: '💵 تسجيل سند قبض / سداد حساب عميل',
                  subtitle: 'تسجيل الدفعات المقبوضة نقداً أو تحويل بنكي وإصدار سند قبض PDF وتخفيض رصيده',
                  icon: Icons.payments_outlined,
                  color: AppColors.success,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => const CustomerPaymentDialog(),
                    );
                  },
                ),

                _buildActionCard(
                  title: 'جرد واستلام الفواتير الواردة',
                  subtitle: 'مطابقة الفواتير الواردة من جدة والرياض أو أي شحنة وإدخالها للمخزون',
                  icon: Icons.assignment_turned_in_outlined,
                  color: AppColors.primaryAccent,
                  onTap: () async {
                    if (provider.transfers.isEmpty) {
                      await provider.loadTransfers();
                    }
                    if (context.mounted) {
                      Navigator.push(
                        context,
                        HawsuPageRoute(page: const TransfersListScreen()),
                      );
                    }
                  },
                ),

                _buildActionCard(
                  title: '➕ إنشاء فاتورة / شحنة جديدة',
                  subtitle: 'إدخال فاتورة تحويل جديدة يدويًا وإضافة الأصناف بالمسح أو الكتابة',
                  icon: Icons.note_add_outlined,
                  color: AppColors.success,
                  onTap: () async {
                    final transferId = await showDialog<String>(
                      context: context,
                      builder: (ctx) => const CreateTransferDialog(),
                    );
                    if (transferId != null && transferId.isNotEmpty && context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (ctx) => TransferAuditDetailScreen(transferId: transferId),
                        ),
                      );
                    }
                  },
                ),

                _buildActionCard(
                  title: 'الجرد الدوري (عند الطلب)',
                  subtitle: 'إجراء جرد كلي أو جزئي لأصناف المستودع وتسجيل الفروقات',
                  icon: Icons.fact_check_outlined,
                  color: AppColors.warning,
                  onTap: () {
                    Navigator.push(
                      context,
                      HawsuPageRoute(page: const StockAuditScreen()),
                    );
                  },
                ),

                _buildActionCard(
                  title: 'إذن صرف / بيع للمحلات',
                  subtitle: 'توزيع الأصناف من مستودع بريدة للمحلات والعملاء وتحديث المخزون',
                  icon: Icons.point_of_sale_outlined,
                  color: AppColors.success,
                  onTap: () {
                    Navigator.push(
                      context,
                      HawsuPageRoute(page: const SalesIssuanceScreen()),
                    );
                  },
                ),

                _buildActionCard(
                  title: 'رصيد مستودع بريدة',
                  subtitle: 'عرض كافة الأصناف المتاحة والكميات الحالية بالمرتجعات والتسويات',
                  icon: Icons.warehouse_outlined,
                  color: AppColors.info,
                  onTap: () {
                    Navigator.push(
                      context,
                      HawsuPageRoute(page: const LocalStockScreen()),
                    );
                  },
                ),

                _buildActionCard(
                  title: 'إدارة المزامنة مع الـ CRM',
                  subtitle: 'متابعة حالة التخزين المحلي ورفع فواتير الجرد للسيرفر الرئيسي',
                  icon: Icons.cloud_sync_outlined,
                  color: AppColors.primaryAccent,
                  onTap: () {
                    Navigator.push(
                      context,
                      HawsuPageRoute(page: const SyncManagerScreen()),
                    );
                  },
                ),

                _buildActionCard(
                  title: '↩️ نظام المرتجعات الشامل (مبيعات وتوريد)',
                  subtitle: 'معالجة مرجعات المبيعات والتوريد وتحديث الرصيد وكشوفات الحسابات تلقائياً',
                  icon: Icons.assignment_return_outlined,
                  color: AppColors.danger,
                  onTap: () {
                    Navigator.push(
                      context,
                      HawsuPageRoute(page: const ReturnsManagementScreen()),
                    );
                  },
                ),

                const SizedBox(height: 24),

                // Recent Transfer Invoice Highlight
                if (provider.transfers.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            HawsuPageRoute(page: const TransfersListScreen()),
                          );
                        },
                        child: Text(
                          'عرض الكل',
                          style: TextStyle(
                            color: AppColors.primaryAccent,
                            fontSize: AppResponsive.fontSize(context, 14),
                          ),
                        ),
                      ),
                      Text(
                        'آخر فاتورة تحويل واردة',
                        style: TextStyle(
                          color: AppColors.getTextPrimary(context),
                          fontSize: AppResponsive.fontSize(context, 16),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Card(
                    color: AppColors.getCardBg(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.primaryAccent),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primaryAccent,
                        child: Icon(Icons.description, color: Colors.white, size: AppResponsive.iconSize(context, 22)),
                      ),
                      title: Text(
                        'تحويل اصناف رقم ${provider.transfers.first.transferNumber}',
                        style: TextStyle(
                          color: AppColors.getTextPrimary(context),
                          fontWeight: FontWeight.bold,
                          fontSize: AppResponsive.fontSize(context, 15),
                        ),
                        textAlign: TextAlign.right,
                      ),
                      subtitle: Text(
                        'من: ${provider.transfers.first.fromWarehouse} 👈 إلى: ${provider.transfers.first.toWarehouse}\nالكاتب: ${provider.transfers.first.author}',
                        style: TextStyle(
                          color: AppColors.getTextSecondary(context),
                          fontSize: AppResponsive.fontSize(context, 12),
                          height: 1.3,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          HawsuPageRoute(
                            page: TransferAuditDetailScreen(
                              transferId: provider.transfers.first.id,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'absher_fab',
            backgroundColor: const Color(0xFF00A86B),
            icon: Icon(Icons.auto_awesome, color: const Color(0xFFFFD700), size: AppResponsive.iconSize(context, 18)),
            label: Text(
              'أبشر حوس ⚡',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: AppResponsive.fontSize(context, 13),
              ),
            ),
            onPressed: () => AbsherHawsuDialog.show(context),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'camera_fab',
            backgroundColor: AppColors.primaryAccent,
            icon: Icon(Icons.qr_code_scanner, color: Colors.white, size: AppResponsive.iconSize(context, 20)),
            label: Text(
              'مسح ضوئي 📷',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: AppResponsive.fontSize(context, 13),
              ),
            ),
            onPressed: () {
              final provider = Provider.of<InventoryProvider>(context, listen: false);
              if (provider.transfers.isNotEmpty) {
                Navigator.push(
                  context,
                  HawsuPageRoute(
                    page: TransferAuditDetailScreen(
                      transferId: provider.transfers.first.id,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  HawsuPageRoute(page: const LocalStockScreen()),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
