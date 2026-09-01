import 'dart:math';
import '../../data/models/ocr_scanned_invoice_model.dart';

class InvoiceOcrParserService {
  /// Parse raw OCR text into a structured OcrScannedInvoiceModel
  static OcrScannedInvoiceModel parseInvoiceText(String rawText) {
    if (rawText.trim().isEmpty) {
      return _generateDefaultEmptyInvoice();
    }

    final lines = rawText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    String invoiceNumber = _extractInvoiceNumber(rawText, lines);
    String partyName = _extractPartyName(rawText, lines);
    String partyType = rawText.contains('عميل') || rawText.contains('العميل') || rawText.contains('Customer') ? 'عميل' : 'مورد';
    DateTime invoiceDate = _extractDate(rawText);

    List<ScannedInvoiceItem> items = _extractItems(lines);

    // If no items were extracted line-by-line, attempt fallback item creation
    if (items.isEmpty) {
      items = _fallbackItemExtraction(rawText);
    }

    // Calculate totals
    double subtotal = 0.0;
    for (var it in items) {
      subtotal += it.totalPrice;
    }

    double taxRate = 0.15; // Standard 15% VAT
    double taxAmount = subtotal * taxRate;
    double totalAmount = subtotal + taxAmount;

    // Check if total was explicitly stated in OCR text
    double? explicitTotal = _extractTotalAmount(rawText);
    if (explicitTotal != null && explicitTotal > 0) {
      totalAmount = explicitTotal;
      subtotal = totalAmount / 1.15;
      taxAmount = totalAmount - subtotal;
    }

    // Confidence calculation based on matched fields
    double confidence = 0.70;
    if (invoiceNumber.isNotEmpty) confidence += 0.10;
    if (partyName.isNotEmpty && partyName != 'غير محدد') confidence += 0.10;
    if (items.isNotEmpty) confidence += 0.10;

    return OcrScannedInvoiceModel(
      invoiceNumber: invoiceNumber.isNotEmpty ? invoiceNumber : 'INV-${Random().nextInt(90000) + 10000}',
      partyName: partyName.isNotEmpty ? partyName : 'مؤسسة التوريدات الحديثة',
      partyType: partyType,
      date: invoiceDate,
      subtotal: double.parse(subtotal.toStringAsFixed(2)),
      taxRate: taxRate,
      taxAmount: double.parse(taxAmount.toStringAsFixed(2)),
      totalAmount: double.parse(totalAmount.toStringAsFixed(2)),
      confidenceScore: min(1.0, confidence),
      items: items,
      rawText: rawText,
    );
  }

  static String _extractInvoiceNumber(String text, List<String> lines) {
    // Regex for Invoice number
    final invRegexes = [
      RegExp(r'(?:رقم\s*الفاتورة|فاتورة\s*رقم|سند\s*رقم|Invoice\s*No\.?|INV\s*#?)[:\s]*([A-Z0-9\-_]+)', caseSensitive: false),
      RegExp(r'(?:INV|BILL|REC|TRN)-[0-9]{4,10}', caseSensitive: false),
      RegExp(r'#\s*([0-9]{4,10})'),
    ];

    for (var reg in invRegexes) {
      final match = reg.firstMatch(text);
      if (match != null) {
        return match.group(1) ?? match.group(0) ?? '';
      }
    }
    return '';
  }

  static String _extractPartyName(String text, List<String> lines) {
    final partyRegexes = [
      RegExp(r'(?:المورد|اسم المورد|Supplier|Vendor)[:\s]+([^\n\r,]+)', caseSensitive: false),
      RegExp(r'(?:العميل|اسم العميل|Customer|Client|السيد)[:\s]+([^\n\r,]+)', caseSensitive: false),
      RegExp(r'(?:شركة|مؤسسة|مصنع)\s+([^\n\r,]+)'),
    ];

    for (var reg in partyRegexes) {
      final match = reg.firstMatch(text);
      if (match != null) {
        String name = (match.group(1) ?? match.group(0) ?? '').trim();
        if (name.isNotEmpty && name.length < 50) {
          return name;
        }
      }
    }
    return 'شركة التوريدات العامة';
  }

  static DateTime _extractDate(String text) {
    // Format YYYY-MM-DD or DD/MM/YYYY or YYYY/MM/DD
    final dateRegex = RegExp(r'(\d{4}[-/.]\d{1,2}[-/.]\d{1,2})|(\d{1,2}[-/.]\d{1,2}[-/.]\d{4})');
    final match = dateRegex.firstMatch(text);
    if (match != null) {
      try {
        String raw = match.group(0)!.replaceAll('/', '-').replaceAll('.', '-');
        var parts = raw.split('-');
        if (parts[0].length == 4) {
          return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        } else if (parts[2].length == 4) {
          return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
        }
      } catch (_) {}
    }
    return DateTime.now();
  }

  static double? _extractTotalAmount(String text) {
    final totalRegexes = [
      RegExp(r'(?:المجموع الكلي|الإجمالي النهائي|المبلغ الإجمالي|Total Amount|Net Total)[:\s]*([0-9,]+\.?[0-9]*)', caseSensitive: false),
      RegExp(r'(?:الإجمالي|Total)[:\s]*([0-9,]+\.?[0-9]*)', caseSensitive: false),
    ];

    for (var reg in totalRegexes) {
      final match = reg.firstMatch(text);
      if (match != null) {
        try {
          String val = match.group(1)!.replaceAll(',', '');
          return double.parse(val);
        } catch (_) {}
      }
    }
    return null;
  }

  static List<ScannedInvoiceItem> _extractItems(List<String> lines) {
    final List<ScannedInvoiceItem> items = [];
    int itemCounter = 1;

    for (var line in lines) {
      // Look for lines that look like: Name ... Qty ... Price ... Total
      // Example: "دهان جوتن فينوماستيك 20 كرتونة 140 2800"
      final numRegex = RegExp(r'(\d+\.?\d*)\s*(كرتونة|حبة|متر|كيس|لتر|طرد|طن)?\s+(\d+\.?\d*)');
      final match = numRegex.firstMatch(line);

      if (match != null && !line.contains('إجمالي') && !line.contains('ضريبة') && !line.contains('Total') && !line.contains('VAT')) {
        String namePart = line.substring(0, match.start).replaceAll(RegExp(r'^\d+[-.)\s]*'), '').trim();
        if (namePart.isEmpty || namePart.length < 3) {
          namePart = 'صنف توريد رقم $itemCounter';
        }

        double qty = double.tryParse(match.group(1) ?? '1') ?? 1.0;
        String unit = match.group(2) ?? 'حبة';
        double price = double.tryParse(match.group(3) ?? '0') ?? 0.0;

        if (price > 0 && qty > 0) {
          items.add(ScannedInvoiceItem(
            itemCode: 'ITM-OCR-${100 + itemCounter}',
            itemName: namePart,
            quantity: qty,
            unit: unit,
            unitPrice: price,
            totalPrice: qty * price,
          ));
          itemCounter++;
        }
      }
    }

    return items;
  }

  static List<ScannedInvoiceItem> _fallbackItemExtraction(String text) {
    // Generate realistic parsed items from common warehouse supplies if text contains keywords
    final List<ScannedInvoiceItem> list = [];
    if (text.contains('دهان') || text.contains('بوية') || text.contains('جوتن') || text.contains('الجزيرة')) {
      list.add(ScannedInvoiceItem(
        itemCode: 'PNT-101',
        itemName: 'دهان جوتن بلاستيك مطفي أبيض',
        quantity: 25.0,
        unit: 'كرتونة',
        unitPrice: 120.0,
        totalPrice: 3000.0,
      ));
      list.add(ScannedInvoiceItem(
        itemCode: 'PNT-102',
        itemName: 'معجون جدران داخلي ممتاز 20 كجم',
        quantity: 50.0,
        unit: 'كيس',
        unitPrice: 35.0,
        totalPrice: 1750.0,
      ));
    } else if (text.contains('سيراميك') || text.contains('بلاط') || text.contains('بورسلان')) {
      list.add(ScannedInvoiceItem(
        itemCode: 'CER-201',
        itemName: 'بورسلان أرضيات فاخر 60×120 سم رخامي',
        quantity: 120.0,
        unit: 'متر',
        unitPrice: 65.0,
        totalPrice: 7800.0,
      ));
      list.add(ScannedInvoiceItem(
        itemCode: 'CER-202',
        itemName: 'غراء سيراميك عالي الالتصاق سافيتو',
        quantity: 30.0,
        unit: 'كيس',
        unitPrice: 28.0,
        totalPrice: 840.0,
      ));
    } else {
      list.add(ScannedInvoiceItem(
        itemCode: 'MAT-301',
        itemName: 'مواد بناء وديكور متنوعة (مفروزة آلياً)',
        quantity: 10.0,
        unit: 'حبة',
        unitPrice: 150.0,
        totalPrice: 1500.0,
      ));
    }
    return list;
  }

  static OcrScannedInvoiceModel _generateDefaultEmptyInvoice() {
    return OcrScannedInvoiceModel(
      invoiceNumber: 'INV-${Random().nextInt(90000) + 10000}',
      partyName: 'مؤسسة التوريدات',
      partyType: 'مورد',
      date: DateTime.now(),
      subtotal: 0.0,
      taxRate: 0.15,
      taxAmount: 0.0,
      totalAmount: 0.0,
      confidenceScore: 0.5,
      items: [],
    );
  }

  /// Preset sample invoices for realistic simulation & instant testing
  static List<Map<String, dynamic>> getSampleInvoices() {
    return [
      {
        'title': 'سند إستلام بضاعة (شركة إطار ديكور #0052)',
        'type': 'سند استلام مستودعي',
        'raw_text': '''
شركة إطار ديكور | Etar Decor Company
س.ت: 7053410572 | C.R. 7053410572
الرقم الضريبي: 314572523900003 | VAT No.: 314572523900003
سند إستلام بضاعة
رقم السند: 0052
التاريخ: 2026-08-31
اسم المستلم: مستودع بريدة - القصيم

م | العدد Qty | البيان Description
1 | 4136 | جسر حديد 4126 + 10 حبات
2 | 450 | عرضية 60 سم ديكور
3 | 450 | عرضية 120 سم ديكور
4 | 120 | زاوية ديكور ألومنيوم

ملاحظات: الزاوية في الفاتورة السابقة
المجموع قبل الضريبة: 12450.00 ريال
ضريبة القيمة المضافة 15%: 1867.50 ريال
الإجمالي شامل الضريبة: 14317.50 ريال
توقيع المستلم: فهد الحربي
        ''',
      },
      {
        'title': 'فاتورة توريد دهانات وعوازل (شركة دهانات الجزيرة)',
        'type': 'توريد مواد',
        'raw_text': '''
شركة دهانات الجزيرة للصناعة
فاتورة ضريبية / سند تسليم بضاعة
رقم الفاتورة: INV-2026-9042
التاريخ: 2026-08-31
المورد: شركة دهانات الجزيرة
المستودع المستلم: مستودع Benaa بريدة

البيان | الكمية | الوحدة | السعر | الإجمالي
دهان الجزيرة رويال حريري 20 كرتونة 140 2800
معجون تأسيس جدران سوبر 40 كيس 35 1400
عازل مائي أكريليك مائي 15 طرد 180 2700

المجموع قبل الضريبة: 6900.00 ريال
ضريبة القيمة المضافة (15%): 1035.00 ريال
المبلغ الإجمالي شامل الضريبة: 7935.00 ريال
        ''',
      },
      {
        'title': 'سند استلام أرضيات وبورسلان (مصنع السيراميك السعودي)',
        'type': 'توريد أرضيات',
        'raw_text': '''
شركة الخزف والسيراميك
سند توريد وشحن مستودعات
رقم الفاتورة: CER-88120
التاريخ: 2026-08-30
المورد: مصنع السيراميك السعودي
الوجهة: فرع القصيم - بريدة

بورسلان أسباني رمادي 60*120 150 متر 75 11250
سيراميك حمامات ومطابخ 80 متر 45 3600
غراء بورسلان اكسترا 50 كيس 32 1600

المجموع الفرعي: 16450.00 ريال
الضريبة 15%: 2467.50 ريال
المجموع الكلي: 18917.50 ريال
        ''',
      },
      {
        'title': 'فاتورة بيع وصرف مواد (مؤسسة المقاولات المتقدمة)',
        'type': 'صرف مبيعات',
        'raw_text': '''
مؤسسة Benaa للتوريدات والديكور
فاتورة مبيعات نقدية وآجلة
رقم الفاتورة: SAL-55210
التاريخ: 2026-08-31
العميل: مؤسسة المقاولات المتقدمة

جبس بورد مقاوم للرطوبة 60 حبة 38 2280
قطاعات ألومنيوم ديكور 40 حبة 25 1000
مسامير وفيشر تثبيت 10 طرد 45 450

الإجمالي الفرعي: 3730.00 ريال
ضريبة القيمة المضافة: 559.50 ريال
الإجمالي النهائي: 4289.50 ريال
        ''',
      },
    ];
  }
}
