import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../providers/inventory_provider.dart';
import '../../core/services/haptics_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/mongodb_sync_service.dart';
import '../../core/services/offline_outbox_service.dart';
import '../../core/services/cloud_auth_service.dart';
import '../widgets/enterprise/enterprise_button.dart';
import '../widgets/enterprise/section_header.dart';

/// Professional Enterprise MongoDB Atlas Sync Manager for Benaa ERP
class SyncManagerScreen extends StatefulWidget {
  const SyncManagerScreen({Key? key}) : super(key: key);

  @override
  State<SyncManagerScreen> createState() => _SyncManagerScreenState();
}

class _SyncManagerScreenState extends State<SyncManagerScreen> {
  bool _isSyncing = false;
  bool _isPinging = false;
  bool _isConnected = false;
  String _pingMessage = 'جارٍ التحقق من الاتصال';
  int _latencyMs = 0;
  Map<String, dynamic> _dbStats = {};

  final List<Map<String, String>> _syncLogs = [];

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    setState(() => _isPinging = true);
    final res = await MongoDbSyncService.checkConnection();
    if (mounted) {
      setState(() {
        _isPinging = false;
        _isConnected = res['connected'] ?? false;
        _latencyMs = res['latencyMs'] ?? 0;
        _dbStats = res['stats'] ?? {};
        _pingMessage = _isConnected
            ? 'متصل بنجاح مع MongoDB Atlas (زمن الاستجابة: ${_latencyMs}ms)'
            : 'تعذر الاتصال المباشر: ${res['error']}';
      });
    }
  }

  void _triggerMongoPush(InventoryProvider provider) async {
    setState(() => _isSyncing = true);
    try {
      await CloudAuthService.refreshCurrentSession();
      await OfflineOutboxService.instance.synchronize(endpoint: Uri.parse(MongoDbSyncService.apiBase),
        token: await CloudAuthService.sessionToken());
      final records = await OfflineOutboxService.instance.records();
      final pending = records.where((entry) => entry['state'] != 'applied').length;
      final conflicts = records.where((entry) => entry['state'] == 'conflict').length;
      if (mounted) {
        setState(() => _syncLogs.insert(0, {'time': DateTime.now().toString(),
          'title': 'عمليات المزامنة المحفوظة', 'status': 'معلقة: $pending — تعارضات للمراجعة: $conflicts'}));
        await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
          title: const Text('حالة العمليات'),
          content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
            children: records.map((row) => ListTile(
              title: Text(row['operationId'].toString()),
              subtitle: Text(row['state'].toString() + (row['error'] == null ? '' : '\n' + row['error'].toString())),
            )).toList()))),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
        ));
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally { if (mounted) setState(() => _isSyncing = false); }
  }

  void _triggerMongoPull(InventoryProvider provider) async {
    setState(() => _isSyncing = true);
    try {
      final items = await MongoDbSyncService.pullProductsFromMongo();
      if (mounted) await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('أرصدة الخادم المعتمدة'),
        content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
          children: items.map((item) => ListTile(title: Text(item['name']?.toString() ?? ''),
            subtitle: Text('الرصيد: ' + item['currentStock'].toString()))).toList()))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تحميل أرصدة الخادم: ' + error.toString())));
    } finally { if (mounted) setState(() => _isSyncing = false); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE2E8F0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة قاعدة بيانات MongoDB والمزامنة'),
        actions: [
          IconButton(
            icon: _isPinging
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.refresh_rounded, size: 21),
            tooltip: 'فحص الاتصال الحي',
            onPressed: _isPinging ? null : _checkConnection,
          ),
        ],
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, child) {
          final pendingTransfers = provider.transfers.where((t) => t.status == 'pending_audit').length;
          final totalItems = provider.localItems.length;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              // 1. Live MongoDB Atlas Connection Card
              Container(
                padding: const EdgeInsets.all(16),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(alignment: WrapAlignment.spaceBetween, spacing: 8, runSpacing: 8,
                      children: [
                        Wrap(children: [Container(width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.success.withOpacity(0.25),
                                  width: 1,
                                ),
                              ),
                              child: const Center(
                                child: Icon(Icons.cloud_done_rounded, color: AppColors.success, size: 22),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'MongoDB Atlas Cloud',
                                  style: AppTypography.cardTitle(
                                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                  ).copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  'قاعدة البيانات المركزية المعتمدة',
                                  style: AppTypography.smallLabel(
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _isConnected
                                ? AppColors.success.withOpacity(0.1)
                                : AppColors.warning.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isConnected
                                  ? AppColors.success.withOpacity(0.3)
                                  : AppColors.warning.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: _isConnected ? AppColors.success : AppColors.warning,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _isConnected ? 'متصل ومفعل' : 'وضع محلي',
                                style: AppTypography.smallLabel(
                                  color: _isConnected ? AppColors.success : AppColors.warning,
                                ).copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Connection Parameters Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor, width: 0.8),
                      ),
                      child: Column(
                        children: [
                          _buildConfigRow('اسم قاعدة البيانات:', MongoDbSyncService.databaseName, Icons.storage_rounded, isDark),
                          const Divider(height: 14),
                          _buildConfigRow('السيرفر العنقودي:', MongoDbSyncService.clusterHost, Icons.dns_rounded, isDark),
                          const Divider(height: 14),
                          _buildConfigRow('مستخدم قاعدة البيانات:', MongoDbSyncService.databaseUser, Icons.person_outline_rounded, isDark),
                          const Divider(height: 14),
                          _buildConfigRow('سلسلة الاتصال URI:', MongoDbSyncService.maskedConnectionUrl, Icons.link_rounded, isDark, isMonospace: true),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          _isConnected ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                          size: 15,
                          color: _isConnected ? AppColors.success : AppColors.warning,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _pingMessage,
                            style: AppTypography.smallLabel(
                              color: _isConnected
                                  ? AppColors.success
                                  : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 2. Synchronization Metrics Box
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('أصناف المستودع الجاهزة', style: AppTypography.secondary()),
                          const SizedBox(height: 4),
                          Text(
                            '$totalItems صنف',
                            style: AppTypography.tabularNumber(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text('مسجلة محلياً وفي السحابة', style: AppTypography.smallLabel(color: AppColors.success)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('سندات قيد التدقيق', style: AppTypography.secondary()),
                          const SizedBox(height: 4),
                          Text(
                            '$pendingTransfers سند',
                            style: AppTypography.tabularNumber(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: pendingTransfers > 0 ? AppColors.warning : AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pendingTransfers > 0 ? 'بانتظار المزامنة' : 'متزامنة بالكامل',
                            style: AppTypography.smallLabel(
                              color: pendingTransfers > 0 ? AppColors.warning : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 3. Primary Sync Actions
              EnterpriseButton(
                label: _isSyncing
                    ? 'جارٍ المزامنة والتسجيل في MongoDB...'
                    : 'مزامنة وتسجيل المخزون في MongoDB سحابياً',
                icon: Icons.cloud_upload_rounded,
                isLoading: _isSyncing,
                onPressed: _isSyncing ? null : () => _triggerMongoPush(provider),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isSyncing ? null : () => _triggerMongoPull(provider),
                icon: const Icon(Icons.cloud_download_rounded, size: 20),
                label: const Text('سحب وتحديث الأصناف من خادم MongoDB'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: BorderSide(color: isDark ? AppColors.borderDark : const Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),

              const SizedBox(height: 18),

              // 4. Live Sync Activity Audit Log
              SectionHeader(
                title: 'سجل المزامنة والعمليات السحابية',
                count: _syncLogs.length,
              ),

              ..._syncLogs.map((log) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.cloud_sync_rounded, color: AppColors.primary, size: 20),
                      ),
                    ),
                    title: Text(
                      log['title']!,
                      style: AppTypography.cardTitle(
                        color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                      ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          log['status']!,
                          style: AppTypography.secondary(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          ).copyWith(fontSize: 12.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          log['time']!,
                          style: AppTypography.smallLabel(
                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _buildConfigRow(String label, String value, IconData icon, bool isDark, {bool isMonospace = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 16),
      title: Text(label, style: AppTypography.smallLabel()),
      subtitle: Text(value, textDirection: TextDirection.ltr,
        style: AppTypography.body().copyWith(fontSize: 12.5,
          fontFamily: isMonospace ? 'monospace' : null)),
    );
  }
}