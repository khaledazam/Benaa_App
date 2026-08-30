import 'package:printing/printing.dart';
import 'pdf_report_service.dart';
import '../database/db_helper.dart';
import '../../data/models/item_model.dart';

class ShareService {
  static Future<void> shareStockReportPdf({
    required List<ItemModel> items,
    required double totalValuation,
    required int lowStockCount,
  }) async {
    final pdfBytes = await PdfReportService.generateInventoryPdfReport(
      items: items,
      totalValuation: totalValuation,
      lowStockCount: lowStockCount,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Benaa_Inventory_Report_${DateTime.now().toIso8601String().split('T').first}.pdf',
    );
  }

  /// Export & Share SQLite database file (.db) to phone Downloads/Files/WhatsApp
  static Future<bool> exportDatabaseBackup() async {
    final bytes = await DBHelper().getDatabaseBytes();
    if (bytes != null && bytes.isNotEmpty) {
      final dateStr = DateTime.now().toIso8601String().split('T').first;
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'benaa_inventory_backup_$dateStr.db',
      );
      return true;
    }
    return false;
  }
}
