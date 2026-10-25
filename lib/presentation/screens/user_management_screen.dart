import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/services/cloud_auth_service.dart';
import '../../core/services/haptics_service.dart';
import '../widgets/enterprise/enterprise_button.dart';
import '../widgets/enterprise/enterprise_dialog.dart';
import '../widgets/enterprise/stock_badge.dart';
import '../widgets/enterprise/section_header.dart';

/// Super Admin Company Staff & Multi-Warehouse Employee Management Screen
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({Key? key}) : super(key: key);

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<CompanyUser> _users = [];
  List<BenaaWarehouseInfo> _warehouses = [];
  bool _isLoading = false;
  String _roleFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final whList = await CloudAuthService.fetchWarehouses();
    final users = await CloudAuthService.fetchCompanyUsers();
    if (mounted) {
      setState(() {
        _warehouses = whList;
        _users = users;
        _isLoading = false;
      });
    }
  }

  void _showCreateWarehouseDialog(BuildContext context) {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final addressController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => EnterpriseDialog(
        title: 'إضافة فرع / مستودع جديد',
        icon: Icons.add_business_rounded,
        confirmLabel: 'حفظ واعتماد المستودع',
        onConfirm: () async {
          final name = nameController.text.trim();
          final code = codeController.text.trim();
          final address = addressController.text.trim();

          if (name.isEmpty || code.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: AppColors.error,
                content: Text('يرجى إدخال اسم المستودع ورمزه التعريفي (Code)'),
              ),
            );
            return;
          }

          await CloudAuthService.provisionNewWarehouse(
            name: name,
            code: code,
            address: address.isNotEmpty ? address : null,
          );

          await HapticsService.actionSuccess();

          if (ctx.mounted) {
            Navigator.pop(ctx);
            _loadData();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.success,
                content: Text('تمت إضافة فرع ($name) بنجاح وأصبح متاحاً لتعيين المشرفين والأمناء.'),
              ),
            );
          }
        },
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'إضافة مستودع أو فرع جديد لمنظومة شركة بناء للديكور وتخصيص إدارته للمشرفين والموظفين.',
                style: AppTypography.secondary(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المستودع (مثال: مستودع بريدة الرئيسي)',
                  prefixIcon: Icon(Icons.warehouse_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(
                  labelText: 'رمز المستودع (مثال: BRD-WH أو QAS-01)',
                  prefixIcon: Icon(Icons.qr_code_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'المدينة / العنوان (مثال: القصيم - بريدة)',
                  prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateUserDialog(BuildContext context) {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    CompanyUserRole selectedRole = CompanyUserRole.storekeeper;
    String? selectedWarehouseId = _warehouses.isNotEmpty ? _warehouses.first.id : null;
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 365));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => EnterpriseDialog(
          title: 'إنشاء حساب موظف واشتراك جديد',
          icon: Icons.person_add_alt_1_rounded,
          confirmLabel: 'تأكيد وحفظ الموظف',
          onConfirm: () async {
            final name = nameController.text.trim();
            final email = emailController.text.trim();
            final username = usernameController.text.trim();
            final password = passwordController.text.trim();

            if (name.isEmpty || email.isEmpty || username.isEmpty || password.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.error,
                  content: Text('يرجى ملء كافة الحقول الأساسية لإنشاء الحساب'),
                ),
              );
              return;
            }

            final defaultWhId = selectedWarehouseId ?? (_warehouses.isNotEmpty ? _warehouses.first.id : '6a7f78f2e720fc52f142e03e');
            final success = await CloudAuthService.provisionNewUser(
              name: name,
              email: email,
              username: username,
              password: password,
              role: selectedRole,
              primaryWarehouseId: defaultWhId,
              subscriptionStartDate: startDate.toIso8601String().substring(0, 10),
              subscriptionEndDate: endDate.toIso8601String().substring(0, 10),
            );

            await HapticsService.actionSuccess();

            if (ctx.mounted) {
              Navigator.pop(ctx);
              _loadData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.success,
                  content: Text('تم إنشاء حساب ($name) وتعيينه بالمستودع بنجاح'),
                ),
              );
            }
          },
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'لوحة السوبر أدمن: إضافة موظف جديد لشركة بناء وربطه بمستودعه واشتراكه',
                  style: AppTypography.secondary(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل للموظف',
                    prefixIcon: Icon(Icons.badge_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني للعمل',
                    prefixIcon: Icon(Icons.email_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'اسم الدخول (Username)',
                    prefixIcon: Icon(Icons.account_circle_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الأولية',
                    prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                Text('الدور الوظيفي والصلاحيات:', style: AppTypography.smallLabel(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                DropdownButtonFormField<CompanyUserRole>(
                  value: selectedRole,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    CompanyUserRole.storekeeper,
                    CompanyUserRole.warehouseSupervisor,
                    CompanyUserRole.salesRep,
                  ].map((role) {
                    return DropdownMenuItem<CompanyUserRole>(
                      value: role,
                      child: Text(role.arabicLabel, style: AppTypography.body()),
                    );
                  }).toList(),
                  onChanged: (newRole) {
                    if (newRole != null) setDialogState(() => selectedRole = newRole);
                  },
                ),
                const SizedBox(height: 12),
                Text('المستودع الرئيسي المعين:', style: AppTypography.smallLabel(color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  value: selectedWarehouseId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _warehouses.map((wh) {
                    return DropdownMenuItem<String>(
                      value: wh.id,
                      child: Text('${wh.name} (${wh.code})', style: AppTypography.body()),
                    );
                  }).toList(),
                  onChanged: (newWh) {
                    if (newWh != null) setDialogState(() => selectedWarehouseId = newWh);
                  },
                ),
                const SizedBox(height: 12),
                Text('فترة الاشتراك:', style: AppTypography.smallLabel(color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.date_range, size: 16),
                        label: Text(
                          'من: ${startDate.toIso8601String().substring(0, 10)}',
                          style: AppTypography.smallLabel(),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setDialogState(() => startDate = picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event_available, size: 16),
                        label: Text(
                          'إلى: ${endDate.toIso8601String().substring(0, 10)}',
                          style: AppTypography.smallLabel(),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate,
                            firstDate: DateTime(2025),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setDialogState(() => endDate = picked);
                        },
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
  }

  void _showReassignDialog(BuildContext context, CompanyUser user) {
    String? targetWarehouseId = user.primaryWarehouseId ?? (_warehouses.isNotEmpty ? _warehouses.first.id : null);
    bool revokeOldAccess = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => EnterpriseDialog(
          title: 'نقل موظف إلى مستودع آخر',
          icon: Icons.transfer_within_a_station_rounded,
          confirmLabel: 'تأكيد النقل وتحديث الصلاحيات',
          onConfirm: () async {
            if (targetWarehouseId == null) return;

            final success = await CloudAuthService.reassignEmployeeWarehouse(
              employeeId: user.id,
              newPrimaryWarehouseId: targetWarehouseId!,
              additionalWarehouseIds: revokeOldAccess ? [] : user.warehouseIds,
            );

            await HapticsService.actionSuccess();

            if (ctx.mounted) {
              Navigator.pop(ctx);
              _loadData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.success,
                  content: Text(
                    'تم نقل الموظف (${user.name}) بنجاح مع الحفاظ على السجلات التاريخية السابقة.',
                  ),
                ),
              );
            }
          },
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'الموظف: ${user.name}',
                      style: AppTypography.cardTitle(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'المستودع الحالي: ${user.primaryWarehouseName ?? "غير محدد"}',
                      style: AppTypography.secondary(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'اختر المستودع الجديد:',
                style: AppTypography.smallLabel(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: targetWarehouseId,
                isExpanded: true,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                items: _warehouses.map((wh) {
                  return DropdownMenuItem<String>(
                    value: wh.id,
                    child: Text('${wh.name} (${wh.code})', style: AppTypography.body()),
                  );
                }).toList(),
                onChanged: (newWh) {
                  if (newWh != null) setDialogState(() => targetWarehouseId = newWh);
                },
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'إلغاء صلاحية المستودع القديم فورياً',
                  style: AppTypography.body(),
                ),
                subtitle: Text(
                  'يحافظ على السجلات والعمليات التاريخية السابقة دون حذف',
                  style: AppTypography.smallLabel(color: AppColors.textSecondary),
                ),
                value: revokeOldAccess,
                onChanged: (val) {
                  setDialogState(() => revokeOldAccess = val);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : AppColors.surface;
    final borderColor = isDark ? AppColors.borderDark : AppColors.border;

    final filteredUsers = _users.where((u) {
      if (_roleFilter == 'ALL') return true;
      return u.role.toUpperCase() == _roleFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المشتركين والمستودعات (Super Admin)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            tooltip: 'تحديث الحسابات من MongoDB',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              children: [
                // 1. Super Admin Role Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.corporate_fare_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'شركة بناء — نظام المستودعات المتعددة المركزي',
                                  style: AppTypography.cardTitle(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'السوبر أدمن: ${CloudAuthService.currentUser?.name ?? "خالد"} (khaled@admin.com)',
                                  style: AppTypography.smallLabel(color: AppColors.success),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: EnterpriseButton.primary(
                              label: 'إنشاء حساب موظف / مشرف',
                              icon: Icons.person_add_rounded,
                              onPressed: () => _showCreateUserDialog(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: EnterpriseButton.secondary(
                              label: '+ إضافة مستودع جديد',
                              icon: Icons.add_business_rounded,
                              onPressed: () => _showCreateWarehouseDialog(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 2. Warehouses Overview Quick Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryStat('المستودعات النشطة', '${_warehouses.length} فروع', Icons.warehouse_rounded),
                          _buildSummaryStat('إجمالي الموظفين', '${_users.length} موظف', Icons.people_outline_rounded),
                          _buildSummaryStat('حالة النظام', 'مركزي 100%', Icons.cloud_done_rounded),
                        ],
                      ),
                      if (_warehouses.isNotEmpty) ...[
                        const Divider(height: 20),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _warehouses.map((wh) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black26 : Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: borderColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.location_city_rounded, size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  '${wh.name} (${wh.code})',
                                  style: AppTypography.smallLabel(),
                                ),
                              ],
                            ),
                          )).toList(),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // 3. Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('ALL', 'الكل (${_users.length})'),
                      const SizedBox(width: 6),
                      _buildFilterChip('SUPER_ADMIN', 'سوبر أدمن'),
                      const SizedBox(width: 6),
                      _buildFilterChip('WAREHOUSE_SUPERVISOR', 'مشرفو المستودعات'),
                      const SizedBox(width: 6),
                      _buildFilterChip('STOREKEEPER', 'أمناء المستودعات'),
                      const SizedBox(width: 6),
                      _buildFilterChip('SALES_REP', 'مندوبو المبيعات'),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // 4. Users List Header
                SectionHeader(
                  title: 'الموظفون والمشتركون المصرح لهم',
                  count: filteredUsers.length,
                ),

                ...filteredUsers.map((user) {
                  final isSuper = user.role.toUpperCase() == 'SUPER_ADMIN' || user.role == 'admin';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: isSuper
                                    ? AppColors.primary.withOpacity(0.12)
                                    : AppColors.surfaceMuted,
                                child: Icon(
                                  isSuper ? Icons.shield_rounded : Icons.person_outline_rounded,
                                  color: isSuper ? AppColors.primary : AppColors.textSecondary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.name,
                                      style: AppTypography.cardTitle(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${user.email} • @${user.username}',
                                      style: AppTypography.secondary(color: AppColors.textSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              StockBadge(
                                label: _getRoleLabel(user.role),
                                backgroundColor: isSuper
                                    ? AppColors.primaryLight.withOpacity(0.15)
                                    : AppColors.surfaceMuted,
                                textColor: isSuper ? AppColors.primaryLight : AppColors.textSecondary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Divider(height: 1),
                          const SizedBox(height: 8),

                          // Warehouse & Subscription Status Row
                          Row(
                            children: [
                              // Warehouse pill
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.warehouse_outlined, size: 14, color: AppColors.primary),
                                    const SizedBox(width: 4),
                                    Text(
                                      user.primaryWarehouseName ?? 'جميع المستودعات',
                                      style: AppTypography.smallLabel(color: AppColors.primary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Subscription Active Status
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: user.isSubscriptionActive
                                      ? AppColors.success.withOpacity(0.1)
                                      : AppColors.error.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      user.isSubscriptionActive ? Icons.check_circle_outline : Icons.cancel_outlined,
                                      size: 13,
                                      color: user.isSubscriptionActive ? AppColors.success : AppColors.error,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      user.isSubscriptionActive ? 'اشتراك نشط' : 'اشتراك منتهي',
                                      style: AppTypography.smallLabel(
                                        color: user.isSubscriptionActive ? AppColors.success : AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const Spacer(),

                              // Action: Reassign Warehouse
                              if (!isSuper)
                                TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                                  label: Text(
                                    'نقل لمستودع آخر',
                                    style: AppTypography.smallLabel(color: AppColors.primary),
                                  ),
                                  onPressed: () => _showReassignDialog(context, user),
                                ),
                            ],
                          ),
                          if (user.subscriptionEndDate != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'فترة الاشتراك: من ${user.subscriptionStartDate != null && user.subscriptionStartDate!.length >= 10 ? user.subscriptionStartDate!.substring(0, 10) : (user.subscriptionStartDate ?? "البداية")} إلى ${user.subscriptionEndDate != null && user.subscriptionEndDate!.length >= 10 ? user.subscriptionEndDate!.substring(0, 10) : user.subscriptionEndDate}',
                              style: AppTypography.smallLabel(color: AppColors.textMuted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(height: 4),
        Text(value, style: AppTypography.tabularNumber(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: AppTypography.smallLabel(color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _roleFilter == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _roleFilter = key);
      },
      selectedColor: AppColors.primary.withOpacity(0.2),
      labelStyle: AppTypography.smallLabel(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role.toUpperCase()) {
      case 'SUPER_ADMIN':
      case 'ADMIN':
        return 'سوبر أدمن';
      case 'WAREHOUSE_SUPERVISOR':
      case 'WAREHOUSE_MANAGER':
        return 'مشرف مستودع';
      case 'STOREKEEPER':
      case 'WAREHOUSE_STAFF':
        return 'أمين مستودع';
      case 'SALES_REP':
      case 'SALES':
        return 'مندوب مبيعات';
      default:
        return role;
    }
  }
}
