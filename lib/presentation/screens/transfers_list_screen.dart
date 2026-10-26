import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../providers/inventory_provider.dart';
import 'transfer_audit_detail_screen.dart';
import '../widgets/create_transfer_dialog.dart';
import '../../core/services/benaa_warehouse_service.dart';
import '../../core/services/cloud_auth_service.dart';
import '../../core/services/haptics_service.dart';
import '../widgets/enterprise/stock_badge.dart';
import '../widgets/enterprise/enterprise_button.dart';
import '../widgets/enterprise/enterprise_dialog.dart';
import '../widgets/enterprise/enterprise_empty_state.dart';

/// Professional Enterprise Multi-Warehouse Transfers & Lifecycle Screen
class TransfersListScreen extends StatefulWidget {
  const TransfersListScreen({Key? key}) : super(key: key);

  @override
  State<TransfersListScreen> createState() => _TransfersListScreenState();
}

class _TransfersListScreenState extends State<TransfersListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<LifecycleTransfer> _lifecycleTransfers = [];
  bool _isLoadingLifecycle = false;
  String _lifecycleFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<InventoryProvider>(context, listen: false).loadTransfers();
      _loadLifecycleTransfers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLifecycleTransfers() async {
    setState(() => _isLoadingLifecycle = true);
    final list = await BenaaWarehouseService.fetchLifecycleTransfers();
    if (mounted) {
      setState(() {
        _lifecycleTransfers = list;
        _isLoadingLifecycle = false;
      });
    }
  }

  void _openCreateInvoiceDialog(BuildContext context) async {
    final transferId = await showDialog<String>(
      context: context,
      builder: (ctx) => const CreateTransferDialog(),
    );
    if (transferId != null && transferId.isNotEmpty && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => TransferAuditDetailScreen(transferId: transferId),
        ),
      );
    }
  }

  void _handleLifecycleAction(LifecycleTransfer transfer, String action) async {
    final user = CloudAuthService.currentUser;

    if (action == 'APPROVE') {
      final confirm = await EnterpriseDialog.showConfirmation(
        context: context,
        title: 'اعتماد طلب التحويل وحجز المخزون',
        message: 'هل تؤكد اعتماد التحويل رقم (${transfer.transferNumber})؟ سيتم حجز كمية (${transfer.requestedQuantity.toInt()}) فورياً من رصيد مستودع (${transfer.fromWarehouseName}) لمنع ازدواجية الصرف.',
        confirmLabel: 'تأكيد الاعتماد والحجز',
        icon: Icons.check_circle_outline,
      );
      if (confirm != true) return;
    } else if (action == 'DISPATCH') {
      final confirm = await EnterpriseDialog.showConfirmation(
        context: context,
        title: 'إرسال الشحنة وخصم المخزون',
        message: 'سيتم خصم كمية (${transfer.requestedQuantity.toInt()}) نهائياً من مستودع (${transfer.fromWarehouseName}) وتحويل الشحنة إلى قيد النقل.',
        confirmLabel: 'تأكيد الإرسال والخصم',
        icon: Icons.local_shipping_outlined,
      );
      if (confirm != true) return;
    } else if (action == 'RECEIVE') {
      final qtyController = TextEditingController(text: transfer.requestedQuantity.toInt().toString());
      final notesController = TextEditingController();

      final res = await showDialog<bool>(
        context: context,
        builder: (ctx) => EnterpriseDialog(
          title: 'استلام وفحص الشحنة بالمستودع',
          icon: Icons.inventory_outlined,
          confirmLabel: 'تأكيد الاستلام وإضافة الرصيد',
          onConfirm: () async {
            final recQty = double.tryParse(qtyController.text) ?? transfer.requestedQuantity;
            final isPartial = recQty != transfer.requestedQuantity;

            final apiRes = await BenaaWarehouseService.executeLifecycleAction(
              transferId: transfer.id,
              action: 'RECEIVE',
              receivedQuantity: recQty,
              discrepancyNotes: notesController.text.trim().isNotEmpty
                  ? notesController.text.trim()
                  : (isPartial ? 'استلام جزئي: $recQty من أصل ${transfer.requestedQuantity}' : null),
            );

            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(apiRes['message'].toString())));
            if (apiRes['success'] != true && apiRes['queued'] != true) return;
            if (apiRes['success'] == true) await HapticsService.actionSuccess();
            if (ctx.mounted) Navigator.pop(ctx, apiRes['success'] == true);
          },
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'المنتج: ${transfer.productName} (${transfer.productSku})',
                style: AppTypography.cardTitle(),
              ),
              const SizedBox(height: 4),
              Text(
                'الكمية المرسلة: ${transfer.requestedQuantity.toInt()} وحدة',
                style: AppTypography.secondary(color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'الكمية الفعلية المستلمة',
                  prefixIcon: Icon(Icons.check_box_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات الفحص / الفروقات إن وجدت',
                  prefixIcon: Icon(Icons.note_alt_outlined, size: 20),
                ),
              ),
            ],
          ),
        ),
      );
      if (res == true) {
        _loadLifecycleTransfers();
      }
      return;
    } else if (action == 'CANCEL') {
      final confirm = await EnterpriseDialog.showConfirmation(
        context: context,
        title: 'إلغاء طلب التحويل',
        message: 'هل أنت متأكد من إلغاء التحويل؟ سيتم فك حجز المخزون فورياً.',
        confirmLabel: 'إلغاء الطلب',
        isDestructive: true,
        icon: Icons.cancel_outlined,
      );
      if (confirm != true) return;
    }

    final res = await BenaaWarehouseService.executeLifecycleAction(
      transferId: transfer.id,
      action: action,
    );

    if (res['success'] == true) await HapticsService.actionSuccess();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.success,
          content: Text(res['message']?.toString() ?? 'تعذر اعتماد العملية'),
        ),
      );
      _loadLifecycleTransfers();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;

    return Scaffold(
      appBar: AppBar(
        title: const Text('شحنات البضائع بين المستودعات'),
        bottom: TabBar(
          isScrollable: true,
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.sync_alt_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text('الشحنات النشطة (${_lifecycleTransfers.length})'),
                ],
              ),
            ),
            const Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('سجل الشحنات السابقة'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            tooltip: 'تحديث البيانات',
            onPressed: () {
              _loadLifecycleTransfers();
              Provider.of<InventoryProvider>(context, listen: false).loadTransfers();
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: 6-Stage Multi-Warehouse Lifecycle
          _buildLifecycleTab(isDark, cardBg, borderColor),

          // Tab 2: Local Offline Transfers & Audit
          _buildLocalTransfersTab(isDark, cardBg, borderColor),
        ],
      ),
    );
  }

  Widget _buildLifecycleTab(bool isDark, Color cardBg, Color borderColor) {
    if (_isLoadingLifecycle) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    final filtered = _lifecycleTransfers.where((t) {
      if (_lifecycleFilter == 'ALL') return true;
      return t.status == _lifecycleFilter;
    }).toList();

    return Column(
      children: [
        // Status Filter Chips Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: borderColor, width: 1)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildStatusChip('ALL', 'الكل (${_lifecycleTransfers.length})'),
                const SizedBox(width: 6),
                _buildStatusChip('REQUESTED', 'مطلوب (REQUESTED)'),
                const SizedBox(width: 6),
                _buildStatusChip('APPROVED', 'معتمد (APPROVED)'),
                const SizedBox(width: 6),
                _buildStatusChip('DISPATCHED', 'تم الإرسال (DISPATCHED)'),
                const SizedBox(width: 6),
                _buildStatusChip('IN_TRANSIT', 'قيد النقل (IN_TRANSIT)'),
                const SizedBox(width: 6),
                _buildStatusChip('COMPLETED', 'مكتمل (COMPLETED)'),
              ],
            ),
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? EnterpriseEmptyState(
                  icon: Icons.swap_horiz_rounded,
                  title: 'لا توجد طلبات تحويل مخزني مطابقة',
                  message: 'يمكنك طلب تحويل مخزني عند نفاد رصيد أي صنف من شاشة الأصناف والمخزون',
                  actionLabel: 'تحديث القائمة',
                  onAction: _loadLifecycleTransfers,
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final t = filtered[idx];
                    return _buildLifecycleTransferCard(t, isDark, cardBg, borderColor);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLifecycleTransferCard(
    LifecycleTransfer t,
    bool isDark,
    Color cardBg,
    Color borderColor,
  ) {
    Color statusColor;
    switch (t.status) {
      case 'REQUESTED':
        statusColor = AppColors.warning;
        break;
      case 'APPROVED':
        statusColor = Colors.blue;
        break;
      case 'DISPATCHED':
      case 'IN_TRANSIT':
        statusColor = Colors.purple;
        break;
      case 'RECEIVED':
      case 'COMPLETED':
        statusColor = AppColors.success;
        break;
      case 'CANCELLED':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.textSecondary;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Row: Transfer Number & Status Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEDF2F7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#${t.transferNumber}',
                        style: AppTypography.smallLabel().copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      t.requestedAt?.substring(0, 10) ?? '',
                      style: AppTypography.smallLabel(color: AppColors.textMuted),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    t.arabicStatus,
                    style: AppTypography.smallLabel(color: statusColor).copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Product & Quantity
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.productName, style: AppTypography.cardTitle()),
                      const SizedBox(height: 2),
                      Text('كود: ${t.productSku}', style: AppTypography.smallLabel(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${t.requestedQuantity.toInt()} وحدة',
                      style: AppTypography.tabularNumber(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    if (t.receivedQuantity != null)
                      Text(
                        'المستلم: ${t.receivedQuantity!.toInt()}',
                        style: AppTypography.smallLabel(color: AppColors.success),
                      ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Source & Destination Warehouses
            Row(
              children: [
                const Icon(Icons.storefront_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('من: ${t.fromWarehouseName}', style: AppTypography.secondary()),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 10),
                const Icon(Icons.warehouse_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('إلى: ${t.toWarehouseName}', style: AppTypography.secondary()),
              ],
            ),

            // Audit History Mini Trail
            if (t.requestedBy != null || t.approvedBy != null || t.dispatchedBy != null || t.receivedBy != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'المسار: طلب: ${t.requestedBy ?? "-"} ← اعتماد: ${t.approvedBy ?? "-"} ← إرسال: ${t.dispatchedBy ?? "-"} ← استلام: ${t.receivedBy ?? "-"}',
                  style: AppTypography.smallLabel(color: AppColors.textMuted).copyWith(fontSize: 10.5),
                ),
              ),
            ],

            if (t.discrepancyNotes != null && t.discrepancyNotes!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'ملاحظات الفروقات: ${t.discrepancyNotes}',
                style: AppTypography.smallLabel(color: AppColors.warning),
              ),
            ],

            // Action Buttons by Lifecycle Stage
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (t.status == 'REQUESTED') ...[
                  OutlinedButton(
                    onPressed: () => _handleLifecycleAction(t, 'CANCEL'),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _handleLifecycleAction(t, 'APPROVE'),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('اعتماد وحجز الكمية'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ] else if (t.status == 'APPROVED') ...[
                  ElevatedButton.icon(
                    onPressed: () => _handleLifecycleAction(t, 'DISPATCH'),
                    icon: const Icon(Icons.local_shipping_outlined, size: 16),
                    label: const Text('إرسال الشحنة (خصم المخزون)'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  ),
                ] else if (t.status == 'DISPATCHED' || t.status == 'IN_TRANSIT') ...[
                  ElevatedButton.icon(
                    onPressed: () => _handleLifecycleAction(t, 'RECEIVE'),
                    icon: const Icon(Icons.inventory_outlined, size: 16),
                    label: const Text('استلام وفحص الشحنة بالمستودع'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                  ),
                ] else if (t.status == 'COMPLETED') ...[
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text('مكتمل ومرحّل بالأرصدة', style: AppTypography.smallLabel(color: AppColors.success)),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String key, String label) {
    final isSelected = _lifecycleFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _lifecycleFilter = key);
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      labelStyle: AppTypography.smallLabel(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
    );
  }

  Widget _buildLocalTransfersTab(bool isDark, Color cardBg, Color borderColor) {
    return Consumer<InventoryProvider>(
      builder: (context, provider, child) {
        final transfers = provider.transfers;

        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (transfers.isEmpty) {
          return EnterpriseEmptyState(
            icon: Icons.local_shipping_outlined,
            title: 'لا توجد سندات شحنات واردة محلية',
            message: 'يمكنك إنشاء سند تحويل جديد من هنا',
            actionLabel: 'إنشاء سند تحويل جديد',
            onAction: () => _openCreateInvoiceDialog(context),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          itemCount: transfers.length,
          itemBuilder: (ctx, idx) {
            final t = transfers[idx];
            Widget statusBadge;
            if (t.status == 'approved' || t.status == 'audited_matched') {
              statusBadge = StockBadge.matched(label: 'مستلم ومطابق');
            } else if (t.status == 'audited_discrepancy') {
              statusBadge = StockBadge.discrepancy(label: 'مكتمل بفارق');
            } else {
              statusBadge = StockBadge.pending(label: 'قيد التدقيق');
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: ListTile(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TransferAuditDetailScreen(transferId: t.id),
                    ),
                  );
                },
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('سند #${t.transferNumber}', style: AppTypography.cardTitle()),
                    statusBadge,
                  ],
                ),
                subtitle: Text('من: ${t.fromWarehouse} ← إلى: ${t.toWarehouse} • ${t.items.length} صنف'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              ),
            );
          },
        );
      },
    );
  }
}
