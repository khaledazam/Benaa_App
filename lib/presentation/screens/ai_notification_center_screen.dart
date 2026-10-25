import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/benaa_ai_service.dart';
import 'local_stock_screen.dart';
import 'transfers_list_screen.dart';
import 'sales_issuance_screen.dart';
import 'stock_audit_screen.dart';
import '../widgets/customer_statement_dialog.dart';
import '../widgets/enterprise/enterprise_empty_state.dart';

/// Benaa AI Notification & Intelligence Center
/// Features:
/// - Real-time NaraRouter (nemotron-3.5-lightning-free) insights
/// - Category filtering (Inventory, Sales, Financial)
/// - Severity indicators (High, Medium, Low)
/// - Offline caching & distinct offline mode banner
/// - Deep-link navigation to operational warehouse records
class AiNotificationCenterScreen extends StatefulWidget {
  const AiNotificationCenterScreen({Key? key}) : super(key: key);

  @override
  State<AiNotificationCenterScreen> createState() => _AiNotificationCenterScreenState();
}

class _AiNotificationCenterScreenState extends State<AiNotificationCenterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedSeverity = 'all'; // all, high, medium, low

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToRoute(BuildContext context, BenaaAiInsight insight) {
    BenaaAiService().markAsRead(insight.id);
    final route = insight.actionRoute.toLowerCase();

    if (route.contains('inventory') || route.contains('stock')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LocalStockScreen(showLowStockOnly: true),
        ),
      );
    } else if (route.contains('transfer') || route.contains('audit') || route.contains('discrepancy')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const TransfersListScreen(),
        ),
      );
    } else if (route.contains('sales') || route.contains('issuance')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SalesIssuanceScreen(),
        ),
      );
    } else if (route.contains('customer') || route.contains('financial') || route.contains('statement')) {
      showDialog(
        context: context,
        builder: (_) => const CustomerStatementDialog(),
      );
    } else {
      // Default to stock screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LocalStockScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A) : AppColors.background;

    return ListenableBuilder(
      listenable: BenaaAiService(),
      builder: (context, _) {
        final ai = BenaaAiService();
        final unreadCount = ai.unreadCount;

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology_rounded, size: 22, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'مركز تنبيهات ذكاء بناء',
                      style: AppTypography.screenTitle(
                        color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                      ).copyWith(fontSize: 18),
                    ),
                  ],
                ),
                Text(
                  ai.isOffline
                      ? 'وضع عدم الاتصال — تحليلات محلية مؤقتة'
                      : 'NaraRouter AI • nemotron-3.5-lightning-free',
                  style: AppTypography.caption(
                    color: ai.isOffline ? AppColors.warning : AppColors.primary,
                  ).copyWith(fontSize: 11),
                ),
              ],
            ),
            actions: [
              if (unreadCount > 0)
                TextButton.icon(
                  onPressed: () => ai.markAllAsRead(),
                  icon: const Icon(Icons.done_all_rounded, size: 18, color: AppColors.primary),
                  label: Text(
                    'قراءة الكل',
                    style: AppTypography.button(color: AppColors.primary).copyWith(fontSize: 12),
                  ),
                ),
              IconButton(
                icon: ai.isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : const Icon(Icons.refresh_rounded, size: 22),
                tooltip: 'تحليل فوري جديد',
                onPressed: ai.isLoading ? null : () => ai.fetchInsights(forceRefresh: true),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : AppColors.textMuted,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: AppTypography.cardTitle().copyWith(fontSize: 13, fontWeight: FontWeight.w700),
                  tabs: [
                    Tab(
                      text: unreadCount > 0 ? 'الكل ($unreadCount)' : 'الكل',
                    ),
                    const Tab(text: 'المخزون'),
                    const Tab(text: 'المبيعات'),
                    const Tab(text: 'المالية'),
                  ],
                ),
              ),
            ),
          ),
          body: Column(
            children: [
              // 1. Connection / Offline Status Header Banner
              _buildStatusHeader(context, ai, isDark),

              // 2. Severity Quick Filter Chips
              _buildSeverityFilterRow(context, isDark),

              // 3. Tab Views with Insights
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildInsightsList(context, ai.insights, isDark),
                    _buildInsightsList(
                      context,
                      ai.insights.where((i) => i.category == AiCategory.inventory).toList(),
                      isDark,
                    ),
                    _buildInsightsList(
                      context,
                      ai.insights.where((i) => i.category == AiCategory.sales).toList(),
                      isDark,
                    ),
                    _buildInsightsList(
                      context,
                      ai.insights.where((i) => i.category == AiCategory.financial).toList(),
                      isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusHeader(BuildContext context, BenaaAiService ai, bool isDark) {
    final isOffline = ai.isOffline;
    final bgColor = isOffline
        ? (isDark ? const Color(0xFF451A03) : const Color(0xFFFFFBEB))
        : (isDark ? const Color(0xFF0F2338) : const Color(0xFFF0FDF4));
    final borderColor = isOffline
        ? (isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A))
        : (isDark ? const Color(0xFF166534) : const Color(0xFFBBF7D0));
    final textColor = isOffline
        ? (isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E))
        : (isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Row(
        children: [
          Icon(
            isOffline ? Icons.cloud_off_rounded : Icons.check_circle_rounded,
            size: 16,
            color: textColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isOffline
                  ? 'يتم عرض تحليلات مخزنة محلياً. اضغط تحديث للمزامنة السحابية.'
                  : 'تحليلات ذكية محدثة مباشرة من MongoDB Atlas عبر NaraRouter.',
              style: AppTypography.caption(color: textColor).copyWith(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            ai.lastAnalysisTime,
            style: AppTypography.caption(color: textColor.withOpacity(0.8)).copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityFilterRow(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF1E293B).withOpacity(0.5) : Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildSeverityChip('all', 'جميع التنبيهات', Icons.list_rounded, isDark),
            const SizedBox(width: 8),
            _buildSeverityChip('high', 'تنبيهات حرجة', Icons.error_outline_rounded, isDark, color: AppColors.error),
            const SizedBox(width: 8),
            _buildSeverityChip('medium', 'تنبيهات متوسطة', Icons.warning_amber_rounded, isDark, color: AppColors.warning),
            const SizedBox(width: 8),
            _buildSeverityChip('low', 'فرص ونمو', Icons.lightbulb_outline_rounded, isDark, color: AppColors.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildSeverityChip(String key, String label, IconData icon, bool isDark, {Color? color}) {
    final isSelected = _selectedSeverity == key;
    final chipColor = color ?? AppColors.primary;

    return ChoiceChip(
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedSeverity = key);
      },
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? Colors.white : (color ?? (isDark ? Colors.white70 : AppColors.textSecondary)),
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : (isDark ? Colors.white70 : AppColors.textPrimary),
        ),
      ),
      selectedColor: chipColor,
      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
      side: BorderSide(
        color: isSelected ? chipColor : (isDark ? AppColors.borderDark : const Color(0xFFE2E8F0)),
        width: 1,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _buildInsightsList(BuildContext context, List<BenaaAiInsight> items, bool isDark) {
    // Apply severity filter
    List<BenaaAiInsight> filtered = items;
    if (_selectedSeverity == 'high') {
      filtered = items.where((i) => i.severity == AiSeverity.high).toList();
    } else if (_selectedSeverity == 'medium') {
      filtered = items.where((i) => i.severity == AiSeverity.medium).toList();
    } else if (_selectedSeverity == 'low') {
      filtered = items.where((i) => i.severity == AiSeverity.low).toList();
    }

    if (filtered.isEmpty) {
      return Center(
        child: EnterpriseEmptyState(
          icon: Icons.check_circle_outline_rounded,
          title: 'لا توجد تنبيهات ذكية حالياً',
          message: 'جميع مؤشرات المستودع والمبيعات والتحصيل ضمن المعدلات التشغيلية المثلى.',
          actionLabel: 'تحليل فوري للبيانات',
          onAction: () => BenaaAiService().fetchInsights(forceRefresh: true),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: filtered.length,
      itemBuilder: (ctx, index) {
        final insight = filtered[index];
        return _buildInsightCard(context, insight, isDark);
      },
    );
  }

  Widget _buildInsightCard(BuildContext context, BenaaAiInsight insight, bool isDark) {
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? AppColors.borderDark : const Color(0xFFE2E8F0);

    Color severityColor;
    String severityLabel;
    IconData categoryIcon;
    String categoryLabel;

    switch (insight.severity) {
      case AiSeverity.high:
        severityColor = AppColors.error;
        severityLabel = 'حرج وعاجل';
        break;
      case AiSeverity.medium:
        severityColor = AppColors.warning;
        severityLabel = 'متوسط الأولوية';
        break;
      case AiSeverity.low:
        severityColor = AppColors.primary;
        severityLabel = 'فرصة وملاحظة';
        break;
    }

    switch (insight.category) {
      case AiCategory.inventory:
        categoryIcon = Icons.inventory_2_rounded;
        categoryLabel = 'ذكاء المخزون';
        break;
      case AiCategory.sales:
        categoryIcon = Icons.trending_up_rounded;
        categoryLabel = 'ذكاء المبيعات';
        break;
      case AiCategory.financial:
        categoryIcon = Icons.account_balance_wallet_rounded;
        categoryLabel = 'التحصيل والمالية';
        break;
    }

    return Dismissible(
      key: Key(insight.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'استبعاد التنبيه',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: Colors.white),
          ],
        ),
      ),
      onDismissed: (_) {
        BenaaAiService().dismissInsight(insight.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم استبعاد التنبيه بنجاح'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: insight.isRead ? borderColor : severityColor.withOpacity(0.4),
            width: insight.isRead ? 1.0 : 1.5,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(insight.isRead ? 0.02 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Right accent bar (RTL side)
                Container(
                  width: 5,
                  color: severityColor,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header row with category pill, severity badge, and unread dot
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(categoryIcon, size: 13, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    categoryLabel,
                                    style: AppTypography.caption(
                                      color: isDark ? const Color(0xFFCBD5E1) : AppColors.textPrimary,
                                    ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: severityColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                severityLabel,
                                style: AppTypography.caption(color: severityColor).copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (!insight.isRead)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 6),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_horiz_rounded, size: 18),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onSelected: (val) {
                                if (val == 'read') {
                                  BenaaAiService().markAsRead(insight.id);
                                } else if (val == 'dismiss') {
                                  BenaaAiService().dismissInsight(insight.id);
                                }
                              },
                              itemBuilder: (ctx) => [
                                PopupMenuItem(
                                  value: 'read',
                                  child: Row(
                                    children: [
                                      Icon(
                                        insight.isRead ? Icons.mark_email_unread_outlined : Icons.done_rounded,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(insight.isRead ? 'تحديد كغير مقروء' : 'تحديد كمقروء'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'dismiss',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.error),
                                      SizedBox(width: 8),
                                      Text('استبعاد التنبيه', style: TextStyle(color: AppColors.error)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // Title
                        Text(
                          insight.title,
                          style: AppTypography.cardTitle(
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          ).copyWith(fontSize: 14.5, fontWeight: FontWeight.w700),
                        ),

                        const SizedBox(height: 6),

                        // Description
                        Text(
                          insight.description,
                          style: AppTypography.body(
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          ).copyWith(fontSize: 13, height: 1.45),
                        ),

                        // Metrics Chips (if any)
                        if (insight.metrics.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: insight.metrics.entries.take(3).map((e) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark ? AppColors.borderDark : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Text(
                                  '${_metricKeyToLabel(e.key)}: ${e.value}',
                                  style: AppTypography.caption(
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                  ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                              );
                            }).toList(),
                          ),
                        ],

                        const SizedBox(height: 12),
                        const Divider(height: 1, thickness: 0.8),
                        const SizedBox(height: 8),

                        // Recommended Action Button
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  backgroundColor: severityColor.withOpacity(0.08),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  alignment: Alignment.centerRight,
                                ),
                                onPressed: () => _navigateToRoute(context, insight),
                                icon: Icon(Icons.arrow_forward_rounded, size: 16, color: severityColor),
                                label: Text(
                                  insight.recommendedAction,
                                  style: AppTypography.button(color: severityColor).copyWith(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _metricKeyToLabel(String key) {
    switch (key) {
      case 'currentStock':
        return 'المخزون الحالي';
      case 'burnRatePerDay':
        return 'الاستهلاك اليومي';
      case 'daysRemaining':
        return 'أيام النفاذ';
      case 'reorderQty':
        return 'كمية الشراء';
      case 'overdueBalance':
        return 'الرصيد المستحق';
      case 'varianceRate':
        return 'نسبة الفارق';
      default:
        return key;
    }
  }
}
