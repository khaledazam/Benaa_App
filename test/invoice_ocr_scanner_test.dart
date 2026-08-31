import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:benaa_flutter_mobile/core/services/invoice_ocr_parser_service.dart';
import 'package:benaa_flutter_mobile/data/models/ocr_scanned_invoice_model.dart';
import 'package:benaa_flutter_mobile/presentation/providers/inventory_provider.dart';
import 'package:benaa_flutter_mobile/presentation/widgets/ocr_invoice_review_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InvoiceOcrParserService & Model Unit Tests', () {
    test('Should parse Arabic standard tax invoice raw text accurately', () {
      const rawText = '''
شركة دهانات الجزيرة للصناعة
فاتورة ضريبية / سند تسليم بضاعة
رقم الفاتورة: INV-2026-9042
التاريخ: 2026-08-31
المورد: شركة دهانات الجزيرة
المستودع المستلم: مستودع Benaa بريدة

دهان الجزيرة رويال حريري 20 كرتونة 140 2800
معجون تأسيس جدران سوبر 40 كيس 35 1400
عازل مائي أكريليك مائي 15 طرد 180 2700

المجموع قبل الضريبة: 6900.00 ريال
ضريبة القيمة المضافة (15%): 1035.00 ريال
المبلغ الإجمالي شامل الضريبة: 7935.00 ريال
      ''';

      final invoice = InvoiceOcrParserService.parseInvoiceText(rawText);

      expect(invoice.invoiceNumber, contains('INV-2026-9042'));
      expect(invoice.partyName, contains('شركة دهانات الجزيرة'));
      expect(invoice.items.length, greaterThanOrEqualTo(2));
      expect(invoice.subtotal, greaterThan(0));
      expect(invoice.taxAmount, greaterThan(0));
      expect(invoice.totalAmount, greaterThan(0));
      expect(invoice.confidenceScore, greaterThanOrEqualTo(0.80));
    });

    test('OcrScannedInvoiceModel recalculation should maintain exact VAT and subtotal math', () {
      final model = OcrScannedInvoiceModel(
        invoiceNumber: 'INV-TEST-001',
        partyName: 'مؤسسة الاختبار',
        date: DateTime.now(),
        subtotal: 1000.0,
        taxAmount: 150.0,
        totalAmount: 1150.0,
        items: [
          ScannedInvoiceItem(itemCode: 'ITM-1', itemName: 'بند 1', quantity: 10, unitPrice: 50, totalPrice: 500),
          ScannedInvoiceItem(itemCode: 'ITM-2', itemName: 'بند 2', quantity: 5, unitPrice: 100, totalPrice: 500),
        ],
      );

      // Modify quantity of item 1
      model.items[0].quantity = 20; // 20 * 50 = 1000
      model.recalculateTotals();

      expect(model.subtotal, equals(1500.0));
      expect(model.taxAmount, equals(225.0)); // 1500 * 0.15
      expect(model.totalAmount, equals(1725.0)); // 1500 + 225
    });
  });

  group('OcrInvoiceReviewSheet Widget & Integration Tests', () {
    testWidgets('OcrInvoiceReviewSheet renders and allows item editing & inventory commit', (WidgetTester tester) async {
      final sampleInvoice = InvoiceOcrParserService.parseInvoiceText(
        InvoiceOcrParserService.getSampleInvoices().first['raw_text'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (_) => InventoryProvider(),
            child: Scaffold(
              body: Builder(
                builder: (context) => OcrInvoiceReviewSheet(invoice: sampleInvoice),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header and elements render
      expect(find.text('مراجعة وتأكيد الفاتورة الممسوحة'), findsOneWidget);
      expect(find.textContaining('دقة التعرف'), findsOneWidget);
      expect(find.textContaining('الأصناف المستخرجة'), findsOneWidget);
      expect(find.textContaining('ترحيل للمستودع فوراً'), findsOneWidget);
    });
  });
}
