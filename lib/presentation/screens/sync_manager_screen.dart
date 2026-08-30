import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../providers/inventory_provider.dart';
import '../../core/services/haptics_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/services/share_service.dart';
import '../../core/services/app_update_service.dart';

class SyncManagerScreen extends StatefulWidget {
  const SyncManagerScreen({Key? key}) : super(key: key);

  @override
  State<SyncManagerScreen> createState() => _SyncManagerScreenState();
}

class _SyncManagerScreenState extends State<SyncManagerScreen> {
  bool _isSyncing = false;
  List<Map<String, String>> _syncLogs = [
    {
      'time': '2026-08-21 16:30',
      'title': 'حفظ محلي (Offline)',
      'status': 'سند تحويل رقم 23 مخزن محلياً',
    },
    {
      'time': '2026-08-21 17:00',
      'title': 'جاهز للمزامنة',
      'status': '16 بند بانتظار الاتصال بالسيرفر الرئيسي',
    },
  ];

  void _startSyncSimulation() async {
    setState(() => _isSyncing = true);

    await Future.delayed(const Duration(seconds: 2));

    await HapticsService.actionSuccess();
    await NotificationService.showSyncNotification(
      title: '🚀 تمت مزامنة المخزن مع الـ CRM بنجاح',
      body: 'تم رفع كافة السجلات وإعادة تحديث الأصناف والحركات بين الموبايل والسيرفر.',
    );

    setState(() {
      _isSyncing = false;
      _syncLogs.insert(0, {
        'time': DateTime.now().toString().substring(0, 16),
        'title': 'تمت المزامنة بنجاح 🚀',
        'status': 'تم رفع جميع السجلات وتحديث الـ CRM بنجاح',
      });
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('تمت مزامنة جميع فواتير وتحديثات المخزن مع سيستم الـ CRM الرئيسي بنجاح!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDark,
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text('إدارة مزامنة البيانات (Sync)'),
        ),
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, child) {
          final pendingTransfers = provider.transfers.where((t) => t.status != 'pending_audit').length;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Network / Local DB Status Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderDark),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'متصل وقابل للمزامنة',
                          style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('حالة قاعدة البيانات', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          SizedBox(height: 2),
                          Text('SQLite Local Database', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Sync Stats Grid
                Card(
                  color: AppColors.bgCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.primaryAccent),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              const Text('سجلات غير مرفوعة', style: TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
                              const SizedBox(height: 4),
                              Text('$pendingTransfers عملية', style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                        Container(height: 30, width: 1, color: AppColors.borderDark),
                        const Expanded(
                          child: Column(
                            children: [
                              Text('آخر مزامنة ناجحة', style: TextStyle(color: AppColors.textSecondary, fontSize: 12), textAlign: TextAlign.center),
                              SizedBox(height: 4),
                              Text('منذ 15 دقيقة', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Start Sync Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.sync),
                    label: Text(_isSyncing ? 'جاري المزامنة مع الـ CRM...' : 'بدء المزامنة الفورية مع سيستم الـ CRM'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryAccent,
                    ),
                    onPressed: _isSyncing ? null : _startSyncSimulation,
                  ),
                ),

                const SizedBox(height: 12),

                // Export Database Backup Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download_for_offline_outlined, color: Colors.white),
                    label: const Text('💾 تصدير وحفظ نسخة احتياطية من قاعدة البيانات (.db)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                    ),
                    onPressed: () async {
                      final success = await ShareService.exportDatabaseBackup();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: success ? AppColors.success : AppColors.warning,
                            content: Text(
                              success
                                  ? 'تم تجهيز وتصدير نسخة قاعدة البيانات بنجاح! يمكنك حفظها في التنزيلات أو إرسالها.'
                                  : 'تعذر تصدير قاعدة البيانات (ربما تعمل على الويب أو الذاكرة المؤقتة).',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Check for Updates Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.system_update_alt_outlined, color: AppColors.primaryAccent),
                    label: const Text('🔄 فحص وجود تحديثات جديدة للنظام (Auto-Update Check)', style: TextStyle(color: AppColors.primaryAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primaryAccent, width: 1.5),
                    ),
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('جاري فحص خادم التحديثات...')),
                      );
                      final update = await AppUpdateService.checkForUpdate();
                      if (!mounted) return;
                      if (update != null) {
                        AppUpdateService.showUpdateDialog(context, update);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.success,
                            content: Text('أنت تستخدم أحدث إصدار من نظام Benaa حالياً (v1.0.0) 🚀'),
                          ),
                        );
                      }
                    },
                  ),
                ),

                const SizedBox(height: 12),

                // Reset DB Button for Production
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.delete_forever, color: AppColors.danger),
                    label: const Text('🚨 تصفير قاعدة البيانات ومسح كل الفواتير للبدء الفعلي (نظيف 100%)', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold, fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger, width: 1.5),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: AppColors.getCardBg(context),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: const Text('⚠️ تأكيد تصفير البيانات للبدء الفعلي', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
                          content: const Text(
                            'هل أنت أصلح متأكد من مسح جميع المنتجات التجريبية، الفواتير، المرتجعات، وحركات المخزن للبدء بنسخة نظيفة وخالية تماماً؟',
                            style: TextStyle(color: AppColors.textPrimary, fontSize: 13),
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
                ),

                const SizedBox(height: 24),

                const Text(
                  'سجل عمليات المزامنة الأخيرة (Sync Audit Log)',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                ),

                const SizedBox(height: 10),

                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _syncLogs.length,
                  itemBuilder: (ctx, idx) {
                    final log = _syncLogs[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: AppColors.bgCard,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.borderDark),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.cloud_done_outlined, color: AppColors.success),
                        title: Text(log['title']!, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.right),
                        subtitle: Text('${log['status']!}\n${log['time']!}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11), textAlign: TextAlign.right),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
