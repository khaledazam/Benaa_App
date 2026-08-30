import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  /// Initialize local notification channels & permissions
  static Future<void> init() async {
    if (_isInitialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings darwinSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _notificationsPlugin.initialize(initSettings);

    // Create Android High Importance Notification Channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'benaa_inventory_channel',
      'إشعارات نظام Benaa للمخازن',
      description: 'إشعارات الباركود والجرد والمزامنة مع الـ CRM',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _isInitialized = true;
  }

  /// Trigger notification when a barcode is scanned via camera
  static Future<void> showScanNotification({
    required String barcode,
    required String itemName,
    required String statusText,
  }) async {
    await init();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'benaa_inventory_channel',
      'إشعارات نظام Benaa للمخازن',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '📷 تم مسح الباركود: $barcode',
      '$itemName — $statusText',
      details,
    );
  }

  /// Trigger notification for stock discrepancy / shortage alert
  static Future<void> showDiscrepancyAlert({
    required String transferNumber,
    required int discrepancyCount,
  }) async {
    await init();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'benaa_inventory_channel',
      'إشعارات نظام Benaa للمخازن',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '⚠️ تنبيه فروقات جرد — فاتورة #$transferNumber',
      'تم اكتشاف فروقات وعجز في $discrepancyCount أصناف أثناء المطابقة!',
      details,
    );
  }

  /// Trigger notification for completed audit
  static Future<void> showAuditCompleteNotification({
    required String transferNumber,
  }) async {
    await init();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'benaa_inventory_channel',
      'إشعارات نظام Benaa للمخازن',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '✅ تم اعتماد الجرد بنجاح',
      'تم إدخال محتويات فاتورة #$transferNumber لرصيد مستودع بريدة',
      details,
    );
  }

  /// Trigger notification for CRM sync completion
  static Future<void> showSyncNotification({
    required String title,
    required String body,
  }) async {
    await init();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'benaa_inventory_channel',
      'إشعارات نظام Benaa للمخازن',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  /// Trigger notification when low stock is detected
  static Future<void> showLowStockAlertNotification({
    required int lowStockCount,
    required String sampleItemName,
  }) async {
    await init();
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'benaa_inventory_channel',
      'إشعارات نظام Benaa للمخازن',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      '⚠️ تحذير: أصناف وشيكة النفاذ في مستودع بريدة',
      'يوجد $lowStockCount أصناف (مثل: $sampleItemName) قل رصيدها عن الحد الآمن!',
      details,
    );
  }
}
