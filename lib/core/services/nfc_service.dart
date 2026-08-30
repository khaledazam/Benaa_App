import 'package:nfc_manager/nfc_manager.dart';
import 'haptics_service.dart';
import 'notification_service.dart';

class NfcService {
  /// Check if NFC hardware is supported and enabled on the device
  static Future<bool> isNfcAvailable() async {
    try {
      return await NfcManager.instance.isAvailable();
    } catch (_) {
      return false;
    }
  }

  /// Start scanning for NFC / RFID tags (Pallets & Items)
  static Future<void> startNfcScan({
    required Function(String nfcCode) onTagDiscovered,
    required Function(String errorText) onError,
  }) async {
    bool available = await isNfcAvailable();
    if (!available) {
      onError('خاصية الـ NFC / RFID غير متوفرة أو غير مفعّلة في إعدادات الهاتف');
      return;
    }

    try {
      NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final String tagId = tag.data['nfca']?['identifier']?.toString() ??
                tag.data['mifare']?['identifier']?.toString() ??
                'NFC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

            await HapticsService.scanSuccess();
            await NotificationService.showScanNotification(
              barcode: tagId,
              itemName: 'كرت / باليت NFC رماد',
              statusText: 'تم الكشف بواسطة مستشعر الـ NFC بالهاتف',
            );

            onTagDiscovered(tagId);
            stopNfcScan();
          } catch (e) {
            onError('خطأ أثناء قراءة بيانات الـ NFC: $e');
            stopNfcScan();
          }
        },
      );
    } catch (e) {
      onError('تعذر بدء جلسة مسح الـ NFC: $e');
    }
  }

  /// Stop active NFC scanning session
  static Future<void> stopNfcScan() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }
}
