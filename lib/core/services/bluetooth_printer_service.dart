import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../../data/models/transfer_model.dart';
import '../../data/models/sale_order_model.dart';
import 'haptics_service.dart';

class BluetoothPrinterService {
  static final BlueThermalPrinter _bluetooth = BlueThermalPrinter.instance;

  /// Get list of paired Bluetooth devices
  static Future<List<BluetoothDevice>> getPairedDevices() async {
    try {
      return await _bluetooth.getBondedDevices();
    } catch (_) {
      return [];
    }
  }

  /// Check if printer is connected
  static Future<bool> isConnected() async {
    try {
      return (await _bluetooth.isConnected) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Connect to Bluetooth Thermal Printer
  static Future<bool> connect(BluetoothDevice device) async {
    try {
      await _bluetooth.connect(device);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Disconnect printer
  static Future<void> disconnect() async {
    try {
      await _bluetooth.disconnect();
    } catch (_) {}
  }

  /// Print Transfer Audit Receipt Voucher
  static Future<void> printTransferAuditVoucher(TransferModel transfer, String gpsLocation) async {
    try {
      bool connected = await isConnected();
      if (!connected) return;

      await HapticsService.actionSuccess();

      // Printer Header
      _bluetooth.printNewLine();
      _bluetooth.printCustom("================================", 1, 1);
      _bluetooth.printCustom("BENAA WAREHOUSE LOGISTICS", 2, 1);
      _bluetooth.printCustom("مستودع Benaa للمواد والديكور", 2, 1);
      _bluetooth.printCustom("فرع القصيم - بريدة", 1, 1);
      _bluetooth.printCustom("================================", 1, 1);
      _bluetooth.printNewLine();

      // Voucher details
      _bluetooth.printCustom("سند مطابقة وجرد شحنة واردة", 1, 1);
      _bluetooth.printCustom("رقم التحويل: ${transfer.transferNumber}", 1, 0);
      _bluetooth.printCustom("المصدر: ${transfer.fromWarehouse}", 1, 0);
      _bluetooth.printCustom("الوجهة: ${transfer.toWarehouse}", 1, 0);
      _bluetooth.printCustom("التاريخ: ${transfer.date}", 1, 0);
      _bluetooth.printCustom("المحرر: ${transfer.author}", 1, 0);
      _bluetooth.printCustom(gpsLocation, 0, 0);
      _bluetooth.printCustom("حالة الجرد: ${transfer.status == 'audited_matched' ? 'مطابق 100%' : 'عجز/فروقات'}", 1, 0);
      _bluetooth.printCustom("--------------------------------", 1, 1);

      // Line items
      for (var item in transfer.items) {
        _bluetooth.printCustom("${item.itemCode} - ${item.itemName}", 1, 0);
        _bluetooth.printCustom("المتوقع: ${item.expectedQty} | الفعلي: ${item.actualQty}", 0, 0);
      }

      _bluetooth.printCustom("--------------------------------", 1, 1);
      _bluetooth.printCustom("توقيع أمين المستودع: ............", 1, 1);
      _bluetooth.printNewLine();
      _bluetooth.printNewLine();
      _bluetooth.paperCut();
    } catch (_) {}
  }

  /// Print Sales Issuance Receipt
  static Future<void> printSalesIssuanceReceipt(
    SaleOrderModel saleOrder,
    String gpsLocation,
  ) async {
    try {
      bool connected = await isConnected();
      if (!connected) return;

      await HapticsService.actionSuccess();

      _bluetooth.printNewLine();
      _bluetooth.printCustom("================================", 1, 1);
      _bluetooth.printCustom("BENAA CONSTRUCTION MATERIALS", 2, 1);
      _bluetooth.printCustom("إذن صرف وتوزيع للمحلات والعملاء", 1, 1);
      _bluetooth.printCustom("================================", 1, 1);
      _bluetooth.printNewLine();

      _bluetooth.printCustom("رقم الفاتورة: ${saleOrder.invoiceNumber}", 1, 0);
      _bluetooth.printCustom("العميل / المحل: ${saleOrder.shopName}", 1, 0);
      _bluetooth.printCustom("التاريخ: ${saleOrder.date}", 1, 0);
      _bluetooth.printCustom(gpsLocation, 0, 0);
      _bluetooth.printCustom("--------------------------------", 1, 1);

      for (var item in saleOrder.items) {
        _bluetooth.printCustom("${item.itemName} x${item.qty}", 1, 0);
        _bluetooth.printCustom("الإجمالي: ${item.totalPrice} ريال", 0, 0);
      }

      _bluetooth.printCustom("--------------------------------", 1, 1);
      _bluetooth.printCustom("المبلغ الإجمالي: ${saleOrder.totalAmount} ريال", 2, 1);
      _bluetooth.printCustom("شكراً لتعاملكم مع شركة Benaa", 1, 1);
      _bluetooth.printNewLine();
      _bluetooth.printNewLine();
      _bluetooth.paperCut();
    } catch (_) {}
  }
}
