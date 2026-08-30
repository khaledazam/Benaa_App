import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../data/models/item_model.dart';

class PdfReportService {
  static Future<pw.Font> _loadFont() async {
    try {
      return await PdfGoogleFonts.cairoMedium();
    } catch (_) {
      try {
        return await PdfGoogleFonts.amiriRegular();
      } catch (_) {
        return pw.Font.helvetica();
      }
    }
  }

  /// Generate a PDF Inventory Summary Report for Buraidah Warehouse
  static Future<Uint8List> generateInventoryPdfReport({
    required List<ItemModel> items,
    required double totalValuation,
    required int lowStockCount,
  }) async {
    final pdf = pw.Document();
    final font = await _loadFont();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Report Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('شركة Benaa لإدارة المواد والديكور', style: pw.TextStyle(font: font, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                        pw.Text('تقرير رصيد وتقييم مستودع بريدة (القصيم)', style: pw.TextStyle(font: font, fontSize: 13, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('التاريخ: ${DateTime.now().toIso8601String().split('T').first}', style: pw.TextStyle(font: font, fontSize: 11)),
                        pw.Text('التوقيت: ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}', style: pw.TextStyle(font: font, fontSize: 11)),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 15),
                pw.Divider(),
                pw.SizedBox(height: 10),

                // Summary Stats Boxes
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    _buildPdfStatBox('إجمالي الأصناف', '${items.length} صنف', font),
                    _buildPdfStatBox('الأصناف وشيكة النفاذ', '$lowStockCount صنف', font, color: PdfColors.red700),
                    _buildPdfStatBox('إجمالي قيمة المخزون', '${totalValuation.toStringAsFixed(0)} ر.س', font, color: PdfColors.green700),
                  ],
                ),

                pw.SizedBox(height: 20),
                pw.Text('تفاصيل أصناف المخزون:', style: pw.TextStyle(font: font, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),

                // Inventory Table
                pw.TableHelper.fromTextArray(
                  context: context,
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                  headerStyle: pw.TextStyle(font: font, fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo800),
                  cellStyle: pw.TextStyle(font: font, fontSize: 9),
                  cellAlignment: pw.Alignment.centerRight,
                  headers: ['كود الصنف', 'اسم المنتَج', 'التصنيف', 'الرصيد المتاح', 'السعر التقديري (ر.س)', 'القيمة الإجمالية'],
                  data: items.map((item) {
                    final itemPrice = 50.0; // default estimated unit price
                    final itemTotal = item.currentStock * itemPrice;
                    return [
                      item.code,
                      item.name,
                      item.category,
                      '${item.currentStock.toInt()} ${item.unit}',
                      '$itemPrice ر.س',
                      '${itemTotal.toStringAsFixed(0)} ر.س',
                    ];
                  }).toList(),
                ),

                pw.Spacer(),

                // Signature section
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('توقيع أمين المستودع: ....................', style: pw.TextStyle(font: font, fontSize: 10)),
                    pw.Text('توقيع مدير المخازن: ....................', style: pw.TextStyle(font: font, fontSize: 10)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildPdfStatBox(String title, String value, pw.Font font, {PdfColor color = PdfColors.indigo900}) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 1),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(title, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  /// Print or Display PDF Layout
  static Future<void> printOrPreviewReport({
    required List<ItemModel> items,
    required double totalValuation,
    required int lowStockCount,
  }) async {
    final pdfBytes = await generateInventoryPdfReport(
      items: items,
      totalValuation: totalValuation,
      lowStockCount: lowStockCount,
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'تقرير_مخزون_Benaa_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  /// Generate CSV string format for Excel export
  static String generateCsvReport(List<ItemModel> items) {
    final StringBuffer csv = StringBuffer();
    csv.writeln('كود الصنف,اسم المنتج,التصنيف,الوحدة,الرصيد المتاح,سعر التكلفة التقديري,القيمة الإجمالية');

    for (var item in items) {
      final unitPrice = 50.0;
      final total = item.currentStock * unitPrice;
      csv.writeln('"${item.code}","${item.name}","${item.category}","${item.unit}",${item.currentStock},$unitPrice,$total');
    }

    return csv.toString();
  }

  /// Generate a Sale Invoice / Receipt PDF matching user's exact uploaded image format
  static Future<Uint8List> generateSaleInvoicePdf({
    required String invoiceNumber,
    required String shopName,
    required String date,
    required double totalAmount,
    required List<Map<String, dynamic>> items,
    bool isVatEnabled = true,
    String companyName = 'شركة إطار ديكور',
    String companyPhone = '0547903880',
    String companyVat = '314572523900003',
    String companyCr = '7053410572',
    String customerPhone = '0555837753',
    String customerVat = '302196026800003',
    String customerAddress = '05393 بريدة الشارع الشرقي',
    double previousBalance = 30288.00,
  }) async {
    final pdf = pw.Document();
    final font = await _loadFont();

    // Calculations
    final double netTotal = items.fold(0.0, (sum, i) {
      final qty = (i['qty'] as num?)?.toDouble() ?? 0.0;
      final price = (i['unit_price'] as num?)?.toDouble() ?? (i['price'] as num?)?.toDouble() ?? 0.0;
      return sum + (qty * price);
    });
    final double vatAmount = isVatEnabled ? (netTotal * 0.15) : 0.0;
    final double invoiceTotal = netTotal + vatAmount;
    final double currentBalance = previousBalance + invoiceTotal;
    final int itemsCount = items.length;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.2),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // --- Header Layout: Side-by-side Boxes (Matches Image Header) ---
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Right Box: Customer & Invoice Details Table
                      pw.Expanded(
                        flex: 5,
                        child: pw.Table(
                          border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
                          columnWidths: {
                            0: const pw.FlexColumnWidth(3),
                            1: const pw.FlexColumnWidth(1.2),
                          },
                          children: [
                            pw.TableRow(
                              children: [
                                pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(invoiceNumber, style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                                pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('رقم الفاتورة', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                              ],
                            ),
                            pw.TableRow(
                              children: [
                                pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(date, style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center)),
                                pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('التاريخ', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                              ],
                            ),
                            pw.TableRow(
                              children: [
                                pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(shopName, style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                                pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('الاسم', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                              ],
                            ),
                            pw.TableRow(
                              children: [
                                pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(customerPhone, style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center)),
                                pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('تليفون العميل', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                              ],
                            ),
                            pw.TableRow(
                              children: [
                                pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(customerVat, style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center)),
                                pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('الرقم الضريبي للعميل', style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                              ],
                            ),
                            pw.TableRow(
                              children: [
                                pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(customerAddress, style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center)),
                                pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('العنوان', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      // Left Box: Company Information
                      pw.Expanded(
                        flex: 4,
                        child: pw.Container(
                          padding: const pw.EdgeInsets.all(8),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.black, width: 0.8),
                          ),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text(companyName, style: pw.TextStyle(font: font, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 6),
                              pw.Text('Mob: $companyPhone', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 6),
                              pw.Text('VAT NO . $companyVat', style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 6),
                              pw.Text('C.R $companyCr', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 10),

                  // --- Items Table (Matches Image Columns) ---
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.2), // ملاحظات
                      1: const pw.FlexColumnWidth(1.2), // الإجمالي
                      2: const pw.FlexColumnWidth(1),   // السعر
                      3: const pw.FlexColumnWidth(1),   // الكمية
                      4: const pw.FlexColumnWidth(3),   // الصنف
                      5: const pw.FlexColumnWidth(0.6), // م
                    },
                    children: [
                      // Header Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Container(padding: const pw.EdgeInsets.all(5), child: pw.Text('ملاحظات', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                          pw.Container(padding: const pw.EdgeInsets.all(5), child: pw.Text('الإجمالي', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                          pw.Container(padding: const pw.EdgeInsets.all(5), child: pw.Text('السعر', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                          pw.Container(padding: const pw.EdgeInsets.all(5), child: pw.Text('الكمية', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                          pw.Container(padding: const pw.EdgeInsets.all(5), child: pw.Text('الصنف', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                          pw.Container(padding: const pw.EdgeInsets.all(5), child: pw.Text('م', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                        ],
                      ),
                      // Data Rows
                      ...List.generate(items.length, (idx) {
                        final item = items[idx];
                        final qty = (item['qty'] as num?)?.toDouble() ?? 0.0;
                        final price = (item['unit_price'] as num?)?.toDouble() ?? (item['price'] as num?)?.toDouble() ?? 0.0;
                        final subtotal = qty * price;
                        return pw.TableRow(
                          children: [
                            pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['notes'] ?? '', style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center)),
                            pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(subtotal.toStringAsFixed(1), style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                            pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(price.toStringAsFixed(1), style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center)),
                            pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('${qty.toInt()}', style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center)),
                            pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text(item['item_name'] ?? item['name'] ?? '', style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                            pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('${idx + 1}', style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center)),
                          ],
                        );
                      }),
                    ],
                  ),

                  pw.Spacer(),

                  // --- Bottom Summary Grid (Matches Image Summary Row) ---
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
                    children: [
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('الرصيد الحالي', style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                          pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('الحساب السابق', style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                          pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('إجمالي الفاتورة', style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                          pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('قيمة الضريبة', style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                          pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('صافي الفاتورة', style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                          pw.Container(padding: const pw.EdgeInsets.all(4), child: pw.Text('عدد الأصناف', style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(padding: const pw.EdgeInsets.all(5), child: pw.Text(currentBalance.toStringAsFixed(2), style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red900), textAlign: pw.TextAlign.center)),
                          pw.Container(padding: const pw.EdgeInsets.all(5), child: pw.Text(previousBalance.toStringAsFixed(2), style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center)),
                          pw.Container(padding: const pw.EdgeInsets.all(5), child: pw.Text(invoiceTotal.toStringAsFixed(1), style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                          pw.Container(padding: const pw.EdgeInsets.all(5), child: pw.Text(vatAmount.toStringAsFixed(1), style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center)),
                          pw.Container(padding: const pw.EdgeInsets.all(5), child: pw.Text(netTotal.toStringAsFixed(0), style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center)),
                          pw.Container(padding: const pw.EdgeInsets.all(5), child: pw.Text('$itemsCount', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 8),

                  // --- Written Amount, Signature & ZATCA QR Code ---
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.black, width: 0.8),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        // ZATCA QR Code
                        pw.Container(
                          width: 50,
                          height: 50,
                          child: pw.BarcodeWidget(
                            barcode: pw.Barcode.qrCode(),
                            data: 'ZATCA-VAT-INVOICE-$invoiceNumber-$companyVat-${invoiceTotal.toStringAsFixed(2)}',
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        // Signature line & amount text
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.center,
                            children: [
                              pw.Text('توقيع العميل : ........................................', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 4),
                              pw.Text('ثلاثة آلاف ومائتان وسبعة وسبعون ريالاً وخمسون هللة فقط لا غير', style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                        ),
                        pw.Text('فقط لا غير', style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Goods Delivery Voucher PDF matching user's exact uploaded image format
  static Future<Uint8List> generateGoodsDeliveryVoucherPdf({
    required String invoiceNumber,
    required String warehouseName, // e.g. "مخزن مرحلة"
    required String customerName,  // e.g. "مؤسسة عبد الله حمد المحيميد"
    required String customerCode,  // e.g. "320"
    required String representative, // e.g. "ابراهيم شكرى"
    required String date,          // e.g. "13/08/2026"
    required String address,       // e.g. "بريدة"
    required String author,        // e.g. "MOHAMED"
    required String time,          // e.g. "04:37:01 ص"
    required String notes,         // e.g. "Note"
    required List<Map<String, dynamic>> items,
  }) async {
    final pdf = pw.Document();
    final font = await _loadFont();

    final double totalPieces = items.fold(0.0, (sum, i) => sum + ((i['qty'] as num?)?.toDouble() ?? 0.0));
    final int totalCategories = items.length;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1.5),
                borderRadius: pw.BorderRadius.circular(16),
              ),
              child: pw.Column(
                children: [
                  // --- Header Grid (Matches Image Top Box) ---
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
                    children: [
                      pw.TableRow(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('مخزن مرحلة', style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(warehouseName.isNotEmpty ? warehouseName : 'مخزن', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(invoiceNumber, style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('رقم الفاتورة', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(customerCode, style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('الكود', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(customerName, style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('اسم العميل', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(date, style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('التاريخ', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(representative, style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('المندوب', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(address, style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('العنوان', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('', style: pw.TextStyle(font: font, fontSize: 9)),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('', style: pw.TextStyle(font: font, fontSize: 9)),
                          ),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 14),

                  // --- Title Header ---
                  pw.Text(
                    'اذن تسليم بضاعة',
                    style: pw.TextStyle(font: font, fontSize: 18, fontWeight: pw.FontWeight.bold),
                    textAlign: pw.TextAlign.center,
                  ),

                  pw.SizedBox(height: 14),

                  // --- Items Table ---
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1), // الكمية
                      1: const pw.FlexColumnWidth(4), // الصنف
                      2: const pw.FlexColumnWidth(0.8), // م
                    },
                    children: [
                      // Header Row
                      pw.TableRow(
                        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('الكمية', style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('الصنف', style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Text('م', style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          ),
                        ],
                      ),

                      // Data Rows
                      ...List.generate(items.length, (index) {
                        final item = items[index];
                        final qty = (item['qty'] as num?)?.toDouble() ?? 0.0;
                        return pw.TableRow(
                          children: [
                            pw.Container(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text('${qty.toInt()}', style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text(item['item_name'] ?? item['name'] ?? '', style: pw.TextStyle(font: font, fontSize: 10), textAlign: pw.TextAlign.center),
                            ),
                            pw.Container(
                              padding: const pw.EdgeInsets.all(6),
                              child: pw.Text('${index + 1}', style: pw.TextStyle(font: font, fontSize: 10), textAlign: pw.TextAlign.center),
                            ),
                          ],
                        );
                      }),
                    ],
                  ),

                  pw.SizedBox(height: 10),

                  // --- Summary Grid ---
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
                    children: [
                      pw.TableRow(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(author.isNotEmpty ? author : 'MOHAMED', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('عدد القطع', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('عدد الأصناف', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          ),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Column(
                              children: [
                                pw.Text(time.isNotEmpty ? time : '04:37:01 ص', style: pw.TextStyle(font: font, fontSize: 9)),
                                pw.Text(date, style: pw.TextStyle(font: font, fontSize: 9)),
                              ],
                            ),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('${totalPieces.toInt()}', style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Text('$totalCategories', style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          ),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 10),

                  // --- Signature & Notes Section ---
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
                    children: [
                      pw.TableRow(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            height: 45,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.end,
                              children: [
                                pw.Text('توقيع العميل / استلام البضاعة:', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                pw.Spacer(),
                                pw.Text('........................................', style: pw.TextStyle(font: font, fontSize: 9)),
                              ],
                            ),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            height: 45,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.center,
                              children: [
                                pw.Text('Note', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                                pw.SizedBox(height: 2),
                                pw.Text(notes.isNotEmpty ? notes : '', style: pw.TextStyle(font: font, fontSize: 9)),
                              ],
                            ),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(8),
                            height: 45,
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('استلمت أنا: ....................', style: pw.TextStyle(font: font, fontSize: 8)),
                                pw.SizedBox(height: 2),
                                pw.Text('الكميات الموضحة بالفاتورة وبعد المراجعة', style: pw.TextStyle(font: font, fontSize: 8)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  pw.Spacer(),

                  // Company Footer Name
                  pw.Center(
                    child: pw.Text(
                      'شركة عبد الله حمد المحيميد - إدارة المستودعات والمبيعات',
                      style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey700),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Detailed Customer Account Statement PDF matching user's exact uploaded image format
  static Future<Uint8List> generateDetailedCustomerStatementPdf({
    required String companyName,    // e.g. "شركة طربوش"
    required String vatNumber,      // e.g. "31057282200003"
    required String crNumber,       // e.g. "7000418972"
    required String customerName,   // e.g. "مؤسسة صلاح سعد أحمد الحارثي"
    required String customerCode,   // e.g. "140"
    required String startDate,      // e.g. "01/01/2026"
    required String endDate,        // e.g. "21/08/2026"
    required double previousBalance,// e.g. 0.0
    required double totalDebit,     // e.g. 40165.5
    required double totalCredit,    // e.g. 6600.0
    required double finalBalance,   // e.g. 33565.50
    required List<Map<String, dynamic>> transactions,
  }) async {
    final pdf = pw.Document();
    final font = await _loadFont();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // --- Top Company Header Box ---
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.black, width: 1),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(companyName.isNotEmpty ? companyName : 'Benaa Co.', style: pw.TextStyle(font: font, fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          pw.Text('VAT NO: $vatNumber', style: pw.TextStyle(font: font, fontSize: 8)),
                          pw.Text('C.R: $crNumber', style: pw.TextStyle(font: font, fontSize: 8)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('كشف حساب تفصيلي', style: pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          pw.Text(customerName, style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('كود العميل: $customerCode', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Text('الفترة من: $startDate إلى: $endDate', style: pw.TextStyle(font: font, fontSize: 8)),
                        ],
                      ),
                    ],
                  ),
                ),

                pw.SizedBox(height: 10),

                // --- Transactions Table ---
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.2), // الرصيد
                    1: const pw.FlexColumnWidth(1.2), // المبلغ (مدين/دائن)
                    2: const pw.FlexColumnWidth(0.8), // السعر
                    3: const pw.FlexColumnWidth(0.8), // الكمية
                    4: const pw.FlexColumnWidth(0.8), // رقم
                    5: const pw.FlexColumnWidth(1.1), // التاريخ
                    6: const pw.FlexColumnWidth(3),   // البيان
                  },
                  children: [
                    // Header Row
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('الرصيد', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('المبلغ', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('السعر', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('الكمية', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('رقم', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('التاريخ', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('البيان', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                        ),
                      ],
                    ),

                    // Rows
                    ...transactions.map((tx) {
                      final desc = tx['description'] ?? tx['type'] ?? '';
                      final dateStr = tx['date'] ?? '';
                      final ref = tx['ref'] ?? tx['invoice_num'] ?? '';
                      final qty = (tx['qty'] as num?)?.toDouble() ?? 0.0;
                      final price = (tx['price'] as num?)?.toDouble() ?? 0.0;
                      final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                      final balance = (tx['balance'] as num?)?.toDouble() ?? 0.0;

                      return pw.TableRow(
                        children: [
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(balance != 0 ? balance.toStringAsFixed(2) : '', style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(amount != 0 ? amount.toStringAsFixed(2) : '', style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(price > 0 ? price.toStringAsFixed(2) : '', style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(qty > 0 ? '${qty.toInt()}' : '', style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text('$ref', style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(dateStr, style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            child: pw.Text(desc, style: pw.TextStyle(font: font, fontSize: 8, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right),
                          ),
                        ],
                      );
                    }),
                  ],
                ),

                pw.Spacer(),

                // --- Bottom Summary Grid (Matches Image Bottom Table) ---
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('مدين - عليه', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('دائن - له', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('النوع', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(previousBalance != 0 ? previousBalance.toStringAsFixed(2) : '0', style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('0', style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('سابقات', style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(totalDebit.toStringAsFixed(2), style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text(totalCredit.toStringAsFixed(2), style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Text('حالية', style: pw.TextStyle(font: font, fontSize: 8), textAlign: pw.TextAlign.center),
                        ),
                      ],
                    ),
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('${finalBalance.toStringAsFixed(2)} ر.س', style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red900), textAlign: pw.TextAlign.center),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('0', style: pw.TextStyle(font: font, fontSize: 9), textAlign: pw.TextAlign.center),
                        ),
                        pw.Container(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text('الرصيد النهائي', style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.SizedBox(height: 10),

                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('توقيع المحاسب: ....................', style: pw.TextStyle(font: font, fontSize: 9)),
                    pw.Text('اعتماد الإدارة: ....................', style: pw.TextStyle(font: font, fontSize: 9)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Generate Official Payment Receipt PDF (سند قبض رسمي)
  static Future<Uint8List> generatePaymentReceiptPdf({
    required String receiptNumber,  // e.g. "REC-9482"
    required String customerName,   // e.g. "مؤسسة عبدالله حمد المحيميد"
    required double amountPaid,     // e.g. 6600.0
    required String paymentMethod,  // e.g. "تحويل بنكي / نقداً"
    required String date,          // e.g. "25/08/2026"
    required String refNumber,     // e.g. "TRF-8847392"
    required String notes,         // e.g. "دفعة سداد حساب فواتير سابقة"
    required double remainingBalance, // e.g. 33565.50
  }) async {
    final pdf = pw.Document();
    final font = await _loadFont();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.indigo900, width: 2),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Top Header
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('شركة Benaa للمواد وإدارة المستودعات', style: pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                          pw.Text('قسم الحسابات والمالية - بريدة', style: pw.TextStyle(font: font, fontSize: 11, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('سند قبض رسمي', style: pw.TextStyle(font: font, fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                          pw.Text('رقم السند: $receiptNumber', style: pw.TextStyle(font: font, fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          pw.Text('التاريخ: $date', style: pw.TextStyle(font: font, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),

                  pw.SizedBox(height: 12),
                  pw.Divider(color: PdfColors.indigo900, thickness: 1),
                  pw.SizedBox(height: 12),

                  // Amount Card
                  pw.Container(
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.green50,
                      border: pw.Border.all(color: PdfColors.green700, width: 1),
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('المبلغ المقبوض: ${amountPaid.toStringAsFixed(2)} ر.س', style: pw.TextStyle(font: font, fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                        pw.Text('طريقة السداد: $paymentMethod', style: pw.TextStyle(font: font, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),

                  pw.SizedBox(height: 16),

                  // Receipt Details Table
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                    children: [
                      pw.TableRow(
                        children: [
                          pw.Container(padding: const pw.EdgeInsets.all(6), child: pw.Text('استلمنا من المكرم / السيد:', style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold))),
                          pw.Container(padding: const pw.EdgeInsets.all(6), child: pw.Text(customerName, style: pw.TextStyle(font: font, fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900))),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(padding: const pw.EdgeInsets.all(6), child: pw.Text('مبلغ وقدره:', style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold))),
                          pw.Container(padding: const pw.EdgeInsets.all(6), child: pw.Text('${amountPaid.toStringAsFixed(2)} ريال لا غير', style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold))),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(padding: const pw.EdgeInsets.all(6), child: pw.Text('رقم المرجع / التحويل:', style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold))),
                          pw.Container(padding: const pw.EdgeInsets.all(6), child: pw.Text(refNumber.isNotEmpty ? refNumber : 'نقداً', style: pw.TextStyle(font: font, fontSize: 10))),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(padding: const pw.EdgeInsets.all(6), child: pw.Text('وذلك عن / البيان:', style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold))),
                          pw.Container(padding: const pw.EdgeInsets.all(6), child: pw.Text(notes.isNotEmpty ? notes : 'سداد حساب فواتير سابقة', style: pw.TextStyle(font: font, fontSize: 10))),
                        ],
                      ),
                      pw.TableRow(
                        children: [
                          pw.Container(padding: const pw.EdgeInsets.all(6), child: pw.Text('الرصيد المتبقي على العميل:', style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold))),
                          pw.Container(padding: const pw.EdgeInsets.all(6), child: pw.Text('${remainingBalance.toStringAsFixed(2)} ر.س', style: pw.TextStyle(font: font, fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red900))),
                        ],
                      ),
                    ],
                  ),

                  pw.Spacer(),

                  // Signatures
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('توقيع المستلم / العميل: ....................', style: pw.TextStyle(font: font, fontSize: 10)),
                      pw.Text('توقيع المحاسب / أمين الصندوق: ....................', style: pw.TextStyle(font: font, fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}
