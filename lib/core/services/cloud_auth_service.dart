import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

/// Canonical Roles inside BENAA Single-Company Ecosystem
enum CompanyUserRole {
  superAdmin,
  warehouseSupervisor,
  storekeeper,
  salesRep,
}

extension CompanyUserRoleExtension on CompanyUserRole {
  String get roleKey {
    switch (this) {
      case CompanyUserRole.superAdmin:
        return 'SUPER_ADMIN';
      case CompanyUserRole.warehouseSupervisor:
        return 'WAREHOUSE_SUPERVISOR';
      case CompanyUserRole.storekeeper:
        return 'STOREKEEPER';
      case CompanyUserRole.salesRep:
        return 'SALES_REP';
    }
  }

  String get arabicLabel {
    switch (this) {
      case CompanyUserRole.superAdmin:
        return 'سوبر أدمن (المدير العام)';
      case CompanyUserRole.warehouseSupervisor:
        return 'مشرف مستودع (اعتمادات ورقابة)';
      case CompanyUserRole.storekeeper:
        return 'أمين مستودع (صرف واستلام وجرد)';
      case CompanyUserRole.salesRep:
        return 'مندوب مبيعات (تسليمات وطلبات)';
    }
  }

  static CompanyUserRole fromString(String role) {
    final r = role.toUpperCase();
    if (r.contains('SUPER') || r == 'ADMIN') return CompanyUserRole.superAdmin;
    if (r.contains('SUPERVISOR') || r.contains('MANAGER')) return CompanyUserRole.warehouseSupervisor;
    if (r.contains('SALES')) return CompanyUserRole.salesRep;
    return CompanyUserRole.storekeeper;
  }
}

class BenaaWarehouseInfo {
  final String id;
  final String name;
  final String code;
  final String? address;

  BenaaWarehouseInfo({
    required this.id,
    required this.name,
    required this.code,
    this.address,
  });

  factory BenaaWarehouseInfo.fromJson(Map<String, dynamic> json) {
    return BenaaWarehouseInfo(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'مستودع بناء',
      code: json['code']?.toString() ?? 'WH',
      address: json['address']?.toString() ?? json['location']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'code': code,
    if (address != null) 'address': address,
  };
}

class CompanyUser {
  final String id;
  final String name;
  final String email;
  final String username;
  final String role;
  final bool isActive;
  final bool isSubscriptionActive;
  final String? subscriptionStartDate;
  final String? subscriptionEndDate;
  final String? primaryWarehouseId;
  final String primaryWarehouseName;
  final String? primaryWarehouseCode;
  final List<String> warehouseIds;
  final List<String> permissions;
  final String createdAt;

  CompanyUser({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.role,
    this.isActive = true,
    this.isSubscriptionActive = true,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.primaryWarehouseId,
    this.primaryWarehouseName = 'المستودع الرئيسي',
    this.primaryWarehouseCode,
    this.warehouseIds = const [],
    this.permissions = const [],
    required this.createdAt,
  });

  factory CompanyUser.fromJson(Map<String, dynamic> json) {
    final wIds = (json['warehouseIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final perms = (json['permissions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    return CompanyUser(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      role: json['role']?.toString() ?? 'STOREKEEPER',
      isActive: json['status'] == true || json['isActive'] == true || json['active'] == true,
      isSubscriptionActive: json['isSubscriptionActive'] ?? true,
      subscriptionStartDate: json['subscriptionStartDate']?.toString(),
      subscriptionEndDate: json['subscriptionEndDate']?.toString(),
      primaryWarehouseId: json['primaryWarehouseId']?.toString(),
      primaryWarehouseName: json['primaryWarehouseName']?.toString() ?? 'مستودع مواد البناء والديكور الرئيسي',
      primaryWarehouseCode: json['primaryWarehouseCode']?.toString() ?? 'MAIN-WH',
      warehouseIds: wIds,
      permissions: perms,
      createdAt: json['createdAt']?.toString() ?? DateTime.now().toIso8601String().split('T').first,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'username': username,
      'role': role,
      'status': isActive,
      'isSubscriptionActive': isSubscriptionActive,
      'subscriptionStartDate': subscriptionStartDate,
      'subscriptionEndDate': subscriptionEndDate,
      'primaryWarehouseId': primaryWarehouseId,
      'primaryWarehouseName': primaryWarehouseName,
      'primaryWarehouseCode': primaryWarehouseCode,
      'warehouseIds': warehouseIds,
      'permissions': permissions,
      'createdAt': createdAt,
    };
  }
}

/// Cloud Authentication & Super Admin User Provisioning Service (MongoDB / Next.js API)
class CloudAuthService {
  static const List<String> _apiBases = [
    'http://localhost:3002',
    'http://localhost:3000',
  ];

  static const String _spUserKey = 'benaa_current_user_json';
  static const String _spUsersListKey = 'benaa_cached_company_users';
  static const String _spWarehousesKey = 'benaa_cached_warehouses_list';

  static CompanyUser? _currentUser;
  static List<CompanyUser> _cachedUsers = [];
  static List<BenaaWarehouseInfo> _cachedWarehouses = [];

  static CompanyUser? get currentUser => _currentUser;
  static List<BenaaWarehouseInfo> get cachedWarehouses => _cachedWarehouses;
  static bool get isSuperAdmin => _currentUser?.role == 'SUPER_ADMIN' || _currentUser?.role == 'admin';
  static bool get isLoggedIn => _currentUser != null;

  /// Initialize service and load cached session
  static Future<void> initialize() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final userStr = sp.getString(_spUserKey);
      if (userStr != null) {
        _currentUser = CompanyUser.fromJson(jsonDecode(userStr));
      } else {
        _currentUser = null; // Clean security: requires login
      }

      final listStr = sp.getString(_spUsersListKey);
      if (listStr != null) {
        final List<dynamic> list = jsonDecode(listStr);
        _cachedUsers = list.map((e) => CompanyUser.fromJson(e)).toList();
      } else {
        _seedInitialCompanyUsers();
      }

      final whStr = sp.getString(_spWarehousesKey);
      if (whStr != null) {
        final List<dynamic> list = jsonDecode(whStr);
        _cachedWarehouses = list.map((e) => BenaaWarehouseInfo.fromJson(e)).toList();
      } else {
        _seedInitialWarehouses();
      }

      // Silent fresh background fetch
      fetchCompanyUsers();
      fetchWarehouses();
    } catch (_) {
      _seedInitialCompanyUsers();
      _seedInitialWarehouses();
    }
  }

  static void _seedInitialWarehouses() {
    _cachedWarehouses = [
      BenaaWarehouseInfo(
        id: '6a7f78f2e720fc52f142e03e',
        name: 'مستودع مواد البناء والديكور الرئيسي (MAIN-WH)',
        code: 'MAIN-WH',
      ),
      BenaaWarehouseInfo(
        id: '6a7f78f2e720fc52f142e03f',
        name: 'مستودع الديكور والتشطيبات الحديثة (DECOR-WH)',
        code: 'DECOR-WH',
      ),
      BenaaWarehouseInfo(
        id: '6a7f78f2e720fc52f142e040',
        name: 'المستودع الاحتياطي والتخزين الثانوي (BACKUP-WH)',
        code: 'BACKUP-WH',
      ),
    ];
  }

  static void _seedInitialCompanyUsers() {
    _cachedUsers = [];
  }

  /// Fetch all warehouses across BENAA
  static Future<List<BenaaWarehouseInfo>> fetchWarehouses() async {
    for (final base in _apiBases) {
      try {
        final res = await http.get(
          Uri.parse('$base/api/warehouses'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final List<dynamic> list = jsonDecode(res.body);
          _cachedWarehouses = list.map((e) => BenaaWarehouseInfo.fromJson(e)).toList();
          final sp = await SharedPreferences.getInstance();
          await sp.setString(_spWarehousesKey, jsonEncode(list));
          return _cachedWarehouses;
        }
      } catch (_) {}
    }
    return _cachedWarehouses;
  }

  /// Super Admin: Provision and create a new warehouse branch in BENAA
  static Future<bool> provisionNewWarehouse({
    required String name,
    required String code,
    String? address,
  }) async {
    final cleanCode = code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9\-]'), '');
    final newId = 'WH-${cleanCode.isEmpty ? "BRANCH" : cleanCode}-${DateTime.now().millisecondsSinceEpoch % 10000}';
    final newWh = BenaaWarehouseInfo(
      id: newId,
      name: name.trim(),
      code: cleanCode.isEmpty ? 'WH' : cleanCode,
      address: address?.trim(),
    );

    // Call Cloud Backend
    bool cloudSucceeded = false;
    for (final base in _apiBases) {
      try {
        final res = await http.post(
          Uri.parse('$base/api/warehouses'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name.trim(),
            'address': address?.trim() ?? '',
            'type': 'BRANCH',
            'status': true,
          }),
        ).timeout(const Duration(seconds: 5));

        if (res.statusCode == 201 || res.statusCode == 200) {
          cloudSucceeded = true;
          break;
        }
      } catch (_) {}
    }

    if (!cloudSucceeded) return false;

    _cachedWarehouses.add(newWh);
    final sp = await SharedPreferences.getInstance();
    final jsonList = _cachedWarehouses.map((w) => w.toJson()).toList();
    await sp.setString(_spWarehousesKey, jsonEncode(jsonList));
    return true;
  }

  /// Get all company users (Super Admin only)
  static Future<List<CompanyUser>> fetchCompanyUsers() async {
    for (final base in _apiBases) {
      try {
        final res = await http.get(
          Uri.parse('$base/api/admin/employees'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final List<dynamic> list = data['employees'] ?? [];
          _cachedUsers = list.map((e) => CompanyUser.fromJson(e)).toList();
          await _saveCachedUsers();
          return _cachedUsers;
        }
      } catch (_) {}
    }
    return _cachedUsers;
  }

  /// Super Admin: Provision and register a new user in the company database
  static Future<bool> provisionNewUser({
    required String name,
    required String email,
    required String username,
    required String password,
    required CompanyUserRole role,
    required String primaryWarehouseId,
    List<String> additionalWarehouseIds = const [],
    required String subscriptionStartDate,
    required String subscriptionEndDate,
    List<String> permissions = const [],
  }) async {
    final wh = _cachedWarehouses.firstWhere(
      (w) => w.id == primaryWarehouseId,
      orElse: () => BenaaWarehouseInfo(id: primaryWarehouseId, name: 'مستودع بناء', code: 'WH'),
    );

    final allWhIds = {primaryWarehouseId, ...additionalWarehouseIds}.toList();

    final newUser = CompanyUser(
      id: 'USR-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      email: email,
      username: username,
      role: role.roleKey,
      isActive: true,
      isSubscriptionActive: true,
      subscriptionStartDate: subscriptionStartDate,
      subscriptionEndDate: subscriptionEndDate,
      primaryWarehouseId: primaryWarehouseId,
      primaryWarehouseName: wh.name,
      primaryWarehouseCode: wh.code,
      warehouseIds: allWhIds,
      permissions: permissions,
      createdAt: DateTime.now().toIso8601String().split('T').first,
    );

    bool cloudSucceeded = false;
    for (final base in _apiBases) {
      try {
        final res = await http.post(
          Uri.parse('$base/api/admin/employees'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name,
            'email': email,
            'username': username,
            'password': password,
            'role': role.roleKey,
            'primaryWarehouseId': primaryWarehouseId,
            'additionalWarehouseIds': additionalWarehouseIds,
            'subscriptionStartDate': subscriptionStartDate,
            'subscriptionEndDate': subscriptionEndDate,
            'permissions': permissions,
          }),
        ).timeout(const Duration(seconds: 5));

        if (res.statusCode == 201 || res.statusCode == 200) {
          cloudSucceeded = true;
          break;
        }
      } catch (_) {}
    }

    if (!cloudSucceeded) return false;

    _cachedUsers.insert(0, newUser);
    await _saveCachedUsers();
    return true;
  }

  /// Super Admin: Move employee to another warehouse (reassignment)
  static Future<bool> reassignEmployeeWarehouse({
    required String employeeId,
    required String newPrimaryWarehouseId,
    List<String> additionalWarehouseIds = const [],
  }) async {
    final wh = _cachedWarehouses.firstWhere(
      (w) => w.id == newPrimaryWarehouseId,
      orElse: () => BenaaWarehouseInfo(id: newPrimaryWarehouseId, name: 'مستودع بناء', code: 'WH'),
    );

    // Call Cloud Backend
    bool cloudSucceeded = false;
    for (final base in _apiBases) {
      try {
        final res = await http.put(
          Uri.parse('$base/api/admin/employees'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'id': employeeId,
            'primaryWarehouseId': newPrimaryWarehouseId,
            'additionalWarehouseIds': additionalWarehouseIds,
          }),
        ).timeout(const Duration(seconds: 5));

        if (res.statusCode == 200) {
          cloudSucceeded = true;
          break;
        }
      } catch (_) {}
    }

    if (!cloudSucceeded) return false;

    // Update local state
    final idx = _cachedUsers.indexWhere((u) => u.id == employeeId);
    if (idx != -1) {
      final old = _cachedUsers[idx];
      final allWhIds = {newPrimaryWarehouseId, ...additionalWarehouseIds}.toList();
      _cachedUsers[idx] = CompanyUser(
        id: old.id,
        name: old.name,
        email: old.email,
        username: old.username,
        role: old.role,
        isActive: old.isActive,
        isSubscriptionActive: old.isSubscriptionActive,
        subscriptionStartDate: old.subscriptionStartDate,
        subscriptionEndDate: old.subscriptionEndDate,
        primaryWarehouseId: newPrimaryWarehouseId,
        primaryWarehouseName: wh.name,
        primaryWarehouseCode: wh.code,
        warehouseIds: allWhIds,
        permissions: old.permissions,
        createdAt: old.createdAt,
      );
      await _saveCachedUsers();
    }

    return true;
  }

  static Future<void> _saveCachedUsers() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final str = jsonEncode(_cachedUsers.map((u) => u.toJson()).toList());
      await sp.setString(_spUsersListKey, str);
    } catch (_) {}
  }

  /// Authenticate with email/username and password against Next.js API
  static Future<Map<String, dynamic>> loginWithCredentials({
    required String identifier,
    required String password,
  }) async {
    final cleanId = identifier.trim();
    final cleanPass = password.trim();

    if (cleanId.isEmpty || cleanPass.isEmpty) {
      return {'success': false, 'message': 'يرجى إدخال اسم المستخدم أو البريد الإلكتروني وكلمة المرور'};
    }

    // Try cloud backend
    for (final base in _apiBases) {
      try {
        final res = await http.post(
          Uri.parse('$base/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': cleanId,
            'password': cleanPass,
          }),
        ).timeout(const Duration(seconds: 4));

        final data = jsonDecode(res.body);

        if (res.statusCode == 200) {
          final wIds = (data['warehouseIds'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
          final perms = (data['permissions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

          final user = CompanyUser(
            id: data['userId']?.toString() ?? '',
            name: data['userName']?.toString() ?? cleanId,
            email: data['userEmail']?.toString() ?? cleanId,
            username: data['username']?.toString() ?? cleanId,
            role: data['userRole']?.toString() ?? 'STOREKEEPER',
            isActive: data['status'] ?? true,
            isSubscriptionActive: data['isSubscriptionActive'] ?? true,
            subscriptionStartDate: data['subscriptionStartDate']?.toString(),
            subscriptionEndDate: data['subscriptionEndDate']?.toString(),
            primaryWarehouseId: data['primaryWarehouseId']?.toString(),
            primaryWarehouseName: _getWarehouseName(data['primaryWarehouseId']?.toString()),
            warehouseIds: wIds,
            permissions: perms,
            createdAt: DateTime.now().toIso8601String().split('T').first,
          );

          _currentUser = user;
          final sp = await SharedPreferences.getInstance();
          await sp.setString(_spUserKey, jsonEncode(user.toJson()));
          if (data['sessionId'] != null) {
            await sp.setString('benaa_session_token', data['sessionId'].toString());
          }
          return {'success': true, 'user': user};
        } else if (res.statusCode == 403) {
          return {
            'success': false,
            'message': data['error'] ?? 'تم إيقاف هذا الحساب أو انتهاء فترة الاشتراك',
          };
        } else if (res.statusCode == 401) {
          return {
            'success': false,
            'message': data['error'] ?? 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
          };
        }
      } catch (_) {}
    }

    return {
      'success': false,
      'message': 'تعذر الاتصال بالخادم ولم يتم العثور على بيانات الحساب محلياً',
    };
  }

  static String _getWarehouseName(String? whId) {
    if (whId == null) return 'مستودع مواد البناء والديكور الرئيسي';
    final wh = _cachedWarehouses.firstWhere(
      (w) => w.id == whId,
      orElse: () => BenaaWarehouseInfo(id: whId, name: 'مستودع بناء', code: 'WH'),
    );
    return wh.name;
  }

  /// Sign out current user
  static Future<void> logout() async {
    _currentUser = null;
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_spUserKey);
    await sp.remove('benaa_session_token');
  }
}
