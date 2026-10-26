import 'package:flutter/material.dart';
import '../../core/services/cloud_auth_service.dart';
import '../../core/services/local_scope_service.dart';
import '../../core/services/project_service.dart';

/// Project materials are server-authoritative quantity documents. This screen
/// never creates customer invoices/debt or calls the local stock engine.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});
  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  List<Map<String, dynamic>> _projects = [], _issues = [];
  bool _loading = true, _cached = false;
  String? _error;
  String? _projectId;
  bool get _admin => ['SUPER_ADMIN', 'ADMIN', 'admin'].contains(CloudAuthService.currentUser?.role);
  bool get _manager => _admin || ['WAREHOUSE_MANAGER', 'WAREHOUSE_SUPERVISOR', 'PROJECT_MANAGER'].contains(CloudAuthService.currentUser?.role);
  bool get _physical => _admin || ['STOREKEEPER', 'WAREHOUSE_MANAGER', 'WAREHOUSE_SUPERVISOR'].contains(CloudAuthService.currentUser?.role);
  @override
  void initState() { super.initState(); _reload(); }
  Future<void> _reload() async {
    setState(() { _loading = true; _error = null; });
    try {
      await CloudAuthService.refreshCurrentSession();
      _projects = await ProjectService.list('/api/projects', 'projects');
      final warehouse = Uri.encodeQueryComponent(LocalScopeService.warehouseId ?? '');
      _issues = await ProjectService.list('/api/projects/material-issues?warehouseId=$warehouse', 'issues');
      _cached = false;
    } catch (error) {
      _projects = await ProjectService.cached('projects');
      _issues = await ProjectService.cached('issues');
      _cached = true; _error = 'تعذر الاتصال؛ عرض آخر بيانات هذا الحساب والمستودع فقط';
    } finally { if (mounted) setState(() => _loading = false); }
  }
  void _message(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
  Future<void> _submit(Map<String, dynamic> payload) async {
    try {
      final result = await ProjectService.issue(payload);
      _message(result['message'].toString());
      await _reload();
    } catch (error) { _message('لم تعتمد العملية: $error'); }
  }
  Future<void> _createProject() async {
    final code = TextEditingController(), name = TextEditingController(), location = TextEditingController();
    final manager = TextEditingController();
    await showDialog<void>(context: context, builder: (ctx) => _ControllerOwner(controllers: [code, name, location, manager], child: AlertDialog(
      title: const Text('مشروع جديد'),
      content: SizedBox(width: 440, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: code, decoration: const InputDecoration(labelText: 'رمز المشروع')),
        TextField(controller: name, decoration: const InputDecoration(labelText: 'اسم المشروع')),
        TextField(controller: location, decoration: const InputDecoration(labelText: 'الموقع')),
        TextField(controller: manager, decoration: const InputDecoration(labelText: 'معرف مدير المشروع (اختياري)')),
        const Text('يرتبط المشروع بالمستودع الحالي؛ تحدد الصلاحيات على الخادم'),
      ]))),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(onPressed: () async {
          if (code.text.trim().isEmpty || name.text.trim().isEmpty || LocalScopeService.warehouseId == null) return;
          try {
            await ProjectService.createProject({'code': code.text.trim(), 'name': name.text.trim(),
              'location': location.text.trim(), 'status': 'ACTIVE',
              'warehouseIds': [LocalScopeService.warehouseId],
              if (manager.text.trim().isNotEmpty) 'assignedManagerId': manager.text.trim()});
            if (ctx.mounted) Navigator.pop(ctx);
            await _reload();
          } catch (error) { _message('لم يتم إنشاء المشروع: $error'); }
        }, child: const Text('إنشاء'))],
    )));
  }
  Future<void> _createIssue() async {
    List<Map<String, dynamic>> products;
    try { products = await ProjectService.list('/api/mobile-sync', 'items'); }
    catch (_) { _message('يلزم تحميل دليل المنتجات المعتمد قبل إنشاء الطلب'); return; }
    if (!mounted || _projects.isEmpty || products.isEmpty) { _message('يلزم مشروع نشط ومنتجات متاحة'); return; }
    String project = _projectId ?? _projects.first['id'].toString();
    String product = (products.first['productId'] ?? products.first['id']).toString();
    final quantity = TextEditingController(), recipient = TextEditingController(), notes = TextEditingController();
    final lines = <Map<String, dynamic>>[];
    await showDialog<void>(context: context, builder: (ctx) => _ControllerOwner(controllers: [quantity, recipient, notes], child: StatefulBuilder(builder: (ctx, update) => AlertDialog(
      title: const Text('طلب مواد للمشروع'),
      content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(initialValue: project, isExpanded: true,
          decoration: const InputDecoration(labelText: 'المشروع'),
          items: _projects.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text(p['name'].toString(), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (value) => update(() => project = value!)),
        DropdownButtonFormField<String>(initialValue: product, isExpanded: true,
          decoration: const InputDecoration(labelText: 'الصنف'),
          items: products.map((p) => DropdownMenuItem(value: (p['productId'] ?? p['id']).toString(), child: Text(p['name'].toString(), overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (value) => update(() => product = value!)),
        TextField(controller: quantity, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الكمية بالوحدة الأساسية')),
        TextButton(onPressed: () {
          final qty = double.tryParse(quantity.text);
          if (qty == null || !qty.isFinite || qty <= 0) return;
          update(() { lines.add({'productId': product, 'quantity': qty}); quantity.clear(); });
        }, child: const Text('إضافة بند')),
        ...lines.asMap().entries.map((entry) => ListTile(title: Text('${entry.value['productId']} — ${entry.value['quantity']}'),
          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => update(() => lines.removeAt(entry.key))))),
        TextField(controller: recipient, decoration: const InputDecoration(labelText: 'اسم المستلم')),
        TextField(controller: notes, decoration: const InputDecoration(labelText: 'ملاحظات')),
      ]))), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(onPressed: lines.isEmpty ? null : () async {
          Navigator.pop(ctx);
          await _submit({'action': 'CREATE', 'projectId': project, 'warehouseId': LocalScopeService.warehouseId,
            'items': lines, 'recipientName': recipient.text.trim(), 'notes': notes.text.trim()});
        }, child: const Text('حفظ طلب المواد'))],
    ))));
  }
  Future<void> _quantityAction(Map<String, dynamic> issue, String action) async {
    final lines = (issue['items'] as List? ?? []).map((entry) => Map<String, dynamic>.from(entry)).toList();
    final controllers = [for (final _ in lines) TextEditingController()];
    final reason = TextEditingController();
    await showDialog<void>(context: context, builder: (ctx) => _ControllerOwner(controllers: [...controllers, reason], child: AlertDialog(
      title: Text(action == 'RETURN' ? 'إرجاع مواد مرتبط بسند الصرف' : action == 'RELEASE' ? 'تحرير الكمية المحجوزة المتبقية' : 'صرف جزئي / كلي'),
      content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ...lines.asMap().entries.map((entry) => TextField(controller: controllers[entry.key],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: '${entry.value['productId']}', helperText:
            'مطلوب: ${entry.value['quantity']} — منصرف: ${entry.value['dispatchedQuantity']} — مرتجع: ${entry.value['returnedQuantity']}'))),
        TextField(controller: reason, decoration: const InputDecoration(labelText: 'السبب / ملاحظات الاستلام')),
      ]))), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
        FilledButton(onPressed: () async {
          final quantities = <Map<String, dynamic>>[];
          for (var i = 0; i < lines.length; i++) {
            final qty = double.tryParse(controllers[i].text);
            if (qty != null && qty.isFinite && qty > 0) quantities.add({'issueItemId': lines[i]['id'], 'quantity': qty});
          }
          if (quantities.isEmpty) return;
          Navigator.pop(ctx);
          await _submit({'action': action, 'issueId': issue['id'], 'quantities': quantities, 'reason': reason.text.trim()});
        }, child: const Text('إرسال للاعتماد'))],
    )));
  }
  List<String> _actions(String status) => [
    if (status == 'DRAFT') 'REQUEST',
    if (_manager && status == 'REQUESTED') ...['APPROVE', 'REJECT'],
    if (_physical && status == 'APPROVED') 'RESERVE',
    if (_physical && ['RESERVED', 'DISPATCHED'].contains(status)) 'DISPATCH',
    if (_manager && ['RESERVED', 'DISPATCHED'].contains(status)) 'RELEASE',
    if (_physical && ['DISPATCHED', 'COMPLETED'].contains(status)) 'RETURN',
    if (_manager && status == 'DISPATCHED') 'COMPLETE',
    if (_manager && ['DRAFT', 'REQUESTED', 'APPROVED', 'RESERVED'].contains(status)) 'CANCEL',
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المشاريع وصرف المواد'), actions: [IconButton(onPressed: _reload, icon: const Icon(Icons.refresh))]),
    body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _reload,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (_error != null) Text(_error!, style: const TextStyle(color: Colors.orange)),
        Wrap(spacing: 12, runSpacing: 8, children: [
          if (_manager) FilledButton.icon(onPressed: _cached ? null : _createProject, icon: const Icon(Icons.add_business), label: const Text('إنشاء مشروع')),
          FilledButton.icon(onPressed: _createIssue, icon: const Icon(Icons.add), label: const Text('طلب مواد')),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(value: _projectId, isExpanded: true,
          decoration: const InputDecoration(labelText: 'تصفية المشروع'),
          items: [const DropdownMenuItem<String>(value: null, child: Text('جميع المشاريع')),
            ..._projects.map((p) => DropdownMenuItem(value: p['id'].toString(), child: Text(p['name'].toString(), overflow: TextOverflow.ellipsis)))],
          onChanged: (value) => setState(() => _projectId = value)),
        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('تقرير الكميات: المطلوب / المحجوز / المنصرف / المرتجع / المتبقي')),
        ..._issues.where((issue) => _projectId == null || issue['projectId'] == _projectId).map((issue) => Card(child: Padding(
          padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${_projects.where((project) => project['id'] == issue['projectId']).firstOrNull?['name'] ?? issue['projectId']} — ${issue['issueNumber']} — ${issue['status']}', style: Theme.of(context).textTheme.titleMedium),
            ...((issue['items'] as List?) ?? []).map((line) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text('${line['product']?['name'] ?? line['productId']}: ${line['quantity']} / ${line['reservedQuantity']} / ${line['dispatchedQuantity']} / ${line['returnedQuantity']} / ${line['remainingQuantity']}'))),
            Wrap(spacing: 8, runSpacing: 8, children: _actions(issue['status'].toString()).map((action) => OutlinedButton(
              onPressed: () => ['DISPATCH', 'RETURN', 'RELEASE'].contains(action) ? _quantityAction(issue, action) :
                _submit({'action': action, 'issueId': issue['id']}), child: Text(action))).toList()),
          ])))),
        if (_issues.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Text('لا توجد طلبات مواد لهذا المستودع')),
      ])),
  );
}

class _ControllerOwner extends StatefulWidget {
  final List<TextEditingController> controllers;
  final Widget child;
  const _ControllerOwner({required this.controllers, required this.child});
  @override
  State<_ControllerOwner> createState() => _ControllerOwnerState();
}
class _ControllerOwnerState extends State<_ControllerOwner> {
  @override
  void dispose() { for (final controller in widget.controllers) { controller.dispose(); } super.dispose(); }
  @override
  Widget build(BuildContext context) => widget.child;
}
