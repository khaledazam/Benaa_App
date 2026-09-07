import '../../data/models/item_model.dart';

enum CeilingItemCategory {
  gypsumTiles,    // بلاط جبس 60*60 (معامل: 2.75 | كرتونة: 8)
  mainTee,        // جسور معلقة (معامل: 0.22 | كرتونة: 25)
  wallAngle,      // زوايا جدار (معامل: 0.22 | كرتونة: 50)
  crossTee60,     // عرضية 60 سم (معامل: 1.25 | كرتونة: 75)
  crossTee120,    // عرضية 120 سم (معامل: 1.25 | كرتونة: 75)
  standard,       // صنف عام يعتمد على معامل التحويل العادي
}

class CeilingCalculationResult {
  final CeilingItemCategory category;
  final String itemName;
  final double areaM2;
  final double multiplier;
  final int cartonCapacity;
  final double totalPieces;
  final int fullCartons;
  final int loosePieces;
  final String formattedBreakdown; // مثال: 34 كرتونة + 3 حبات (275 بلاطة)
  final String shortSummary;       // مثال: 34 ك + 3 حبة

  const CeilingCalculationResult({
    required this.category,
    required this.itemName,
    required this.areaM2,
    required this.multiplier,
    required this.cartonCapacity,
    required this.totalPieces,
    required this.fullCartons,
    required this.loosePieces,
    required this.formattedBreakdown,
    required this.shortSummary,
  });
}

class CeilingProjectEstimate {
  final double areaM2;
  final CeilingCalculationResult gypsumTiles;
  final CeilingCalculationResult mainTees;
  final CeilingCalculationResult wallAngles;
  final CeilingCalculationResult crossTees60;
  final CeilingCalculationResult crossTees120;

  const CeilingProjectEstimate({
    required this.areaM2,
    required this.gypsumTiles,
    required this.mainTees,
    required this.wallAngles,
    required this.crossTees60,
    required this.crossTees120,
  });

  List<CeilingCalculationResult> get allResults => [
    gypsumTiles,
    mainTees,
    wallAngles,
    crossTees60,
    crossTees120,
  ];
}

class CeilingEstimationEngine {
  /// التعرف الذكي على نوع الصنف الديكوري من اسمه أو تصنيفه أو كوده
  static CeilingItemCategory detectCategory(ItemModel item) {
    final name = item.name.toLowerCase();
    final category = item.category.toLowerCase();
    final code = item.code.toLowerCase();

    // 1. زوايا الجدار وزوايا البلاط وحديد الزاوية (Wall Angle / Tile Angle / Corner Trim)
    // نضع فحص الزوايا أولاً قبل فحص "بلاط" حتى لا يُصنف صنف "زاوية بلاط" خطأً كبلاط أسقف جبسية
    if (name.contains('زاوية') ||
        name.contains('زاويه') ||
        name.contains('angle') ||
        name.contains('corner') ||
        name.contains('كورنر') ||
        code == '3001' ||
        category.contains('زوايا') ||
        category.contains('زوايه')) {
      return CeilingItemCategory.wallAngle;
    }

    // 2. الجسور المعلقة (Main Tee)
    if (name.contains('جسر') || name.contains('main') || name.contains('tee 3.6') || name.contains('tee 4') || code == '4126') {
      return CeilingItemCategory.mainTee;
    }

    // 3. عرضية 60 سم (Cross Tee 60)
    if ((name.contains('عرضية') || name.contains('عرضيه') || name.contains('cross')) && (name.contains('60') || code == '6001')) {
      return CeilingItemCategory.crossTee60;
    }

    // 4. عرضية 120 سم (Cross Tee 120)
    if ((name.contains('عرضية') || name.contains('عرضيه') || name.contains('cross')) && (name.contains('120') || code == '1202')) {
      return CeilingItemCategory.crossTee120;
    }

    // 5. بلاط الجبس / أسقف جبسية
    if (name.contains('بلاط') || name.contains('جبس') || category.contains('جبس') || category.contains('بلاط') || code == '154' || code == '1010') {
      return CeilingItemCategory.gypsumTiles;
    }

    return CeilingItemCategory.standard;
  }

  /// سعة الكرتونة لكل فئة هندسية
  static int getCartonCapacity(CeilingItemCategory category) {
    switch (category) {
      case CeilingItemCategory.gypsumTiles:
        return 8;
      case CeilingItemCategory.mainTee:
        return 25;
      case CeilingItemCategory.wallAngle:
        return 50;
      case CeilingItemCategory.crossTee60:
      case CeilingItemCategory.crossTee120:
        return 75;
      case CeilingItemCategory.standard:
        return 1;
    }
  }

  /// حساب التفكيك الدقيق لأي صنف عند إدخال المساحة بالمتر المربع (م²)
  static CeilingCalculationResult calculateItemBreakdown({
    required ItemModel item,
    required double areaM2,
  }) {
    final cat = detectCategory(item);
    return calculateForCategory(category: cat, areaM2: areaM2, customItemName: item.name);
  }

  /// حساب التفكيك لفئة معينة بناءً على المعادلات المعتمدة
  static CeilingCalculationResult calculateForCategory({
    required CeilingItemCategory category,
    required double areaM2,
    String? customItemName,
  }) {
    double multiplier;
    int cartonCap;
    String defaultName;

    switch (category) {
      case CeilingItemCategory.gypsumTiles:
        multiplier = 2.75;
        cartonCap = 8;
        defaultName = 'بلاط جبس 60×60';
        break;
      case CeilingItemCategory.mainTee:
        multiplier = 0.22;
        cartonCap = 25;
        defaultName = 'جسر حديد معلق 4 متر';
        break;
      case CeilingItemCategory.wallAngle:
        multiplier = 0.22;
        cartonCap = 50;
        defaultName = 'زاوية جدار 3 متر';
        break;
      case CeilingItemCategory.crossTee60:
        multiplier = 1.25;
        cartonCap = 75;
        defaultName = 'عرضية 60 سم سقف مستعار';
        break;
      case CeilingItemCategory.crossTee120:
        multiplier = 1.25;
        cartonCap = 75;
        defaultName = 'عرضية 120 سم سقف مستعار';
        break;
      case CeilingItemCategory.standard:
        multiplier = 1.0;
        cartonCap = 1;
        defaultName = customItemName ?? 'صنف عام';
        break;
    }

    final totalExactPieces = areaM2 * multiplier;
    // التقريب الهندسي لأعلى حبة صحيحة لضمان تغطية كامل المساحة
    final totalRoundedPieces = totalExactPieces.roundToDouble();

    final fullCartons = (totalRoundedPieces / cartonCap).floor();
    final loosePieces = (totalRoundedPieces % cartonCap).toInt();

    String breakdown;
    String shortSummary;

    if (fullCartons > 0 && loosePieces > 0) {
      breakdown = '$fullCartons كرتونة + $loosePieces حبة (${totalRoundedPieces.toInt()} قطعة)';
      shortSummary = '$fullCartons ك + $loosePieces حبة';
    } else if (fullCartons > 0 && loosePieces == 0) {
      breakdown = '$fullCartons كرتونة مقفولة (${totalRoundedPieces.toInt()} قطعة)';
      shortSummary = '$fullCartons كرتونة';
    } else {
      breakdown = '$loosePieces حبة فردي';
      shortSummary = '$loosePieces حبة';
    }

    return CeilingCalculationResult(
      category: category,
      itemName: customItemName ?? defaultName,
      areaM2: areaM2,
      multiplier: multiplier,
      cartonCapacity: cartonCap,
      totalPieces: totalRoundedPieces,
      fullCartons: fullCartons,
      loosePieces: loosePieces,
      formattedBreakdown: breakdown,
      shortSummary: shortSummary,
    );
  }

  /// حساب مقايسة سقف كاملة دفعة واحدة بمساحة معينة
  static CeilingProjectEstimate calculateFullProject(double areaM2) {
    return CeilingProjectEstimate(
      areaM2: areaM2,
      gypsumTiles: calculateForCategory(category: CeilingItemCategory.gypsumTiles, areaM2: areaM2),
      mainTees: calculateForCategory(category: CeilingItemCategory.mainTee, areaM2: areaM2),
      wallAngles: calculateForCategory(category: CeilingItemCategory.wallAngle, areaM2: areaM2),
      crossTees60: calculateForCategory(category: CeilingItemCategory.crossTee60, areaM2: areaM2),
      crossTees120: calculateForCategory(category: CeilingItemCategory.crossTee120, areaM2: areaM2),
    );
  }
}
