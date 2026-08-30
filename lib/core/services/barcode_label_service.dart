import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/item_model.dart';

class BarcodeLabelService {
  static Future<void> printThermalStickerLabel({
    required ItemModel item,
    int copies = 1,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    // Standard 50mm x 30mm Thermal Sticker Label Size
    final pageFormat = PdfPageFormat(50 * PdfPageFormat.mm, 30 * PdfPageFormat.mm);

    for (int i = 0; i < copies; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(3),
          build: (pw.Context context) {
            return pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.black, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                padding: const pw.EdgeInsets.all(4),
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      'مؤسسة Benaa للتوريدات',
                      style: pw.TextStyle(font: font, fontSize: 6, color: PdfColors.grey700),
                    ),
                    pw.Text(
                      item.name,
                      style: pw.TextStyle(font: fontBold, fontSize: 8),
                      textAlign: pw.TextAlign.center,
                      maxLines: 1,
                    ),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.code128(),
                      data: item.code,
                      width: 120,
                      height: 20,
                      drawText: true,
                      textStyle: pw.TextStyle(font: font, fontSize: 7),
                    ),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('كود: ${item.code}', style: pw.TextStyle(font: font, fontSize: 6)),
                        pw.Text('الوحدة: ${item.unit}', style: pw.TextStyle(font: font, fontSize: 6)),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Sticker_${item.code}',
    );
  }
}
