import 'dart:convert';
import 'local_scope_service.dart';
import 'cloud_auth_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum AiCategory { inventory, sales, financial }
enum AiSeverity { high, medium, low }

class BenaaAiInsight {
  final String id;
  final AiCategory category;
  final AiSeverity severity;
  final String title;
  final String description;
  final String recommendedAction;
  final String actionRoute;
  final Map<String, dynamic> metrics;
  final String createdAt;
  final bool isCloudAiGenerated;
  final String provider;
  bool isRead;

  BenaaAiInsight({
    required this.id,
    required this.category,
    required this.severity,
    required this.title,
    required this.description,
    required this.recommendedAction,
    required this.actionRoute,
    this.metrics = const {},
    required this.createdAt,
    this.isCloudAiGenerated = true,
    this.provider = 'NaraRouter (nemotron-3.5-lightning-free)',
    this.isRead = false,
  });

  factory BenaaAiInsight.fromJson(Map<String, dynamic> json) {
    AiCategory cat = AiCategory.inventory;
    if (json['category'] == 'sales') cat = AiCategory.sales;
    if (json['category'] == 'financial') cat = AiCategory.financial;

    AiSeverity sev = AiSeverity.medium;
    if (json['severity'] == 'high') sev = AiSeverity.high;
    if (json['severity'] == 'low') sev = AiSeverity.low;

    return BenaaAiInsight(
      id: json['id'] ?? 'ai-${DateTime.now().millisecondsSinceEpoch}',
      category: cat,
      severity: sev,
      title: json['title'] ?? 'تنبيه ذكاء بناء',
      description: json['description'] ?? '',
      recommendedAction: json['recommendedAction'] ?? 'اتخاذ الإجراء',
      actionRoute: json['actionRoute'] ?? '/inventory',
      metrics: json['metrics'] is Map ? Map<String, dynamic>.from(json['metrics']) : {},
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
      isCloudAiGenerated: json['isCloudAiGenerated'] ?? false,
      provider: json['provider'] ?? 'NaraRouter (nemotron-3.5-lightning-free)',
      isRead: json['isRead'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category.name,
      'severity': severity.name,
      'title': title,
      'description': description,
      'recommendedAction': recommendedAction,
      'actionRoute': actionRoute,
      'metrics': metrics,
      'createdAt': createdAt,
      'isCloudAiGenerated': isCloudAiGenerated,
      'provider': provider,
      'isRead': isRead,
    };
  }
}

/// Service managing Benaa Intelligence AI notifications and NaraRouter sync
class BenaaAiService extends ChangeNotifier {
  static final BenaaAiService _instance = BenaaAiService._internal();
  factory BenaaAiService() => _instance;
  BenaaAiService._internal();

  static const List<String> _endpoints = [
    'http://localhost:3002/api/ai/benaa-intelligence',
    'http://localhost:3000/api/ai/benaa-intelligence',
  ];
  static const String _spCacheKey = 'benaa_ai_cached_insights';
  static const String _spLastAnalysisKey = 'benaa_ai_last_analysis_time';

  List<BenaaAiInsight> _insights = [];
  String _scope = LocalScopeService.key;
  void _ensureScope() {
    if (_scope == LocalScopeService.key) return;
    _scope = LocalScopeService.key;
    _insights = [];
    _lastAnalysisTime = '';
  }
  bool _isLoading = false;
  bool _isOffline = false;
  String _lastAnalysisTime = 'منذ قليل';
  String _providerName = 'NaraRouter (nemotron-3.5-lightning-free)';

  List<BenaaAiInsight> get insights { _ensureScope(); return _insights; }
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  String get lastAnalysisTime => _lastAnalysisTime;
  String get providerName => _providerName;

  int get unreadCount => _insights.where((i) => !i.isRead).length;
  int get highSeverityCount => _insights.where((i) => i.severity == AiSeverity.high).length;

  /// Initialize service and load cached insights for offline resilience
  Future<void> initialize() async {
    await _loadFromLocalCache();
    // Silent fresh fetch
    fetchInsights(silent: true);
  }

  /// Fetch insights from Next.js / NaraRouter backend with offline fallback
  Future<void> fetchInsights({bool forceRefresh = false, bool silent = false}) async {
    _ensureScope();
    final requestScope = LocalScopeService.key;
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      http.Response? response;
      for (final endpoint in _endpoints) {
        try {
          final res = await (forceRefresh
              ? http.post(
                  Uri.parse(endpoint),
                  headers: await CloudAuthService.authenticatedHeaders(),
                  body: jsonEncode({'action': 'analyze_now'}),
                )
              : http.get(Uri.parse(endpoint), headers: await CloudAuthService.authenticatedHeaders()))
              .timeout(const Duration(seconds: 6));
          if (res.statusCode == 200) {
            response = res;
            break;
          }
        } catch (_) {}
      }

      if (response != null && response.statusCode == 200) {
        if (requestScope != LocalScopeService.key) return;
        final data = jsonDecode(response.body);
        final List<dynamic> list = data['insights'] ?? [];
        _insights = list.map((e) => BenaaAiInsight.fromJson(e)).toList();
        _providerName = data['provider'] ?? 'NaraRouter (nemotron-3.5-lightning-free)';
        _lastAnalysisTime = _formatTime(data['lastAnalysisTime']);
        _isOffline = false;

        await _saveToLocalCache();
      } else {
        await _fallbackToLocalCache();
      }
    } catch (e) {
      debugPrint('[Benaa AI] Network failure, using local cache: $e');
      await _fallbackToLocalCache();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Mark insight as read
  Future<void> markAsRead(String id) async {
    final idx = _insights.indexWhere((i) => i.id == id);
    if (idx != -1) {
      _insights[idx].isRead = true;
      notifyListeners();
      await _saveToLocalCache();

      // Silent sync with backend
      try {
        http.post(
          Uri.parse(_endpoints.first),
          headers: await CloudAuthService.authenticatedHeaders(),
          body: jsonEncode({'action': 'mark_read', 'insightId': id}),
        );
      } catch (_) {}
    }
  }

  /// Dismiss insight
  Future<void> dismissInsight(String id) async {
    _insights.removeWhere((i) => i.id == id);
    notifyListeners();
    await _saveToLocalCache();

    try {
      http.post(
        Uri.parse(_endpoints.first),
        headers: await CloudAuthService.authenticatedHeaders(),
        body: jsonEncode({'action': 'dismiss', 'insightId': id}),
      );
    } catch (_) {}
  }

  /// Mark all insights as read
  Future<void> markAllAsRead() async {
    for (var i in _insights) {
      i.isRead = true;
    }
    notifyListeners();
    await _saveToLocalCache();
  }

  Future<void> _saveToLocalCache() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final str = jsonEncode(_insights.map((i) => i.toJson()).toList());
      await sp.setString(LocalScopeService.preferenceKey(_spCacheKey), str);
      await sp.setString(LocalScopeService.preferenceKey(_spLastAnalysisKey), _lastAnalysisTime);
    } catch (_) {}
  }

  Future<void> _loadFromLocalCache() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final str = sp.getString(LocalScopeService.preferenceKey(_spCacheKey));
      _lastAnalysisTime = sp.getString(LocalScopeService.preferenceKey(_spLastAnalysisKey)) ?? 'مخزن محلياً';

      if (str != null && str.isNotEmpty) {
        final List<dynamic> list = jsonDecode(str);
        _insights = list.map((e) => BenaaAiInsight.fromJson(e)).toList();
      } else {
        _insights = [];
      }
    } catch (_) {
      _insights = [];
    }
  }

  Future<void> _fallbackToLocalCache() async {
    _isOffline = true;
    if (_insights.isEmpty) {
      await _loadFromLocalCache();
    }
  }

  void _seedDefaultInsights() {
    final now = DateTime.now().toIso8601String();
    _insights = [
      BenaaAiInsight(
        id: 'ai-default-1',
        category: AiCategory.inventory,
        severity: AiSeverity.high,
        title: 'تنبيه نفاد وشيك: جبس بورد مقاوم للرطوبة (خلال 3 أيام)',
        description: 'استناداً إلى متوسط معدل السحب (4 ألواح/يوم)، سينفد المخزون الحالي (12 لوحاً) قريباً. الكمية المقترحة لإعادة الطلب: 80 لوحاً.',
        recommendedAction: 'إصدار طلب شراء وتوريد عاجل',
        actionRoute: '/inventory?filter=low_stock',
        createdAt: now,
        isCloudAiGenerated: false,
        provider: 'Benaa Engine (Offline Cache)',
      ),
      BenaaAiInsight(
        id: 'ai-default-2',
        category: AiCategory.financial,
        severity: AiSeverity.high,
        title: 'أولوية تحصيل قصوى: مؤسسة إعمار نجد للمقاولات',
        description: 'تجاوزت مديونية العميل سقف التسهيلات برصيد مستحق قدره 18,500 ر.س. يُوصى بجدولة الدفعة أو الاتصال فوراً قبل أي صرف آجل جديد.',
        recommendedAction: 'مراجعة كشف الحساب والاتصال',
        actionRoute: '/customers',
        createdAt: now,
        isCloudAiGenerated: false,
        provider: 'Benaa Engine (Offline Cache)',
      ),
      BenaaAiInsight(
        id: 'ai-default-3',
        category: AiCategory.inventory,
        severity: AiSeverity.medium,
        title: 'عجز كميات مسجل أثناء التدقيق: صوف زجاجي 50 مم',
        description: 'تم رصد فارق قدره (2 لفة) بين السند الأصلي والمستلم فعلياً في شحنة جدة الأخيرة. يُنصح بمطابقة بوليصة الشحن مع الناقل.',
        recommendedAction: 'مراجعة سند الشحن ومطابقة العجز',
        actionRoute: '/transfers?filter=discrepancy',
        createdAt: now,
        isCloudAiGenerated: false,
        provider: 'Benaa Engine (Offline Cache)',
      ),
      BenaaAiInsight(
        id: 'ai-default-4',
        category: AiCategory.sales,
        severity: AiSeverity.low,
        title: 'الصنف الأعلى مبيعاً وطلباً: بلاط دبيس 60*60 رمادي',
        description: 'حقق الصنف أعلى حركة صرف خلال الأسبوع مع نمو +14.8%. الرصيد المتبقي مستقر وكافٍ للمشاريع القائمة.',
        recommendedAction: 'متابعة حركة الصرف والمبيعات',
        actionRoute: '/sales',
        createdAt: now,
        isCloudAiGenerated: false,
        provider: 'Benaa Engine (Offline Cache)',
      ),
    ];
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return 'منذ قليل';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return 'اليوم';
    }
  }
}
