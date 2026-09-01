import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/haptics_service.dart';
import '../../core/services/pdf_report_service.dart';
import '../providers/inventory_provider.dart';
import '../screens/sales_issuance_screen.dart';
import '../screens/transfer_audit_detail_screen.dart';
import '../screens/returns_management_screen.dart';
import 'customer_statement_dialog.dart';
import 'customer_payment_dialog.dart';
import 'packaging_unit_converter_dialog.dart';
import 'invoice_ocr_scanner_dialog.dart';
import 'hawsu_loading_overlay.dart';

class AbsherHawsuDialog extends StatefulWidget {
  const AbsherHawsuDialog({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) async {
    await HapticsService.actionSuccess();
    if (!context.mounted) return;
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'أبشر حوس',
      barrierColor: Colors.black.withOpacity(0.65),
      transitionDuration: const Duration(milliseconds: 450),
      pageBuilder: (ctx, anim1, anim2) => const AbsherHawsuDialog(),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curvedAnim = CurvedAnimation(parent: anim1, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: Tween<double>(begin: 0.82, end: 1.0).animate(curvedAnim),
          child: FadeTransition(
            opacity: anim1,
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<AbsherHawsuDialog> createState() => _AbsherHawsuDialogState();
}

class _AbsherHawsuDialogState extends State<AbsherHawsuDialog> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  final TextEditingController _promptController = TextEditingController();
  String _filterQuery = '';

  final List<Map<String, dynamic>> _quickServices = [
    {
      'title': '🧾 إصدار فاتورة بيع جديدة',
      'subtitle': 'صرف أصناف المحلات والتعبئة التلقائية للأسعار',
      'icon': Icons.receipt_long,
      'color': const Color(0xFF00A86B),
      'action': 'sales',
    },
    {
      'title': '📦 جرد واستلام فواتير التوريد',
      'subtitle': 'مطابقة الأصناف الواردة وزيادة رصيد المستودع',
      'icon': Icons.inventory_2_outlined,
      'color': const Color(0xFF3B82F6),
      'action': 'transfer',
    },
    {
      'title': '📜 كشف حساب تفصيلي للعميل',
      'subtitle': 'عرض ديون العميل والحركات المسجلة والـ PDF',
      'icon': Icons.account_balance_wallet,
      'color': const Color(0xFF8B5CF6),
      'action': 'statement',
    },
    {
      'title': '💵 تسديد دفعة وحساب عميل',
      'subtitle': 'تسجيل سند قبض وحسم الفلوس وطباعة الإيصال',
      'icon': Icons.payments_outlined,
      'color': const Color(0xFF10B981),
      'action': 'payment',
    },
    {
      'title': '⚖️ حاسبة التعبئة والوحدات المتعددة',
      'subtitle': 'تحويل الكراتين والأطنان والمتر المربع آلياً',
      'icon': Icons.calculate_outlined,
      'color': const Color(0xFFF59E0B),
      'action': 'converter',
    },
    {
      'title': '↩️ نظام المرتجعات (مبيعات وتوريد)',
      'subtitle': 'معالجة مرتجع عميل أو مورد وتعديل المخزون آلياً',
      'icon': Icons.assignment_return_outlined,
      'color': const Color(0xFFDC2626),
      'action': 'returns',
    },
    {
      'title': '📸 مسح فاتورة ورقية بالذكاء الاصطناعي (AI OCR)',
      'subtitle': 'قراءة الفواتير وسندات التوريد الورقية وتفريغها بالمخزن تلقائياً',
      'icon': Icons.document_scanner,
      'color': const Color(0xFF9333EA),
      'action': 'ocr',
    },
    {
      'title': '🖨️ طباعة وتصدير جرد بريدة (PDF)',
      'subtitle': 'تصدير تقرير الجرد الشامل وقيمة المخزون',
      'icon': Icons.picture_as_pdf,
      'color': const Color(0xFFEF4444),
      'action': 'pdf',
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _executeService(String action) async {
    Navigator.pop(context);
    final provider = Provider.of<InventoryProvider>(context, listen: false);

    switch (action) {
      case 'sales':
        Navigator.push(
          context,
          HawsuPageRoute(page: const SalesIssuanceScreen()),
        );
        break;
      case 'transfer':
        if (provider.selectedTransfer != null) {
          Navigator.push(
            context,
            HawsuPageRoute(page: TransferAuditDetailScreen(transferId: provider.selectedTransfer!.id)),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('الرجاء اختيار شحنة واردة أولاً من القائمة')),
          );
        }
        break;
      case 'statement':
        showDialog(
          context: context,
          builder: (ctx) => const CustomerStatementDialog(),
        );
        break;
      case 'payment':
        showDialog(
          context: context,
          builder: (ctx) => const CustomerPaymentDialog(),
        );
        break;
      case 'converter':
        showDialog(
          context: context,
          builder: (ctx) => PackagingUnitConverterDialog(items: provider.localItems),
        );
        break;
      case 'returns':
        Navigator.push(
          context,
          HawsuPageRoute(page: const ReturnsManagementScreen()),
        );
        break;
      case 'ocr':
        showDialog(
          context: context,
          builder: (ctx) => const InvoiceOcrScannerDialog(),
        );
        break;
      case 'pdf':
        final lowStockCount = provider.localItems.where((i) => i.currentStock <= 15.0).length;
        final valuation = provider.localItems.fold<double>(0.0, (sum, i) => sum + (i.currentStock * i.unitPrice));
        await PdfReportService.printOrPreviewReport(
          items: provider.localItems,
          totalValuation: valuation,
          lowStockCount: lowStockCount,
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterQuery.isEmpty
        ? _quickServices
        : _quickServices
            .where((s) =>
                s['title'].toString().contains(_filterQuery) ||
                s['subtitle'].toString().contains(_filterQuery))
            .toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: AppColors.getCardBg(context),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFF00A86B).withOpacity(0.6), width: 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00A86B).withOpacity(0.35),
              blurRadius: 30,
              spreadRadius: 4,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Premium Animated Header Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF004D25), Color(0xFF00A86B), Color(0xFF005C36)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 24),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (ctx, child) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFD700).withOpacity(0.85 + (_pulseController.value * 0.15)),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      '✨ AI QUICK',
                                      style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  );
                                },
                              ),
                              const Text(
                                'أبشر حوس ⚡',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'المساعد الذكي لمستودع بريدة',
                            style: TextStyle(color: Colors.white70, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFFD700), width: 1.5),
                      ),
                      child: const Icon(Icons.auto_awesome, color: Color(0xFFFFD700), size: 20),
                    ),
                  ],
                ),
              ),

              // Interactive Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _promptController,
                  style: TextStyle(color: AppColors.getTextPrimary(context), fontSize: 13),
                  onChanged: (val) => setState(() => _filterQuery = val),
                  decoration: InputDecoration(
                    hintText: 'أبشر بالخير! اكتب الخدمة أو ابحث هنا (مثل: فاتورة، كشف حساب...)...',
                    hintStyle: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF00A86B)),
                    suffixIcon: _filterQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _promptController.clear();
                              setState(() => _filterQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.getBg(context),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF00A86B), width: 2),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppColors.getBorder(context)),
                    ),
                  ),
                ),
              ),

              // Services List
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shrinkWrap: true,
                  itemCount: filtered.length,
                  separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final s = filtered[idx];
                    final color = s['color'] as Color;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _executeService(s['action']),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.getBg(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: color.withOpacity(0.3), width: 1),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.arrow_back_ios_new, color: AppColors.getTextSecondary(context), size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      s['title'],
                                      style: TextStyle(
                                        color: AppColors.getTextPrimary(context),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      s['subtitle'],
                                      style: TextStyle(
                                        color: AppColors.getTextSecondary(context),
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(s['icon'], color: color, size: 22),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Banner
              Container(
                padding: const EdgeInsets.all(12),
                color: AppColors.getBg(context),
                child: Center(
                  child: Text(
                    'نظام Benaa المطور | جميع الأوامر تفتح بلمسة واحدة ⚡',
                    style: TextStyle(color: AppColors.getTextSecondary(context), fontSize: 11, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
