import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../data/models/item_model.dart';
import '../../data/models/transfer_model.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/product_unit_model.dart';
import '../../core/services/unit_conversion_engine.dart';
import '../../core/services/local_scope_service.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;
  bool _isInMemoryFallback = false;
  bool _isClearedPermanently = false;
  bool _isMemInitialized = false;
  String _activeScope = LocalScopeService.key;
  Future<void>? _memInitialization;
  Future<void> _salesWrites = Future.value();
  String _storageKey(String name) => _activeScope == 'legacy' ? name : '${_activeScope}_$name';
  Future<void> close() async {
    await _salesWrites;
    if (_isInMemoryFallback && _isMemInitialized) await _saveMemStateToPrefs();
    if (_database != null) await _database!.close();
    _database = null;
    _clearAllMemLists();
    _isMemInitialized = false;
    _memInitialization = null;
    _isInMemoryFallback = false;
  }
  Future<void> _ensureScope() async {
    if (_activeScope == LocalScopeService.key) return;
    if (_database != null) await _database!.close();
    _database = null;
    _clearAllMemLists();
    CustomerModel.clearAllCustomers();
    _isMemInitialized = false;
    _memInitialization = null;
    _isInMemoryFallback = false;
    _isClearedPermanently = false;
    _activeScope = LocalScopeService.key;
  }
  Future<void> _ready() async {
    await _ensureScope();
    final db = await database;
    if (db == null) await _initMemData();
  }

  // In-memory fallback structures for web/testing or SQLite failures
  final List<Map<String, dynamic>> _memItems = [];
  final List<Map<String, dynamic>> _memTransfers = [];
  final List<Map<String, dynamic>> _memTransferItems = [];
  final List<Map<String, dynamic>> _memSales = [];
  final List<Map<String, dynamic>> _memSaleItems = [];
  final List<Map<String, dynamic>> _memProductUnits = [];
  final List<Map<String, dynamic>> _memStockMovements = [];
  final List<Map<String, dynamic>> _memReturns = [];
  final List<Map<String, dynamic>> _memReturnItems = [];
  final List<Map<String, dynamic>> _memCustomers = [];
  final List<Map<String, dynamic>> _memCustomerPayments = [];
  final List<Map<String, dynamic>> _memAuditLogs = [];

  Future<Database?> get database async {
    await _ensureScope();
    if (_isInMemoryFallback) return null;
    if (kIsWeb) {
      _isInMemoryFallback = true;
      return null;
    }
    if (_database != null) return _database!;
    try {
      _database = await _initDB();
      return _database!;
    } catch (e) {
      debugPrint("Native SQLite failed or running on web fallback: $e");
      _isInMemoryFallback = true;
      return null;
    }
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), LocalScopeService.actorId == null ? 'benaa_inventory.db' : 'benaa_inventory_' + LocalScopeService.key + '.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE sale_items ADD COLUMN base_qty REAL;');
    }
    if (oldVersion < 2) {
      try { await db.execute('ALTER TABLE items ADD COLUMN unit_price REAL DEFAULT 25.0;'); } catch (_) {}
      try { await db.execute('ALTER TABLE items ADD COLUMN location TEXT;'); } catch (_) {}
      try { await db.execute('ALTER TABLE items ADD COLUMN size TEXT;'); } catch (_) {}
      try { await db.execute('ALTER TABLE items ADD COLUMN color TEXT;'); } catch (_) {}
      try { await db.execute('ALTER TABLE items ADD COLUMN finish_type TEXT;'); } catch (_) {}
    }
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE items (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT,
        unit TEXT,
        packaging_unit TEXT,
        conversion_factor REAL DEFAULT 1.0,
        current_stock REAL DEFAULT 0.0,
        unit_price REAL DEFAULT 25.0,
        location TEXT,
        size TEXT,
        color TEXT,
        finish_type TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE transfers (
        id TEXT PRIMARY KEY,
        transfer_number TEXT NOT NULL,
        from_warehouse TEXT NOT NULL,
        to_warehouse TEXT NOT NULL,
        author TEXT NOT NULL,
        date TEXT NOT NULL,
        status TEXT NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE transfer_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transfer_id TEXT NOT NULL,
        item_code TEXT NOT NULL,
        item_name TEXT NOT NULL,
        author TEXT NOT NULL,
        expected_qty REAL NOT NULL,
        actual_qty REAL NOT NULL,
        notes TEXT,
        image_path TEXT,
        FOREIGN KEY (transfer_id) REFERENCES transfers (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        audit_number TEXT NOT NULL,
        audit_date TEXT NOT NULL,
        item_code TEXT NOT NULL,
        item_name TEXT NOT NULL,
        system_qty REAL NOT NULL,
        counted_qty REAL NOT NULL,
        variance REAL NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        invoice_number TEXT NOT NULL,
        shop_name TEXT NOT NULL,
        date TEXT NOT NULL,
        total_amount REAL NOT NULL,
        status TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id TEXT NOT NULL,
        item_code TEXT NOT NULL,
        item_name TEXT NOT NULL,
        qty REAL NOT NULL,
        base_qty REAL,
        unit_price REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE product_units (
        id TEXT PRIMARY KEY,
        product_code TEXT NOT NULL,
        unit_name TEXT NOT NULL,
        unit_type TEXT NOT NULL,
        conversion_factor REAL NOT NULL,
        is_base INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        sale_price REAL,
        purchase_price REAL,
        FOREIGN KEY (product_code) REFERENCES items (code) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE stock_movements (
        id TEXT PRIMARY KEY,
        transaction_type TEXT NOT NULL,
        product_code TEXT NOT NULL,
        entered_quantity REAL NOT NULL,
        entered_unit TEXT NOT NULL,
        conversion_factor REAL NOT NULL,
        base_quantity REAL NOT NULL,
        base_unit TEXT NOT NULL,
        created_at TEXT NOT NULL,
        notes TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE returns (
        id TEXT PRIMARY KEY,
        return_number TEXT NOT NULL,
        return_type TEXT NOT NULL,
        party_name TEXT NOT NULL,
        date TEXT NOT NULL,
        refund_method TEXT NOT NULL,
        notes TEXT,
        total_amount REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        return_id TEXT NOT NULL,
        item_code TEXT NOT NULL,
        item_name TEXT NOT NULL,
        returned_qty REAL NOT NULL,
        unit TEXT NOT NULL,
        base_qty REAL NOT NULL,
        unit_price REAL NOT NULL,
        reason TEXT,
        FOREIGN KEY (return_id) REFERENCES returns (id) ON DELETE CASCADE
      )
    ''');

    await _seedInitialData(db);
  }

  Future<void> _seedInitialData(Database db) async {
    // Production Mode: Clean Empty Initial State
  }

  // --- Web / Fallback In-Memory Initializer & Local Storage Persistence ---
  Future<void> _initMemData() async {
    if (_isMemInitialized) return;
    await (_memInitialization ??= _loadMemStateFromPrefs());
    _isMemInitialized = true;
  }

  void _clearAllMemLists() {
    _memItems.clear();
    _memTransfers.clear();
    _memTransferItems.clear();
    _memSales.clear();
    _memSaleItems.clear();
    _memProductUnits.clear();
    _memStockMovements.clear();
    _memReturns.clear();
    _memReturnItems.clear();
    _memCustomers.clear();
    _memCustomerPayments.clear();
    _memAuditLogs.clear();
  }

  Map<String, List<Map<String, dynamic>>> get _persistedLists => {
    'items': _memItems,
    'transfers': _memTransfers,
    'transfer_items': _memTransferItems,
    'sales': _memSales,
    'sale_items': _memSaleItems,
    'product_units': _memProductUnits,
    'movements': _memStockMovements,
    'returns': _memReturns,
    'return_items': _memReturnItems,
    'customers': _memCustomers,
    'customer_payments': _memCustomerPayments,
    'audit_logs': _memAuditLogs,
  };

  Future<void> _loadMemStateFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final snapshot = prefs.getString(_storageKey('benaa_local_snapshot_v2'));
    final Map<String, dynamic> state = snapshot == null ? {} : jsonDecode(snapshot);
    // No demo migration or seed may replace user inventory/history.
    for (final entry in _persistedLists.entries) {
      final legacy = prefs.getString(_storageKey('benaa_mem_' + entry.key));
      final value = state[entry.key] ?? (legacy == null ? null : jsonDecode(legacy));
      if (value != null) {
        entry.value.clear();
        entry.value.addAll((value as List).map((row) => Map<String, dynamic>.from(row)));
      }
    }
  }

  Future<void> _saveMemStateToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(_storageKey('benaa_local_snapshot_v2'), jsonEncode(_persistedLists))) {
      throw StateError('Unable to persist local warehouse data');
    }
  }

  void seedRealisticTestData({bool force = false}) {
    if (!force && (_isClearedPermanently || _memItems.isNotEmpty)) return;
    _isClearedPermanently = false;
    _clearAllMemLists();

    _memItems.addAll([
      {
        'code': '154',
        'name': 'بلاط دبيس مقاس 60*60 رمادي ديكور فاخر',
        'category': 'ديكور أرضيات',
        'unit': 'كرتونة',
        'packaging_unit': 'كرتونة',
        'conversion_factor': 1.44,
        'current_stock': 0.0,
        'unit_price': 45.0,
        'location': 'ممر A - رف 1',
        'size': '60*60 سم',
        'color': 'رمادي فاتح',
        'finish_type': 'مطفي',
      },
      {
        'code': '4126',
        'name': 'جسر حديد معلق سقف مستعار 4 متر',
        'category': 'قطاعات وأسقف',
        'unit': 'حبة',
        'packaging_unit': 'ربطة',
        'conversion_factor': 10.0,
        'current_stock': 0.0,
        'unit_price': 28.0,
        'location': 'ممر B - رف 2',
        'size': '4 متر',
        'color': 'فضي مجلفن',
        'finish_type': 'سماكة 0.5 مم',
      },
      {
        'code': '6001',
        'name': 'عرضية 60 سم نظام تعليق سقف مستعار',
        'category': 'قطاعات وأسقف',
        'unit': 'حبة',
        'packaging_unit': 'كرتونة',
        'conversion_factor': 60.0,
        'current_stock': 0.0,
        'unit_price': 12.0,
        'location': 'ممر B - رف 3',
        'size': '60 سم',
        'color': 'أبيض ناصع',
        'finish_type': 'مقاوم للصدأ',
      },
      {
        'code': '1202',
        'name': 'عرضية 120 سم نظام تعليق سقف مستعار',
        'category': 'قطاعات وأسقف',
        'unit': 'حبة',
        'packaging_unit': 'كرتونة',
        'conversion_factor': 40.0,
        'current_stock': 0.0,
        'unit_price': 18.0,
        'location': 'ممر B - رف 3',
        'size': '120 سم',
        'color': 'أبيض ناصع',
        'finish_type': 'مقاوم للصدأ',
      },
      {
        'code': '3001',
        'name': 'زاوية ديكور ألومنيوم 3 متر بيضاء',
        'category': 'زوايا وإكسسوارات',
        'unit': 'حبة',
        'packaging_unit': 'حزمة',
        'conversion_factor': 25.0,
        'current_stock': 0.0,
        'unit_price': 15.0,
        'location': 'ممر C - رف 1',
        'size': '3 متر',
        'color': 'أبيض',
        'finish_type': 'ألومنيوم مدهون',
      },
      {
        'code': '9042',
        'name': 'دهان رويال حريري ناصع البياض',
        'category': 'دهانات وعوازل',
        'unit': 'جالون',
        'packaging_unit': 'كرتونة',
        'conversion_factor': 4.0,
        'current_stock': 0.0,
        'unit_price': 140.0,
        'location': 'ممر D - رف 4',
        'size': 'جالون 3.6 لتر',
        'color': 'أبيض حريري',
        'finish_type': 'نصف لمعة',
      },
      {
        'code': '1010',
        'name': 'جبس بورد مقاوم للرطوبة 12.5 مم',
        'category': 'ألواح جبسية',
        'unit': 'لوح',
        'packaging_unit': 'بالتة',
        'conversion_factor': 50.0,
        'current_stock': 0.0,
        'unit_price': 38.0,
        'location': 'ممر A - رف 4',
        'size': '1.20 * 2.40 م',
        'color': 'أخضر',
        'finish_type': 'مقاوم للرطوبة',
      },
      {
        'code': '1011',
        'name': 'جبس بورد عادي 12.5 مم كناوف أصلي',
        'category': 'ألواح جبسية',
        'unit': 'لوح',
        'packaging_unit': 'بالتة',
        'conversion_factor': 50.0,
        'current_stock': 0.0,
        'unit_price': 28.5,
        'location': 'ممر A - رف 2',
        'size': '1.20 * 2.40 م',
        'color': 'رمادي بيج',
        'finish_type': 'عادي',
      },
      {
        'code': '1012',
        'name': 'جبس بورد مقاوم للحريق 12.5 مم أحمر',
        'category': 'ألواح جبسية',
        'unit': 'لوح',
        'packaging_unit': 'بالتة',
        'conversion_factor': 50.0,
        'current_stock': 0.0,
        'unit_price': 44.0,
        'location': 'ممر A - رف 3',
        'size': '1.20 * 2.40 م',
        'color': 'وردي أحمر',
        'finish_type': 'مقاوم للحريق',
      },
      {
        'code': '2015',
        'name': 'قطاع أوميجا سقف مستعار 0.45 مم مجلفن',
        'category': 'قطاعات حديد',
        'unit': 'حبة',
        'packaging_unit': 'ربطة',
        'conversion_factor': 20.0,
        'current_stock': 0.0,
        'unit_price': 9.5,
        'location': 'ممر B - رف 1',
        'size': '3 متر',
        'color': 'فضي',
        'finish_type': 'مجلفن',
      },
      {
        'code': '2016',
        'name': 'قطاع C-Stud قواطع جدارية 70 مم',
        'category': 'قطاعات حديد',
        'unit': 'حبة',
        'packaging_unit': 'ربطة',
        'conversion_factor': 10.0,
        'current_stock': 0.0,
        'unit_price': 16.0,
        'location': 'ممر B - رف 2',
        'size': '3 متر',
        'color': 'فضي',
        'finish_type': '0.5 مم',
      },
      {
        'code': '2017',
        'name': 'قطاع U-Track مسار أرضي وسقفي 70 مم',
        'category': 'قطاعات حديد',
        'unit': 'حبة',
        'packaging_unit': 'ربطة',
        'conversion_factor': 10.0,
        'current_stock': 0.0,
        'unit_price': 14.5,
        'location': 'ممر B - رف 2',
        'size': '3 متر',
        'color': 'فضي',
        'finish_type': '0.5 مم',
      },
      {
        'code': '3020',
        'name': 'معجون فواصل جبس بورد كناوف 28 كجم',
        'category': 'معجون ومواد لاصقة',
        'unit': 'كيس',
        'packaging_unit': 'بالتة',
        'conversion_factor': 40.0,
        'current_stock': 0.0,
        'unit_price': 42.0,
        'location': 'ممر C - رف 3',
        'size': '28 كجم',
        'color': 'أبيض',
        'finish_type': 'بودرة جاهزة للخلط',
      },
      {
        'code': '3021',
        'name': 'شريط فواصل شبك فايبر جلاس 90 متر',
        'category': 'إكسسوارات فواصل',
        'unit': 'لفة',
        'packaging_unit': 'كرتونة',
        'conversion_factor': 24.0,
        'current_stock': 0.0,
        'unit_price': 18.0,
        'location': 'ممر C - رف 2',
        'size': '90 متر * 5 سم',
        'color': 'أبيض شبكي',
        'finish_type': 'ذاتي اللصق',
      },
      {
        'code': '3022',
        'name': 'شريط فواصل ورقي مثقب 150 متر',
        'category': 'إكسسوارات فواصل',
        'unit': 'لفة',
        'packaging_unit': 'كرتونة',
        'conversion_factor': 20.0,
        'current_stock': 0.0,
        'unit_price': 22.0,
        'location': 'ممر C - رف 2',
        'size': '150 متر * 5 سم',
        'color': 'بيج ورقي',
        'finish_type': 'مثقب ليزري',
      },
      {
        'code': '4030',
        'name': 'براغي جبس بورد مصلبة 25 مم أسود',
        'category': 'مثبتات وبراغي',
        'unit': 'علبة',
        'packaging_unit': 'كرتونة',
        'conversion_factor': 16.0,
        'current_stock': 0.0,
        'unit_price': 24.0,
        'location': 'ممر C - رف 4',
        'size': '25 مم (1000 حبة)',
        'color': 'أسود مقسّى',
        'finish_type': 'سن خشن',
      },
      {
        'code': '4031',
        'name': 'براغي ذاتية الثقب حديد 35 مم',
        'category': 'مثبتات وبراغي',
        'unit': 'علبة',
        'packaging_unit': 'كرتونة',
        'conversion_factor': 12.0,
        'current_stock': 0.0,
        'unit_price': 28.0,
        'location': 'ممر C - رف 4',
        'size': '35 مم (1000 حبة)',
        'color': 'فضي زنك',
        'finish_type': 'رأس مصلب',
      },
      {
        'code': '4032',
        'name': 'فيشر تثبيت حديد إسفين 6 مم للأسقف',
        'category': 'مثبتات وبراغي',
        'unit': 'كرتونة',
        'packaging_unit': 'كرتونة',
        'conversion_factor': 1.0,
        'current_stock': 0.0,
        'unit_price': 35.0,
        'location': 'ممر C - رف 5',
        'size': '6*40 مم (100 حبة)',
        'color': 'فضي',
        'finish_type': 'صلب متمدد',
      },
      {
        'code': '5010',
        'name': 'بلاطات أسقف جبسية فينيل مخرمة 60*60',
        'category': 'بلاطات سقف',
        'unit': 'كرتونة',
        'packaging_unit': 'كرتونة',
        'conversion_factor': 8.0,
        'current_stock': 0.0,
        'unit_price': 52.0,
        'location': 'ممر D - رف 1',
        'size': '60*60 سم (8 حبات)',
        'color': 'أبيض فينيل',
        'finish_type': 'عازل حراري خلفي',
      },
      {
        'code': '5012',
        'name': 'بلاطات ألياف صخرية عازلة للصوت 60*60',
        'category': 'بلاطات سقف',
        'unit': 'كرتونة',
        'packaging_unit': 'كرتونة',
        'conversion_factor': 10.0,
        'current_stock': 0.0,
        'unit_price': 68.0,
        'location': 'ممر D - رف 2',
        'size': '60*60 سم (10 حبات)',
        'color': 'أبيض نقوش ناعمة',
        'finish_type': 'امتصاص صوتي',
      },
      {
        'code': '6015',
        'name': 'صوف صخري عازل حراري كثافة 50 كجم',
        'category': 'عوازل حرارية',
        'unit': 'حزمة',
        'packaging_unit': 'بالتة',
        'conversion_factor': 12.0,
        'current_stock': 0.0,
        'unit_price': 85.0,
        'location': 'ممر E - رف 1',
        'size': '1.20 * 0.60 م (6 ألواح)',
        'color': 'أصفر مخضر',
        'finish_type': 'كثافة 50 كجم/م3',
      },
      {
        'code': '6016',
        'name': 'صوف زجاجي مع قصدير ألومنيوم 50 مم',
        'category': 'عوازل حرارية',
        'unit': 'لفة',
        'packaging_unit': 'لفة',
        'conversion_factor': 1.0,
        'current_stock': 0.0,
        'unit_price': 110.0,
        'location': 'ممر E - رف 2',
        'size': '15 متر * 1.2 متر',
        'color': 'أصفر مع قصدير',
        'finish_type': 'مقاوم للحريق',
      },
      {
        'code': '7001',
        'name': 'دهان داخلي مائي جوتن بروفيشنال مطفي',
        'category': 'دهانات وعوازل',
        'unit': 'سطل',
        'packaging_unit': 'بالتة',
        'conversion_factor': 36.0,
        'current_stock': 0.0,
        'unit_price': 185.0,
        'location': 'ممر D - رف 3',
        'size': 'سطل 18 لتر',
        'color': 'أبيض ناصع 001',
        'finish_type': 'مطفي قابل للغسيل',
      },
      {
        'code': '7002',
        'name': 'دهان برايمر مائي مقاوم للأملاح والقلويات',
        'category': 'دهانات وعوازل',
        'unit': 'سطل',
        'packaging_unit': 'بالتة',
        'conversion_factor': 36.0,
        'current_stock': 0.0,
        'unit_price': 130.0,
        'location': 'ممر D - رف 3',
        'size': 'سطل 18 لتر',
        'color': 'أبيض شفاف',
        'finish_type': 'أساس سيلر',
      },
      {
        'code': '7005',
        'name': 'سيليكون أكريليك أبيض إيطالي للجبس',
        'category': 'معجون ومواد لاصقة',
        'unit': 'حبة',
        'packaging_unit': 'كرتونة',
        'conversion_factor': 24.0,
        'current_stock': 0.0,
        'unit_price': 8.5,
        'location': 'ممر C - رف 1',
        'size': '310 مل',
        'color': 'أبيض',
        'finish_type': 'قابل للدهان',
      },
      {
        'code': '8001',
        'name': 'كشاف ليد بانل غاطس 60*60 48 واط',
        'category': 'إنارة وديكور',
        'unit': 'حبة',
        'packaging_unit': 'كرتونة',
        'conversion_factor': 6.0,
        'current_stock': 0.0,
        'unit_price': 45.0,
        'location': 'ممر F - رف 1',
        'size': '60*60 سم (48W)',
        'color': 'أبيض إطار ناعم',
        'finish_type': 'إضاءة بيضاء 6500K',
      },
      {
        'code': '8002',
        'name': 'سبوت لايت مانع للتوهج 7 واط جرم أسود',
        'category': 'إنارة وديكور',
        'unit': 'حبة',
        'packaging_unit': 'كرتونة',
        'conversion_factor': 50.0,
        'current_stock': 0.0,
        'unit_price': 22.0,
        'location': 'ممر F - رف 2',
        'size': '7 واط مقاس 7 سم',
        'color': 'جرم أسود مط',
        'finish_type': 'إضاءة دافئة 3000K',
      },
      {
        'code': '8005',
        'name': 'شريط إضاءة مخفية LED COB دافئ 5 متر',
        'category': 'إنارة وديكور',
        'unit': 'لفة',
        'packaging_unit': 'كرتونة',
        'conversion_factor': 20.0,
        'current_stock': 0.0,
        'unit_price': 38.0,
        'location': 'ممر F - رف 3',
        'size': '5 متر 24V',
        'color': 'ورم لايت 3000K',
        'finish_type': 'كثافة 480 ليد/متر',
      },
      {
        'code': '9010',
        'name': 'فوم عازل رغوي بولي يوريثان 750 مل',
        'category': 'عوازل ومثبتات',
        'unit': 'حبة',
        'packaging_unit': 'كرتونة',
        'conversion_factor': 12.0,
        'current_stock': 0.0,
        'unit_price': 19.0,
        'location': 'ممر E - رف 3',
        'size': '750 مل بخاخ',
        'color': 'رغوة بيج',
        'finish_type': 'تمدد ذاتي سريع',
      },
      {
        'code': '9015',
        'name': 'سلك تعليق مجلفن قابل للتعديل 1 متر',
        'category': 'قطاعات وأسقف',
        'unit': 'حبة',
        'packaging_unit': 'حزمة',
        'conversion_factor': 100.0,
        'current_stock': 0.0,
        'unit_price': 2.5,
        'location': 'ممر B - رف 4',
        'size': '1 متر مع زنبرك',
        'color': 'فضي مجلفن',
        'finish_type': 'مقاوم للصدأ',
      },
      {
        'code': '9020',
        'name': 'زاوية حماية ركن معدنية 3 متر مجلفنة',
        'category': 'زوايا وإكسسوارات',
        'unit': 'حبة',
        'packaging_unit': 'ربطة',
        'conversion_factor': 50.0,
        'current_stock': 0.0,
        'unit_price': 7.0,
        'location': 'ممر B - رف 5',
        'size': '3 متر مخرمة',
        'color': 'فضي',
        'finish_type': 'زاوية 90 درجة',
      },
      {
        'code': '9030',
        'name': 'شبك فايبر جلاس للياسة والعزل 50 متر',
        'category': 'عوازل وشبك',
        'unit': 'لفة',
        'packaging_unit': 'لفة',
        'conversion_factor': 1.0,
        'current_stock': 0.0,
        'unit_price': 65.0,
        'location': 'ممر E - رف 4',
        'size': '50 متر * 1 متر',
        'color': 'أبيض 160 جم',
        'finish_type': 'مقاوم للقلويات',
      },
    ]);

    _memTransfers.clear();

    _memTransferItems.clear();

    _memCustomers.clear();

    _saveMemStateToPrefs();
  }

  void _seedDefaultDemoData() {
    seedRealisticTestData(force: false);
  }

  // --- CRUD Operations ---

  Future<List<TransferModel>> getTransfers() async {
    await _ready();
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      await _initMemData();
      List<TransferModel> result = [];
      for (var map in _memTransfers) {
        final tId = map['id'].toString();
        final itemsMap = _memTransferItems.where((i) => i['transfer_id'] == tId).toList();
        final items = itemsMap.map((i) => TransferItemModel.fromMap(i)).toList();
        result.add(TransferModel.fromMap(map, items: items));
      }
      return result;
    }

    try {
      var transferMaps = await db.query('transfers');
      List<TransferModel> transfers = [];
      for (var map in transferMaps) {
        final transferId = map['id'].toString();
        final itemMaps = await db.query(
          'transfer_items',
          where: 'transfer_id = ?',
          whereArgs: [transferId],
        );
        final items = itemMaps.map((i) => TransferItemModel.fromMap(i)).toList();
        transfers.add(TransferModel.fromMap(map, items: items));
      }
      return transfers;
    } catch (e) {
      debugPrint("Error fetching transfers from SQLite: $e");
      _isInMemoryFallback = true;
      return getTransfers();
    }
  }

  Future<TransferModel?> getTransferById(String id) async {
    await _ready();
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      await _initMemData();
      final maps = _memTransfers.where((t) => t['id'] == id).toList();
      if (maps.isEmpty) return null;
      final itemsMap = _memTransferItems.where((i) => i['transfer_id'] == id).toList();
      final items = itemsMap.map((i) => TransferItemModel.fromMap(i)).toList();
      return TransferModel.fromMap(maps.first, items: items);
    }

    try {
      final maps = await db.query('transfers', where: 'id = ?', whereArgs: [id]);
      if (maps.isEmpty) return null;

      final itemMaps = await db.query('transfer_items', where: 'transfer_id = ?', whereArgs: [id]);
      final items = itemMaps.map((i) => TransferItemModel.fromMap(i)).toList();
      return TransferModel.fromMap(maps.first, items: items);
    } catch (e) {
      debugPrint("Error fetching transfer by id from SQLite: $e");
      _isInMemoryFallback = true;
      return getTransferById(id);
    }
  }

  Future<void> updateTransferItemQty(int itemId, double actualQty, String? notes, {String? imagePath}) async {
    await _ready();
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      final idx = _memTransferItems.indexWhere((i) => i['id'] == itemId);
      if (idx != -1) {
        _memTransferItems[idx]['actual_qty'] = actualQty;
        _memTransferItems[idx]['notes'] = notes;
        if (imagePath != null) {
          _memTransferItems[idx]['image_path'] = imagePath;
        }
      }
      return;
    }

    try {
      Map<String, dynamic> updateData = {'actual_qty': actualQty, 'notes': notes};
      if (imagePath != null) {
        updateData['image_path'] = imagePath;
      }
      await db.update(
        'transfer_items',
        updateData,
        where: 'id = ?',
        whereArgs: [itemId],
      );
    } catch (e) {
      debugPrint("Error updating transfer item qty: $e");
    }
  }

  Future<void> confirmTransferAudit(String transferId, String status) async {
    await _ready();
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      await _initMemData();
      final idx = _memTransfers.indexWhere((t) => t['id'] == transferId);
      if (idx != -1) {
        final currentStatus = (_memTransfers[idx]['status'] ?? '').toString();
        // IDEMPOTENCY PROTECTION: Prevent duplicate stock addition on rapid double taps
        if (currentStatus.startsWith('audited')) {
          _memTransfers[idx]['status'] = status;
          return;
        }
        _memTransfers[idx]['status'] = status;
      }
      final itemsForTransfer = _memTransferItems.where((i) => i['transfer_id'] == transferId).toList();
      for (var tItem in itemsForTransfer) {
        final code = (tItem['item_code'] ?? '').toString().trim();
        final name = (tItem['item_name'] ?? '').toString().trim();
        final actualQty = (tItem['actual_qty'] as num).toDouble();

        final itemIdx = _memItems.indexWhere((i) {
          final c = (i['code'] ?? '').toString().trim().toLowerCase();
          final n = (i['name'] ?? '').toString().trim().toLowerCase();
          return (code.isNotEmpty && c == code.toLowerCase()) ||
              (name.isNotEmpty && n == name.toLowerCase());
        });

        String finalCode = code;
        if (itemIdx != -1) {
          final oldStock = (_memItems[itemIdx]['current_stock'] as num).toDouble();
          _memItems[itemIdx]['current_stock'] = oldStock + actualQty;
          finalCode = _memItems[itemIdx]['code'].toString();
        } else {
          finalCode = code.isNotEmpty ? code : 'ITEM-${DateTime.now().millisecondsSinceEpoch % 100000}';
          _memItems.add({
            'code': finalCode,
            'name': name.isNotEmpty ? name : 'صنف جديد',
            'category': 'عام',
            'unit': 'حبة',
            'packaging_unit': 'كرتونة',
            'conversion_factor': 1.0,
            'current_stock': actualQty,
            'unit_price': 25.0,
            'location': 'ممر A - رف 1',
          });
        }

        await postStockMovement(StockMovementSnapshot(
          transactionId: 'MOV-TRF-${DateTime.now().millisecondsSinceEpoch}-$finalCode',
          transactionType: 'إذن توريد / استلام شحنة (+)',
          productCode: finalCode,
          enteredQuantity: actualQty,
          enteredUnit: 'حبة',
          conversionFactor: 1.0,
          baseQuantity: actualQty,
          baseUnit: 'حبة',
          date: DateTime.now().toIso8601String().split('T').first,
          notes: 'إذن توريد واستلام بضاعة بالمستودع',
        ));
      }
      return;
    }

    try {
      final existingTransfer = await db.query('transfers', where: 'id = ?', whereArgs: [transferId]);
      if (existingTransfer.isNotEmpty) {
        final currentStatus = (existingTransfer.first['status'] ?? '').toString();
        if (currentStatus.startsWith('audited')) {
          await db.update('transfers', {'status': status}, where: 'id = ?', whereArgs: [transferId]);
          return; // Already audited, do not double-add stock
        }
      }

      await db.update(
        'transfers',
        {'status': status},
        where: 'id = ?',
        whereArgs: [transferId],
      );

      final itemMaps = await db.query('transfer_items', where: 'transfer_id = ?', whereArgs: [transferId]);
      for (var map in itemMaps) {
        final itemCode = (map['item_code'] ?? '').toString().trim();
        final itemName = (map['item_name'] ?? '').toString().trim();
        final actualQty = (map['actual_qty'] as num).toDouble();

        final existing = await db.query(
          'items',
          where: 'code = ? OR LOWER(TRIM(name)) = ?',
          whereArgs: [itemCode, itemName.toLowerCase()],
        );

        String finalCode = itemCode;
        if (existing.isNotEmpty) {
          finalCode = existing.first['code'].toString();
          await db.rawUpdate('''
            UPDATE items 
            SET current_stock = current_stock + ? 
            WHERE code = ?
          ''', [actualQty, finalCode]);
        } else {
          finalCode = itemCode.isNotEmpty ? itemCode : 'ITEM-${DateTime.now().millisecondsSinceEpoch % 100000}';
          await db.insert(
            'items',
            {
              'code': finalCode,
              'name': itemName.isNotEmpty ? itemName : 'صنف جديد',
              'category': 'عام',
              'unit': 'حبة',
              'packaging_unit': 'كرتونة',
              'conversion_factor': 1.0,
              'current_stock': actualQty,
              'unit_price': 25.0,
              'location': 'ممر A - رف 1',
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        await postStockMovement(StockMovementSnapshot(
          transactionId: 'MOV-TRF-${DateTime.now().millisecondsSinceEpoch}-$finalCode',
          transactionType: 'إذن توريد / استلام شحنة (+)',
          productCode: finalCode,
          enteredQuantity: actualQty,
          enteredUnit: 'حبة',
          conversionFactor: 1.0,
          baseQuantity: actualQty,
          baseUnit: 'حبة',
          date: DateTime.now().toIso8601String().split('T').first,
          notes: 'إذن توريد واستلام بضاعة بالمستودع',
        ));
      }
    } catch (e) {
      debugPrint("Error confirming transfer audit in SQLite: $e");
    }
  }

  Future<List<ItemModel>> getLocalItems() async {
    await _ready();
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      await _initMemData();
      List<ItemModel> result = [];
      for (var map in _memItems) {
        final code = map['code'].toString();
        final unitMaps = _memProductUnits.where((u) => u['product_code'] == code).toList();
        final loadedUnits = unitMaps.isNotEmpty
            ? unitMaps.map((u) => ProductUnitModel.fromMap(u)).toList()
            : null;
        result.add(ItemModel.fromMap(map, loadedUnits: loadedUnits));
      }
      return result;
    }

    try {
      final maps = await db.query('items');
      List<ItemModel> result = [];
      for (var map in maps) {
        final code = map['code'].toString();
        final unitMaps = await db.query('product_units', where: 'product_code = ?', whereArgs: [code]);
        final loadedUnits = unitMaps.isNotEmpty
            ? unitMaps.map((u) => ProductUnitModel.fromMap(u)).toList()
            : null;
        result.add(ItemModel.fromMap(map, loadedUnits: loadedUnits));
      }
      return result;
    } catch (e) {
      debugPrint("Error fetching local items from SQLite: $e");
      _isInMemoryFallback = true;
      return getLocalItems();
    }
  }

  Future<List<ProductUnitModel>> getProductUnits(String productCode) async {
    await _ready();
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      await _initMemData();
      final maps = _memProductUnits.where((u) => u['product_code'] == productCode).toList();
      if (maps.isNotEmpty) {
        return maps.map((m) => ProductUnitModel.fromMap(m)).toList();
      }
      final itemMap = _memItems.firstWhere((i) => i['code'] == productCode, orElse: () => {});
      if (itemMap.isNotEmpty) {
        final item = ItemModel.fromMap(itemMap);
        return item.units;
      }
      return [];
    }

    try {
      final maps = await db.query(
        'product_units',
        where: 'product_code = ?',
        whereArgs: [productCode],
      );

      if (maps.isNotEmpty) {
        return maps.map((m) => ProductUnitModel.fromMap(m)).toList();
      }

      final itemMaps = await db.query('items', where: 'code = ?', whereArgs: [productCode]);
      if (itemMaps.isNotEmpty) {
        final item = ItemModel.fromMap(itemMaps.first);
        return item.units;
      }
      return [];
    } catch (e) {
      debugPrint("Error getting product units from SQLite: $e");
      return [];
    }
  }

  Future<void> saveProductUnit(ProductUnitModel unit) async {
    await _ready();
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      _initMemData();
      final idx = _memProductUnits.indexWhere((u) => u['id'] == unit.id);
      if (idx != -1) {
        _memProductUnits[idx] = unit.toMap();
      } else {
        _memProductUnits.add(unit.toMap());
      }
      return;
    }

    try {
      await db.insert(
        'product_units',
        unit.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint("Error saving product unit to SQLite: $e");
    }
  }

  Future<void> postStockMovement(StockMovementSnapshot snapshot) async {
    await _ready();
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      _initMemData();
      _memStockMovements.add(snapshot.toMap());
      return;
    }

    try {
      await db.insert('stock_movements', snapshot.toMap());
    } catch (e) {
      debugPrint("Error posting stock movement to SQLite: $e");
    }
  }

  Future<List<StockMovementSnapshot>> getStockMovements(String productCode) async {
    await _ready();
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      _initMemData();
      final list = _memStockMovements.where((m) => m['product_code'] == productCode).toList();
      return list.map((m) => StockMovementSnapshot(
        transactionId: m['id'],
        transactionType: m['transaction_type'],
        productCode: m['product_code'],
        enteredQuantity: (m['entered_quantity'] as num).toDouble(),
        enteredUnit: m['entered_unit'],
        conversionFactor: (m['conversion_factor'] as num).toDouble(),
        baseQuantity: (m['base_quantity'] as num).toDouble(),
        baseUnit: m['base_unit'],
        date: m['created_at'],
        notes: m['notes'],
      )).toList();
    }

    try {
      final maps = await db.query(
        'stock_movements',
        where: 'product_code = ?',
        whereArgs: [productCode],
        orderBy: 'created_at DESC',
      );

      return maps.map((m) => StockMovementSnapshot(
        transactionId: m['id'].toString(),
        transactionType: m['transaction_type'].toString(),
        productCode: m['product_code'].toString(),
        enteredQuantity: (m['entered_quantity'] as num).toDouble(),
        enteredUnit: m['entered_unit'].toString(),
        conversionFactor: (m['conversion_factor'] as num).toDouble(),
        baseQuantity: (m['base_quantity'] as num).toDouble(),
        baseUnit: m['base_unit'].toString(),
        date: m['created_at'].toString(),
        notes: m['notes']?.toString(),
      )).toList();
    } catch (e) {
      debugPrint("Error getting stock movements from SQLite: $e");
      return [];
    }
  }

  Future<void> recordLocalStockAudit(String itemCode, String itemName, double systemQty, double countedQty, String? notes) async {
    await _ready();
    final nowIso = DateTime.now().toIso8601String().split('T').first;
    final auditNumber = 'AUD-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final variance = countedQty - systemQty;

    final db = await database;
    if (db == null || _isInMemoryFallback) {
      final idx = _memItems.indexWhere((i) => i['code'] == itemCode);
      if (idx != -1) {
        _memItems[idx]['current_stock'] = countedQty;
      }
      _memAuditLogs.insert(0, {
        'id': _memAuditLogs.length + 1,
        'audit_number': auditNumber,
        'audit_date': nowIso,
        'item_code': itemCode,
        'item_name': itemName,
        'system_qty': systemQty,
        'counted_qty': countedQty,
        'variance': variance,
        'notes': notes ?? '',
      });
      return;
    }

    try {
      await db.update(
        'items',
        {'current_stock': countedQty},
        where: 'code = ?',
        whereArgs: [itemCode],
      );

      await db.insert('audit_logs', {
        'audit_number': auditNumber,
        'audit_date': nowIso,
        'item_code': itemCode,
        'item_name': itemName,
        'system_qty': systemQty,
        'counted_qty': countedQty,
        'variance': variance,
        'notes': notes ?? '',
      });
    } catch (e) {
      debugPrint("Error recording local stock audit in SQLite: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getAuditLogs() async {
    await _ready();
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      return List<Map<String, dynamic>>.from(_memAuditLogs);
    }
    try {
      return await db.query('audit_logs', orderBy: 'id DESC');
    } catch (e) {
      debugPrint("Error fetching audit logs from SQLite: $e");
      return [];
    }
  }

  static int _txCounter = 1;

  Future<String> createNewCustomTransfer({
    required String transferNumber,
    required String fromWarehouse,
    required String toWarehouse,
    required String author,
    required String notes,
    required List<Map<String, dynamic>> items,
  }) async {
    await _ready();
    final transferId = 'trf-custom-${DateTime.now().microsecondsSinceEpoch}-${_txCounter++}';
    final db = await database;

    if (db == null || _isInMemoryFallback) {
      _isClearedPermanently = false;
      _memTransfers.add({
        'id': transferId,
        'transfer_number': transferNumber,
        'from_warehouse': fromWarehouse,
        'to_warehouse': toWarehouse,
        'author': author,
        'date': DateTime.now().toIso8601String().split('T').first,
        'status': 'pending_audit',
        'notes': notes,
      });

      int nextId = _memTransferItems.isEmpty ? 1 : ((_memTransferItems.map((i) => i['id'] is int ? i['id'] as int : 0).fold(0, (max, e) => e > max ? e : max)) + 1);
      for (var item in items) {
        final rawQty = item['qty'] ?? item['expected_qty'];
        final double qty = rawQty is num
            ? rawQty.toDouble()
            : (double.tryParse(rawQty?.toString() ?? '1.0') ?? 1.0);

        _memTransferItems.add({
          'id': nextId++,
          'transfer_id': transferId,
          'item_code': item['item_code']?.toString() ?? 'ITEM-${DateTime.now().millisecondsSinceEpoch % 100000}',
          'item_name': item['item_name']?.toString() ?? 'صنف جديد',
          'author': author,
          'expected_qty': qty,
          'actual_qty': qty,
          'notes': item['notes'] ?? '',
        });
      }
      await _saveMemStateToPrefs();
      return transferId;
    }

    try {
      await db.insert(
        'transfers',
        {
          'id': transferId,
          'transfer_number': transferNumber,
          'from_warehouse': fromWarehouse,
          'to_warehouse': toWarehouse,
          'author': author,
          'date': DateTime.now().toIso8601String().split('T').first,
          'status': 'pending_audit',
          'notes': notes,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      for (var item in items) {
        final rawQty = item['qty'] ?? item['expected_qty'];
        final double qty = rawQty is num
            ? rawQty.toDouble()
            : (double.tryParse(rawQty?.toString() ?? '1.0') ?? 1.0);

        await db.insert(
          'transfer_items',
          {
            'transfer_id': transferId,
            'item_code': item['item_code']?.toString() ?? 'ITEM-${DateTime.now().millisecondsSinceEpoch % 100000}',
            'item_name': item['item_name']?.toString() ?? 'صنف جديد',
            'author': author,
            'expected_qty': qty,
            'actual_qty': qty,
            'notes': item['notes'] ?? '',
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (e) {
      debugPrint("Error inserting transfer into SQLite: $e. Using fallback.");
      _isInMemoryFallback = true;
      return createNewCustomTransfer(
        transferNumber: transferNumber,
        fromWarehouse: fromWarehouse,
        toWarehouse: toWarehouse,
        author: author,
        notes: notes,
        items: items,
      );
    }

    return transferId;
  }

  Future<void> registerOrUpdateLocalItem({
    required String code,
    required String name,
    required String category,
    required String unit,
    required double initialQty,
    double unitPrice = 25.0,
    String location = 'ممر A - رف 1 - كابينة 1',
  }) async {
    await _ready();
    final cleanCode = code.trim();
    final cleanName = name.trim();

    final db = await database;
    if (db == null || _isInMemoryFallback) {
      final idx = _memItems.indexWhere((i) {
        final c = (i['code'] ?? '').toString().trim().toLowerCase();
        final n = (i['name'] ?? '').toString().trim().toLowerCase();
        return (cleanCode.isNotEmpty && c == cleanCode.toLowerCase()) ||
            (cleanName.isNotEmpty && n == cleanName.toLowerCase());
      });

      if (idx != -1) {
        final current = (_memItems[idx]['current_stock'] as num).toDouble();
        _memItems[idx]['current_stock'] = current + initialQty;
        _memItems[idx]['name'] = cleanName;
        _memItems[idx]['unit'] = unit;
        _memItems[idx]['category'] = category;
        _memItems[idx]['location'] = location;
      } else {
        _memItems.add({
          'code': cleanCode.isNotEmpty ? cleanCode : 'ITEM-${DateTime.now().millisecondsSinceEpoch % 100000}',
          'name': cleanName,
          'category': category,
          'unit': unit,
          'packaging_unit': 'كرتونة',
          'conversion_factor': 1.0,
          'current_stock': initialQty,
          'unit_price': unitPrice,
          'location': location,
        });
      }
      _isClearedPermanently = false;
      await _saveMemStateToPrefs();
      return;
    }

    try {
      final existing = await db.query(
        'items',
        where: 'code = ? OR LOWER(TRIM(name)) = ?',
        whereArgs: [cleanCode, cleanName.toLowerCase()],
      );

      if (existing.isNotEmpty) {
        final existingCode = existing.first['code'].toString();
        final currentStock = (existing.first['current_stock'] as num).toDouble();
        await db.update(
          'items',
          {
            'name': cleanName,
            'category': category,
            'unit': unit,
            'current_stock': currentStock + initialQty,
            'unit_price': unitPrice,
            'location': location,
          },
          where: 'code = ?',
          whereArgs: [existingCode],
        );
      } else {
        await db.insert(
          'items',
          {
            'code': cleanCode.isNotEmpty ? cleanCode : 'ITEM-${DateTime.now().millisecondsSinceEpoch % 100000}',
            'name': cleanName,
            'category': category,
            'unit': unit,
            'packaging_unit': 'كرتونة',
            'conversion_factor': 1.0,
            'current_stock': initialQty,
            'unit_price': unitPrice,
            'location': location,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      _isClearedPermanently = false;
      await _saveMemStateToPrefs();
    } catch (e) {
      debugPrint("Error in registerOrUpdateLocalItem SQLite: $e");
    }
  }

  Future<void> updateItemStockDirectly(String itemCode, double newStock, String reasonNote) async {
    await _ready();
    final nowIso = DateTime.now().toIso8601String().split('T').first;
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      final idx = _memItems.indexWhere((i) => i['code'] == itemCode);
      double oldStock = 0.0;
      if (idx != -1) {
        oldStock = (_memItems[idx]['current_stock'] as num).toDouble();
        _memItems[idx]['current_stock'] = newStock;
      }
      final diff = newStock - oldStock;
      if (diff != 0) {
        await postStockMovement(StockMovementSnapshot(
          transactionId: 'MOV-ADJ-${DateTime.now().millisecondsSinceEpoch}-$itemCode',
          transactionType: diff > 0 ? 'إذن توريد / إضافة مخزون (+)' : 'تسوية / صرف مخزون (-)',
          productCode: itemCode,
          enteredQuantity: diff.abs(),
          enteredUnit: 'حبة',
          conversionFactor: 1.0,
          baseQuantity: diff.abs(),
          baseUnit: 'حبة',
          date: nowIso,
          notes: reasonNote.isNotEmpty ? reasonNote : 'تعديل رصيد المخزون مباشرة',
        ));
      }
      return;
    }

    try {
      final existing = await db.query('items', where: 'code = ?', whereArgs: [itemCode]);
      double oldStock = 0.0;
      if (existing.isNotEmpty) {
        oldStock = (existing.first['current_stock'] as num).toDouble();
      }

      await db.update(
        'items',
        {'current_stock': newStock},
        where: 'code = ?',
        whereArgs: [itemCode],
      );

      await db.insert('audit_logs', {
        'audit_number': 'ADJ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
        'audit_date': nowIso,
        'item_code': itemCode,
        'item_name': 'تعديل مخزون مباشر',
        'system_qty': oldStock,
        'counted_qty': newStock,
        'variance': newStock - oldStock,
        'notes': reasonNote,
      });

      final diff = newStock - oldStock;
      if (diff != 0) {
        await postStockMovement(StockMovementSnapshot(
          transactionId: 'MOV-ADJ-${DateTime.now().millisecondsSinceEpoch}-$itemCode',
          transactionType: diff > 0 ? 'إذن توريد / إضافة مخزون (+)' : 'تسوية / صرف مخزون (-)',
          productCode: itemCode,
          enteredQuantity: diff.abs(),
          enteredUnit: 'حبة',
          conversionFactor: 1.0,
          baseQuantity: diff.abs(),
          baseUnit: 'حبة',
          date: nowIso,
          notes: reasonNote.isNotEmpty ? reasonNote : 'تعديل رصيد المخزون مباشرة',
        ));
      }
    } catch (e) {
      debugPrint("Error updating item stock directly in SQLite: $e");
    }
  }

  Future<void> createSaleOrder(String id, String invoiceNumber, String shopName, double totalAmount, List<Map<String, dynamic>> items) async {
    await _ready();
    final scope = LocalScopeService.key;
    final result = _salesWrites.then((_) async {
      if (scope != LocalScopeService.key) throw StateError('Account or warehouse changed');
      if (id.isEmpty || items.isEmpty || !totalAmount.isFinite || totalAmount < 0) {
        throw ArgumentError('Invalid sale');
      }
      final demand = <String, double>{};
      for (final item in items) {
        final code = item['item_code']?.toString() ?? '';
        final qty = (item['qty'] as num?)?.toDouble() ?? double.nan;
        final base = (item['base_qty'] as num?)?.toDouble() ?? qty;
        final price = (item['unit_price'] as num?)?.toDouble() ?? double.nan;
        if (code.isEmpty || !qty.isFinite || qty <= 0 || !base.isFinite || base <= 0 || !price.isFinite || price < 0) {
          throw ArgumentError('Invalid sale quantity or price');
        }
        demand[code] = (demand[code] ?? 0) + base;
      }
      final date = DateTime.now().toIso8601String().split('T').first;
      final sale = {'id': id, 'invoice_number': invoiceNumber, 'shop_name': shopName,
        'date': date, 'total_amount': totalAmount, 'status': 'completed'};
      final rows = <Map<String, dynamic>>[];
      final movements = <Map<String, dynamic>>[];
      for (var index = 0; index < items.length; index++) {
        final item = items[index];
        final qty = (item['qty'] as num).toDouble();
        final base = (item['base_qty'] as num?)?.toDouble() ?? qty;
        rows.add({'sale_id': id, 'item_code': item['item_code'], 'item_name': item['item_name'],
          'qty': qty, 'base_qty': base, 'unit_price': item['unit_price']});
        movements.add(StockMovementSnapshot(
          transactionId: 'MOV-SALE-' + id + '-' + index.toString(),
          transactionType: 'مبيعات (صرف عميل)', productCode: item['item_code'].toString(),
          enteredQuantity: qty, enteredUnit: item['unit']?.toString() ?? 'حبة',
          conversionFactor: base / qty, baseQuantity: base,
          baseUnit: item['base_unit']?.toString() ?? item['unit']?.toString() ?? 'حبة',
          date: date, notes: 'فاتورة مبيعات #' + invoiceNumber).toMap());
      }
      final db = await database;
      if (db == null) {
        if (_memSales.any((sale) => sale['id'] == id)) throw StateError('Sale already posted');
        for (final entry in demand.entries) {
          final product = _memItems.where((item) => item['code'] == entry.key);
          if (product.isEmpty || (product.first['current_stock'] as num).toDouble() < entry.value) {
            throw StateError('Insufficient stock: ' + entry.key);
          }
        }
        final before = jsonDecode(jsonEncode(_persistedLists)) as Map<String, dynamic>;
        try {
          for (final entry in demand.entries) {
            final product = _memItems.firstWhere((item) => item['code'] == entry.key);
            product['current_stock'] = (product['current_stock'] as num).toDouble() - entry.value;
          }
          _memSales.add({...sale, 'items': items});
          _memSaleItems.addAll(rows);
          _memStockMovements.addAll(movements);
          await _saveMemStateToPrefs();
        } catch (_) {
          for (final entry in _persistedLists.entries) {
            entry.value.clear();
            entry.value.addAll((before[entry.key] as List).map((row) => Map<String, dynamic>.from(row)));
          }
          rethrow;
        }
      } else {
        await db.transaction((txn) async {
          await txn.insert('sales', sale);
          for (final entry in demand.entries) {
            final changed = await txn.rawUpdate('UPDATE items SET current_stock = current_stock - ? WHERE code = ? AND current_stock >= ?',
              [entry.value, entry.key, entry.value]);
            if (changed != 1) throw StateError('Insufficient stock: ' + entry.key);
          }
          for (final row in rows) { await txn.insert('sale_items', row); }
          for (final movement in movements) { await txn.insert('stock_movements', movement); }
        });
      }
      CustomerModel.registerSaleForCustomer(shopName, totalAmount);
    });
    _salesWrites = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    await result;
  }

  Future<List<Map<String, dynamic>>> getSalesForCustomer(String shopName) async {
    await _ready();
    final query = shopName.trim().toLowerCase();
    if (_database == null || _isInMemoryFallback) {
      return _memSales.where((s) {
        final name = (s['shop_name'] as String? ?? '').toLowerCase();
        return name.contains(query) || query.contains(name);
      }).toList();
    }

    final db = await database;
    if (db == null) return [];

    try {
      return await db.query(
        'sales',
        where: 'LOWER(shop_name) LIKE ?',
        whereArgs: ['%$query%'],
      );
    } catch (e) {
      debugPrint("Error getting sales for customer: $e");
      return [];
    }
  }

  Future<void> createReturnInvoice({
    required String id,
    required String returnNumber,
    required String returnType,
    required String partyName,
    required String date,
    required String refundMethod,
    required String notes,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
  }) async {
    await _ready();
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      _memReturns.add({
        'id': id,
        'return_number': returnNumber,
        'return_type': returnType,
        'party_name': partyName,
        'date': date,
        'refund_method': refundMethod,
        'notes': notes,
        'total_amount': totalAmount,
      });

      for (var item in items) {
        final itemCode = item['item_code'].toString();
        final baseQty = (item['base_qty'] as num).toDouble();
        final returnedQty = (item['returned_qty'] as num).toDouble();
        final unit = item['unit']?.toString() ?? 'حبة';

        _memReturnItems.add({
          'return_id': id,
          'item_code': itemCode,
          'item_name': item['item_name'],
          'returned_qty': returnedQty,
          'unit': unit,
          'base_qty': baseQty,
          'unit_price': (item['unit_price'] as num).toDouble(),
          'reason': item['reason'],
        });

        final existingItemIndex = _memItems.indexWhere((i) => i['code'] == itemCode);
        if (existingItemIndex != -1) {
          final currentStock = (_memItems[existingItemIndex]['current_stock'] as num).toDouble();
          final newStock = returnType == 'sales' ? currentStock + baseQty : currentStock - baseQty;
          _memItems[existingItemIndex]['current_stock'] = newStock > 0 ? newStock : 0.0;
        }

        await postStockMovement(StockMovementSnapshot(
          transactionId: 'MOV-RET-${DateTime.now().millisecondsSinceEpoch}-$itemCode',
          transactionType: returnType == 'sales' ? 'مرتجع مبيعات (وارد +)' : 'مرتجع مشتريات (منصرف -)',
          productCode: itemCode,
          enteredQuantity: returnedQty,
          enteredUnit: unit,
          conversionFactor: returnedQty > 0 ? baseQty / returnedQty : 1.0,
          baseQuantity: baseQty,
          baseUnit: unit,
          date: date,
          notes: 'فاتورة مرتجع #$returnNumber - $partyName | ${item['reason'] ?? ''}',
        ));
      }
      return;
    }

    try {
      await db.insert('returns', {
        'id': id,
        'return_number': returnNumber,
        'return_type': returnType,
        'party_name': partyName,
        'date': date,
        'refund_method': refundMethod,
        'notes': notes,
        'total_amount': totalAmount,
      });

      for (var item in items) {
        final itemCode = item['item_code'].toString();
        final baseQty = (item['base_qty'] as num).toDouble();
        final returnedQty = (item['returned_qty'] as num).toDouble();
        final unit = item['unit']?.toString() ?? 'حبة';

        await db.insert('return_items', {
          'return_id': id,
          'item_code': itemCode,
          'item_name': item['item_name'],
          'returned_qty': returnedQty,
          'unit': unit,
          'base_qty': baseQty,
          'unit_price': (item['unit_price'] as num).toDouble(),
          'reason': item['reason'],
        });

        if (returnType == 'sales') {
          await db.rawUpdate('''
            UPDATE items 
            SET current_stock = current_stock + ? 
            WHERE code = ?
          ''', [baseQty, itemCode]);
        } else {
          await db.rawUpdate('''
            UPDATE items 
            SET current_stock = CASE WHEN current_stock >= ? THEN current_stock - ? ELSE 0 END 
            WHERE code = ?
          ''', [baseQty, baseQty, itemCode]);
        }

        await postStockMovement(StockMovementSnapshot(
          transactionId: 'MOV-RET-${DateTime.now().millisecondsSinceEpoch}-$itemCode',
          transactionType: returnType == 'sales' ? 'مرتجع مبيعات (وارد +)' : 'مرتجع مشتريات (منصرف -)',
          productCode: itemCode,
          enteredQuantity: returnedQty,
          enteredUnit: unit,
          conversionFactor: returnedQty > 0 ? baseQty / returnedQty : 1.0,
          baseQuantity: baseQty,
          baseUnit: unit,
          date: date,
          notes: 'فاتورة مرتجع #$returnNumber - $partyName | ${item['reason'] ?? ''}',
        ));
      }
    } catch (e) {
      debugPrint("Error creating return invoice in SQLite: $e");
    }
  }

  Future<List<Map<String, dynamic>>> getReturnInvoices() async {
    await _ready();
    if (_database == null || _isInMemoryFallback) {
      await _initMemData();
      return List.from(_memReturns);
    }
    final db = await database;
    if (db == null) return [];
    try {
      return await db.query('returns', orderBy: 'date DESC');
    } catch (e) {
      debugPrint("Error getting return invoices: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getReturnItems(String returnId) async {
    await _ready();
    if (_database == null || _isInMemoryFallback) {
      return _memReturnItems.where((i) => i['return_id'] == returnId).toList();
    }
    final db = await database;
    if (db == null) return [];
    try {
      return await db.query('return_items', where: 'return_id = ?', whereArgs: [returnId]);
    } catch (e) {
      debugPrint("Error getting return items: $e");
      return [];
    }
  }

  Future<void> clearAllDatabaseData() async {
    await _ready();
    _isClearedPermanently = true;
    _isMemInitialized = true;

    final db = await database;
    if (db != null) {
      try { await db.delete('items'); } catch (_) {}
      try { await db.delete('transfers'); } catch (_) {}
      try { await db.delete('transfer_items'); } catch (_) {}
      try { await db.delete('audit_logs'); } catch (_) {}
      try { await db.delete('product_units'); } catch (_) {}
      try { await db.delete('stock_movements'); } catch (_) {}
      try { await db.delete('returns'); } catch (_) {}
      try { await db.delete('return_items'); } catch (_) {}
      try { await db.delete('sales'); } catch (_) {}
      try { await db.delete('sale_items'); } catch (_) {}
      try { await db.delete('customers'); } catch (_) {}
      try { await db.delete('customer_payments'); } catch (_) {}
    }

    _clearAllMemLists();
    CustomerModel.clearAllCustomers();

    await _saveMemStateToPrefs();
  }


  Future<Uint8List?> getDatabaseBytes() async {
    await _ready();
    try {
      if (kIsWeb) return null;
      String path = join(await getDatabasesPath(), 'benaa_inventory.db');
      final file = File(path);
      if (await file.exists()) {
        return await file.readAsBytes();
      }
    } catch (e) {
      debugPrint("Failed to read database bytes: $e");
    }
    return null;
  }

  /// Delete item from local stock
  Future<void> deleteItem(String code) async {
    await _ready();
    final db = await database;
    if (db == null || _isInMemoryFallback) {
      _memItems.removeWhere((i) => i['code'] == code);
      await _saveMemStateToPrefs();
      return;
    }
    try {
      await db.delete('items', where: 'code = ?', whereArgs: [code]);
      await db.delete('product_units', where: 'product_code = ?', whereArgs: [code]);
      _memItems.removeWhere((i) => i['code'] == code);
      await _saveMemStateToPrefs();
    } catch (e) {
      debugPrint("Error deleting item $code: $e");
    }
  }

  /// Safe Void / Cancellation of a Sale Invoice:
  /// 1. Restores sold quantities back to item stock
  /// 2. Reduces customer debt balance
  /// 3. Deletes the invoice
  Future<bool> voidSaleInvoice(int saleId) async {
    await _ready();
    if (_database == null || _isInMemoryFallback) {
      final saleIndex = _memSales.indexWhere((s) => s['id'] == saleId);
      if (saleIndex == -1) return false;
      final sale = _memSales[saleIndex];
      final shopName = sale['shop_name'];
      final totalAmount = (sale['total_amount'] as num).toDouble();

      // Restore items stock
      final items = _memSaleItems.where((i) => i['sale_id'] == saleId).toList();
      for (var it in items) {
        final itmIdx = _memItems.indexWhere((m) => m['code'] == it['item_code']);
        if (itmIdx != -1) {
          _memItems[itmIdx]['current_stock'] = (_memItems[itmIdx]['current_stock'] as num).toDouble() + (it['qty'] as num).toDouble();
        }
      }

      // Revert customer balance
      final custIdx = _memCustomers.indexWhere((c) => c['name'] == shopName);
      if (custIdx != -1) {
        final curBal = (_memCustomers[custIdx]['current_balance'] as num).toDouble();
        _memCustomers[custIdx]['current_balance'] = (curBal - totalAmount).clamp(0.0, double.infinity);
      }

      _memSaleItems.removeWhere((i) => i['sale_id'] == saleId);
      _memSales.removeAt(saleIndex);
      return true;
    }

    final db = await database;
    if (db == null) return false;

    try {
      final saleMaps = await db.query('sales', where: 'id = ?', whereArgs: [saleId]);
      if (saleMaps.isEmpty) return false;

      final sale = saleMaps.first;
      final shopName = sale['shop_name'].toString();
      final totalAmount = (sale['total_amount'] as num).toDouble();

      // Get sale items
      final saleItems = await db.query('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);

      // 1. Restock each item
      for (var it in saleItems) {
        final itemCode = it['item_code'].toString();
        final qty = (it['qty'] as num).toDouble();
        await db.rawUpdate('''
          UPDATE items 
          SET current_stock = current_stock + ? 
          WHERE code = ?
        ''', [qty, itemCode]);
      }

      // 2. Adjust customer balance
      await db.rawUpdate('''
        UPDATE customers 
        SET current_balance = MAX(0.0, current_balance - ?) 
        WHERE name = ?
      ''', [totalAmount, shopName]);

      // 3. Delete sale items and sale invoice
      await db.delete('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
      await db.delete('sales', where: 'id = ?', whereArgs: [saleId]);

      return true;
    } catch (e) {
      debugPrint("Error voiding sale invoice: $e");
      return false;
    }
  }

  /// Safe Void of a Customer Payment:
  /// 1. Re-adds the paid amount back into customer debt
  /// 2. Deletes the payment record
  Future<bool> voidCustomerPayment(int paymentId) async {
    await _ready();
    if (_database == null || _isInMemoryFallback) {
      final pIndex = _memCustomerPayments.indexWhere((p) => p['id'] == paymentId);
      if (pIndex == -1) return false;
      final payment = _memCustomerPayments[pIndex];
      final custName = payment['customer_name'];
      final amount = (payment['amount_paid'] as num).toDouble();

      final custIdx = _memCustomers.indexWhere((c) => c['name'] == custName);
      if (custIdx != -1) {
        _memCustomers[custIdx]['current_balance'] = (_memCustomers[custIdx]['current_balance'] as num).toDouble() + amount;
      }
      _memCustomerPayments.removeAt(pIndex);
      return true;
    }

    final db = await database;
    if (db == null) return false;

    try {
      final pMaps = await db.query('customer_payments', where: 'id = ?', whereArgs: [paymentId]);
      if (pMaps.isEmpty) return false;

      final payment = pMaps.first;
      final custName = payment['customer_name'].toString();
      final amount = (payment['amount_paid'] as num).toDouble();

      // Re-add to debt
      await db.rawUpdate('''
        UPDATE customers 
        SET current_balance = current_balance + ? 
        WHERE name = ?
      ''', [amount, custName]);

      await db.delete('customer_payments', where: 'id = ?', whereArgs: [paymentId]);
      return true;
    } catch (e) {
      debugPrint("Error voiding payment: $e");
      return false;
    }
  }

  /// Delete Transfer Voucher
  Future<void> deleteTransfer(String transferId) async {
    await _ready();
    if (_database == null || _isInMemoryFallback) {
      _memTransfers.removeWhere((t) => t['id'] == transferId);
      _memTransferItems.removeWhere((i) => i['transfer_id'] == transferId);
      return;
    }

    final db = await database;
    if (db == null) return;

    try {
      await db.delete('transfer_items', where: 'transfer_id = ?', whereArgs: [transferId]);
      await db.delete('transfers', where: 'id = ?', whereArgs: [transferId]);
    } catch (e) {
      debugPrint("Error deleting transfer: $e");
    }
  }
}
