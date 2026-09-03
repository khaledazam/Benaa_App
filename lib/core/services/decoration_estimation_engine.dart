import 'dart:math' as math;
import '../../data/models/item_model.dart';

enum DecorationProjectType {
  ceiling,    // أسقف مستعارة وبلاط جبس
  wpcWood,    // بديل خشب جداري WPC
  pvcMarble,  // بديل رخام PVC مع فواصل ألومنيوم
  wallFoam,   // إطارات وبانوهات فوم وبوليريثان
}

enum DecorationItemRole {
  mainPanel,     // الشريحة أو اللوح الرئيسي (بلاط، خشب، رخام)
  mainStructure, // الجسور أو الأعواد الأساسية
  crossProfile,  // العرضيات أو فواصل الألومنيوم H-Profile
  edgeTrim,      // زوايا الجدار، حليات الإغلاق، زوايا L
  adhesive,      // سيليكون وغراء تثبيت
  filler,        // معجون زوايا وفواصل
}

class DecorationItemEstimate {
  final DecorationItemRole role;
  final String itemName;
  final String categoryHint;
  final double quantity;
  final String unit;
  final int fullCartons;
  final int loosePieces;
  final int cartonCapacity;
  final double estimatedUnitPrice;
  final String breakdownSummary;
  final String calculationFormulaNote;

  const DecorationItemEstimate({
    required this.role,
    required this.itemName,
    required this.categoryHint,
    required this.quantity,
    required this.unit,
    required this.fullCartons,
    required this.loosePieces,
    required this.cartonCapacity,
    required this.estimatedUnitPrice,
    required this.breakdownSummary,
    required this.calculationFormulaNote,
  });

  double get estimatedTotalPrice => quantity * estimatedUnitPrice;
}

class DecorationProjectEstimate {
  final DecorationProjectType projectType;
  final String projectTitle;
  final double primaryDimension; // مساحة م² أو أمتار طولية أو عرض الجدار
  final double? secondaryDimension; // ارتفاع الجدار إن وجد
  final List<DecorationItemEstimate> items;

  const DecorationProjectEstimate({
    required this.projectType,
    required this.projectTitle,
    required this.primaryDimension,
    this.secondaryDimension,
    required this.items,
  });

  double get totalEstimatedCost => items.fold(0.0, (sum, i) => sum + i.estimatedTotalPrice);
  int get totalPiecesCount => items.fold(0, (sum, i) => sum + i.quantity.toInt());
}

class DecorationEstimationEngine {
  // -------------------------------------------------------------
  // 1. حساب مقايسة الأسقف المستعارة وبلاط الجبس (Ceiling Grids)
  // -------------------------------------------------------------
  static DecorationProjectEstimate estimateCeilingProject(double areaM2) {
    if (areaM2 <= 0) areaM2 = 1.0;

    // بلاط جبس 60×60: معامل 2.75 | كرتونة 8
    final tilesCount = (areaM2 * 2.75).ceilToDouble();
    final tilesCartons = (tilesCount / 8).floor();
    final tilesLoose = (tilesCount % 8).toInt();

    // جسور معلقة 4 متر: معامل 0.22 | ربطة 25
    final mainTeesCount = (areaM2 * 0.22).ceilToDouble();
    final mainTeesCartons = (mainTeesCount / 25).floor();
    final mainTeesLoose = (mainTeesCount % 25).toInt();

    // زوايا جدار 3 متر: معامل 0.22 | ربطة 50
    final wallAnglesCount = (areaM2 * 0.22).ceilToDouble();
    final wallAnglesCartons = (wallAnglesCount / 50).floor();
    final wallAnglesLoose = (wallAnglesCount % 50).toInt();

    // عرضية 60 سم: معامل 1.25 | كرتونة 75
    final cross60Count = (areaM2 * 1.25).ceilToDouble();
    final cross60Cartons = (cross60Count / 75).floor();
    final cross60Loose = (cross60Count % 75).toInt();

    // عرضية 120 سم: معامل 1.25 | كرتونة 75
    final cross120Count = (areaM2 * 1.25).ceilToDouble();
    final cross120Cartons = (cross120Count / 75).floor();
    final cross120Loose = (cross120Count % 75).toInt();

    final items = [
      DecorationItemEstimate(
        role: DecorationItemRole.mainPanel,
        itemName: 'بلاط جبس 60×60 ديكور',
        categoryHint: 'ديكور أرضيات وأسقف',
        quantity: tilesCount,
        unit: 'حبة',
        fullCartons: tilesCartons,
        loosePieces: tilesLoose,
        cartonCapacity: 8,
        estimatedUnitPrice: 6.0,
        breakdownSummary: tilesCartons > 0 ? '$tilesCartons ك + $tilesLoose حبة' : '$tilesLoose حبة',
        calculationFormulaNote: 'المساحة × 2.75 بلاطة/م²',
      ),
      DecorationItemEstimate(
        role: DecorationItemRole.mainStructure,
        itemName: 'جسر حديد معلق سقف مستعار 4 متر',
        categoryHint: 'قطاعات وأسقف',
        quantity: mainTeesCount,
        unit: 'حبة',
        fullCartons: mainTeesCartons,
        loosePieces: mainTeesLoose,
        cartonCapacity: 25,
        estimatedUnitPrice: 28.0,
        breakdownSummary: mainTeesCartons > 0 ? '$mainTeesCartons ربطة + $mainTeesLoose حبة' : '$mainTeesLoose حبة',
        calculationFormulaNote: 'المساحة × 0.22 جسر/م²',
      ),
      DecorationItemEstimate(
        role: DecorationItemRole.edgeTrim,
        itemName: 'زاوية ديكور ألومنيوم جدارية 3 متر',
        categoryHint: 'زوايا وإكسسوارات',
        quantity: wallAnglesCount,
        unit: 'حبة',
        fullCartons: wallAnglesCartons,
        loosePieces: wallAnglesLoose,
        cartonCapacity: 50,
        estimatedUnitPrice: 15.0,
        breakdownSummary: wallAnglesCartons > 0 ? '$wallAnglesCartons ربطة + $wallAnglesLoose حبة' : '$wallAnglesLoose حبة',
        calculationFormulaNote: 'المساحة × 0.22 زاوية/م²',
      ),
      DecorationItemEstimate(
        role: DecorationItemRole.crossProfile,
        itemName: 'عرضية 60 سم نظام تعليق سقف مستعار',
        categoryHint: 'قطاعات وأسقف',
        quantity: cross60Count,
        unit: 'حبة',
        fullCartons: cross60Cartons,
        loosePieces: cross60Loose,
        cartonCapacity: 75,
        estimatedUnitPrice: 12.0,
        breakdownSummary: cross60Cartons > 0 ? '$cross60Cartons ك + $cross60Loose حبة' : '$cross60Loose حبة',
        calculationFormulaNote: 'المساحة × 1.25 عرضية/م²',
      ),
      DecorationItemEstimate(
        role: DecorationItemRole.crossProfile,
        itemName: 'عرضية 120 سم نظام تعليق سقف مستعار',
        categoryHint: 'قطاعات وأسقف',
        quantity: cross120Count,
        unit: 'حبة',
        fullCartons: cross120Cartons,
        loosePieces: cross120Loose,
        cartonCapacity: 75,
        estimatedUnitPrice: 18.0,
        breakdownSummary: cross120Cartons > 0 ? '$cross120Cartons ك + $cross120Loose حبة' : '$cross120Loose حبة',
        calculationFormulaNote: 'المساحة × 1.25 عرضية/م²',
      ),
    ];

    return DecorationProjectEstimate(
      projectType: DecorationProjectType.ceiling,
      projectTitle: 'مقايسة سقف مستعار وجبس ($areaM2 م²)',
      primaryDimension: areaM2,
      items: items,
    );
  }

  // -------------------------------------------------------------
  // 2. حساب مقايسة بديل الخشب الجداري (WPC Fluted Panels)
  // -------------------------------------------------------------
  static DecorationProjectEstimate estimateWpcWoodProject({
    required double wallWidthM,
    required double wallHeightM,
    double panelWidthCm = 16.0,
    double panelLengthM = 2.90,
    double wastageRate = 0.05,
  }) {
    if (wallWidthM <= 0) wallWidthM = 1.0;
    if (wallHeightM <= 0) wallHeightM = 2.80;

    final wallWidthCm = wallWidthM * 100.0;
    final panelsAcrossWidth = (wallWidthCm / panelWidthCm);
    final verticalSections = (wallHeightM / panelLengthM).ceil();

    final rawPanels = panelsAcrossWidth * verticalSections;
    final totalPanels = (rawPanels * (1.0 + wastageRate)).ceilToDouble();

    // عدد كراتين بديل الخشب (الكرتونة بها عادة 14 شريحة)
    const cartonCapacity = 14;
    final fullCartons = (totalPanels / cartonCapacity).floor();
    final loosePanels = (totalPanels % cartonCapacity).toInt();

    // زوايا وحليات إغلاق WPC (U/L Edge Trims) - شريحة لكل بداية ونهاية جدار أو زاوية (1 زاوية لكل 3 متر عرض أو زوايا)
    final edgeTrimsCount = math.max(2.0, (wallWidthM / 2.5).ceilToDouble());

    // سيليكون وغراء تثبيت تركي/ألماني قوي (أنبوب لكل 3.5 شريحة)
    final glueTubesCount = (totalPanels / 3.5).ceilToDouble();

    final items = [
      DecorationItemEstimate(
        role: DecorationItemRole.mainPanel,
        itemName: 'شريحة بديل خشب WPC مضلع (${panelWidthCm.toInt()} سم × ${panelLengthM} م)',
        categoryHint: 'بدائل الخشب والرخام',
        quantity: totalPanels,
        unit: 'شريحة',
        fullCartons: fullCartons,
        loosePieces: loosePanels,
        cartonCapacity: cartonCapacity,
        estimatedUnitPrice: 38.0,
        breakdownSummary: fullCartons > 0 ? '$fullCartons كرتونة + $loosePanels شريحة' : '$loosePanels شريحة',
        calculationFormulaNote: 'عرض الجدار $wallWidthM م ÷ ${panelWidthCm} سم + ${(wastageRate * 100).toInt()}% هالك',
      ),
      DecorationItemEstimate(
        role: DecorationItemRole.edgeTrim,
        itemName: 'زاوية إغلاق وحلية بديل خشب (U/L Profile)',
        categoryHint: 'زوايا وإكسسوارات',
        quantity: edgeTrimsCount,
        unit: 'حبة',
        fullCartons: 0,
        loosePieces: edgeTrimsCount.toInt(),
        cartonCapacity: 20,
        estimatedUnitPrice: 20.0,
        breakdownSummary: '${edgeTrimsCount.toInt()} حبة للأطراف والزوايا',
        calculationFormulaNote: 'إغلاق طرفي الجدار والزوايا القائمة',
      ),
      DecorationItemEstimate(
        role: DecorationItemRole.adhesive,
        itemName: 'غراء سيليكون تثبيت قوي (Nail-Free Adhesive)',
        categoryHint: 'لواصق ومعجون',
        quantity: glueTubesCount,
        unit: 'أنبوب',
        fullCartons: (glueTubesCount / 24).floor(),
        loosePieces: (glueTubesCount % 24).toInt(),
        cartonCapacity: 24,
        estimatedUnitPrice: 18.0,
        breakdownSummary: '${glueTubesCount.toInt()} أنبوب للتثبيت المباشر',
        calculationFormulaNote: 'أنبوب واحد لكل 3.5 شريحة خشب',
      ),
    ];

    return DecorationProjectEstimate(
      projectType: DecorationProjectType.wpcWood,
      projectTitle: 'مقايسة بديل خشب ($wallWidthM م × $wallHeightM م)',
      primaryDimension: wallWidthM,
      secondaryDimension: wallHeightM,
      items: items,
    );
  }

  // -------------------------------------------------------------
  // 3. حساب مقايسة بديل الرخام (PVC Marble Sheets & Aluminum Profiles)
  // -------------------------------------------------------------
  static DecorationProjectEstimate estimatePvcMarbleProject({
    required double wallWidthM,
    required double wallHeightM,
    double sheetWidthM = 1.22,
    double sheetHeightM = 2.80,
    double wastageRate = 0.05,
  }) {
    if (wallWidthM <= 0) wallWidthM = 1.22;
    if (wallHeightM <= 0) wallHeightM = 2.80;

    final wallArea = wallWidthM * wallHeightM;
    final sheetArea = sheetWidthM * sheetHeightM;

    final rawSheets = (wallArea / sheetArea);
    final totalSheets = (rawSheets * (1.0 + wastageRate)).ceilToDouble();

    // فواصل ألومنيوم ذهبي/فضي H-Profile (فاصل بين كل لوحين متجاورين)
    final hProfilesCount = math.max(0.0, (wallWidthM / sheetWidthM).floorToDouble() - 1.0);

    // زوايا إغلاق L-Profile للأطراف العلوية والجانبية
    final lProfilesCount = math.max(2.0, ((wallWidthM + (wallHeightM * 2)) / 2.80).ceilToDouble());

    // غراء بولي يوريثان / سيليكون قوي (أنبوب لكل 1.5 لوح رخام)
    final glueTubesCount = (totalSheets / 1.5).ceilToDouble();

    final items = [
      DecorationItemEstimate(
        role: DecorationItemRole.mainPanel,
        itemName: 'لوح بديل رخام PVC مقاس ($sheetWidthM م × $sheetHeightM م)',
        categoryHint: 'بدائل الخشب والرخام',
        quantity: totalSheets,
        unit: 'لوح',
        fullCartons: 0,
        loosePieces: totalSheets.toInt(),
        cartonCapacity: 1,
        estimatedUnitPrice: 85.0,
        breakdownSummary: '${totalSheets.toInt()} لوح رخام كامل',
        calculationFormulaNote: 'المساحة ${(wallArea).toStringAsFixed(1)} م² ÷ مساحة اللوح ${(sheetArea).toStringAsFixed(2)} م²',
      ),
      if (hProfilesCount > 0)
        DecorationItemEstimate(
          role: DecorationItemRole.crossProfile,
          itemName: 'فاصل ألومنيوم ديكوري H-Profile ذهبي/فضي (2.8 م)',
          categoryHint: 'زوايا وإكسسوارات',
          quantity: hProfilesCount,
          unit: 'عود',
          fullCartons: 0,
          loosePieces: hProfilesCount.toInt(),
          cartonCapacity: 25,
          estimatedUnitPrice: 25.0,
          breakdownSummary: '${hProfilesCount.toInt()} عود فواصل بين الألواح',
          calculationFormulaNote: 'فاصل H بين كل لوحين متجاورين',
        ),
      DecorationItemEstimate(
        role: DecorationItemRole.edgeTrim,
        itemName: 'زاوية ألومنيوم إغلاق L-Profile للأطراف (2.8 م)',
        categoryHint: 'زوايا وإكسسوارات',
        quantity: lProfilesCount,
        unit: 'عود',
        fullCartons: 0,
        loosePieces: lProfilesCount.toInt(),
        cartonCapacity: 25,
        estimatedUnitPrice: 22.0,
        breakdownSummary: '${lProfilesCount.toInt()} عود زوايا أطراف',
        calculationFormulaNote: 'إغلاق الأطراف الجانبية والعلوية للوح',
      ),
      DecorationItemEstimate(
        role: DecorationItemRole.adhesive,
        itemName: 'غراء بولي يوريثان عالي الالتصاق لبديل الرخام',
        categoryHint: 'لواصق ومعجون',
        quantity: glueTubesCount,
        unit: 'أنبوب',
        fullCartons: (glueTubesCount / 24).floor(),
        loosePieces: (glueTubesCount % 24).toInt(),
        cartonCapacity: 24,
        estimatedUnitPrice: 22.0,
        breakdownSummary: '${glueTubesCount.toInt()} أنبوب للتثبيت',
        calculationFormulaNote: 'أنبوب واحد لكل 1.5 لوح رخام',
      ),
    ];

    return DecorationProjectEstimate(
      projectType: DecorationProjectType.pvcMarble,
      projectTitle: 'مقايسة بديل رخام ($wallWidthM م × $wallHeightM م)',
      primaryDimension: wallWidthM,
      secondaryDimension: wallHeightM,
      items: items,
    );
  }

  // -------------------------------------------------------------
  // 4. حساب مقايسة إطارات وبانوهات الفوم (Foam Wall Frames & Moldings)
  // -------------------------------------------------------------
  static DecorationProjectEstimate estimateFoamFramesProject({
    required int frameCount,
    required double frameWidthM,
    required double frameHeightM,
    double stickLengthM = 2.40,
    double wastageRate = 0.10,
  }) {
    if (frameCount <= 0) frameCount = 1;
    if (frameWidthM <= 0) frameWidthM = 1.0;
    if (frameHeightM <= 0) frameHeightM = 1.0;

    // محيط الإطار الواحد = 2 × (العرض + الارتفاع)
    final perimeterPerFrame = 2.0 * (frameWidthM + frameHeightM);
    final totalLinearMeters = frameCount * perimeterPerFrame;

    // حساب عدد الأعواد مع 10% هالك لقص الزوايا 45 درجة (مع معالجة الدقة العشرية)
    final totalMetersWithWastage = totalLinearMeters * (1.0 + wastageRate);
    final totalSticks = ((totalMetersWithWastage / stickLengthM) - 1e-7).ceilToDouble();

    // زوايا ديكورية منقوشة (4 زوايا لكل إطار)
    final cornersCount = (frameCount * 4).toDouble();

    // علب معجون وغراء زوايا ميتريكس (علبة لكل 20 متر طولي)
    final fillerCount = math.max(1.0, (totalLinearMeters / 20.0).ceilToDouble());

    final items = [
      DecorationItemEstimate(
        role: DecorationItemRole.mainStructure,
        itemName: 'عود بانوه فوم بوليريثان جداري (${stickLengthM} م)',
        categoryHint: 'فوم وبانوهات جدارية',
        quantity: totalSticks,
        unit: 'عود',
        fullCartons: (totalSticks / 20).floor(),
        loosePieces: (totalSticks % 20).toInt(),
        cartonCapacity: 20,
        estimatedUnitPrice: 16.0,
        breakdownSummary: '${totalSticks.toInt()} عود (${totalLinearMeters.toStringAsFixed(1)} م طولي)',
        calculationFormulaNote: '$frameCount إطار × ${perimeterPerFrame.toStringAsFixed(1)} م محيط + 10% هالك زوايا 45°',
      ),
      DecorationItemEstimate(
        role: DecorationItemRole.edgeTrim,
        itemName: 'زاوية إطار بانوه فوم ديكورية منقوشة',
        categoryHint: 'فوم وبانوهات جدارية',
        quantity: cornersCount,
        unit: 'حبة',
        fullCartons: 0,
        loosePieces: cornersCount.toInt(),
        cartonCapacity: 50,
        estimatedUnitPrice: 5.0,
        breakdownSummary: '${cornersCount.toInt()} زاوية لـ $frameCount إطار',
        calculationFormulaNote: '4 زوايا قائمة لكل إطار بانوه',
      ),
      DecorationItemEstimate(
        role: DecorationItemRole.filler,
        itemName: 'معجون وفيلر فواصل وأركان إطارات الفوم',
        categoryHint: 'لواصق ومعجون',
        quantity: fillerCount,
        unit: 'علبة',
        fullCartons: 0,
        loosePieces: fillerCount.toInt(),
        cartonCapacity: 12,
        estimatedUnitPrice: 14.0,
        breakdownSummary: '${fillerCount.toInt()} علبة معجون للأركان',
        calculationFormulaNote: 'علبة معجون لكل 20 متر طولي',
      ),
    ];

    return DecorationProjectEstimate(
      projectType: DecorationProjectType.wallFoam,
      projectTitle: 'مقايسة بانوهات فوم ($frameCount إطار - ${frameWidthM}×${frameHeightM} م)',
      primaryDimension: totalLinearMeters,
      items: items,
    );
  }

  /// مطابقة الصنف في المستودع المحلي بناءً على تلميح الفئة والاسم
  static ItemModel? findMatchingWarehouseItem(DecorationItemEstimate estimate, List<ItemModel> warehouseItems) {
    if (warehouseItems.isEmpty) return null;

    final targetName = estimate.itemName.toLowerCase();

    // 1. بحث بالاسم الدقيق أو الجزئي
    for (var item in warehouseItems) {
      final name = item.name.toLowerCase();
      if (name.contains(targetName) || targetName.contains(name)) {
        return item;
      }
    }

    // 2. بحث بالتصنيف والكلمات المفتاحية المحددة لكل مادة
    for (var item in warehouseItems) {
      final cat = item.category.toLowerCase();
      final name = item.name.toLowerCase();

      if (estimate.role == DecorationItemRole.mainPanel || estimate.role == DecorationItemRole.mainStructure) {
        if (targetName.contains('خشب') && (name.contains('خشب') || cat.contains('خشب'))) {
          return item;
        }
        if (targetName.contains('رخام') && (name.contains('رخام') || cat.contains('رخام'))) {
          return item;
        }
        if ((targetName.contains('جبس') || targetName.contains('بلاط')) &&
            (name.contains('جبس') || name.contains('بلاط') || cat.contains('جبس') || cat.contains('بلاط'))) {
          return item;
        }
        if ((targetName.contains('فوم') || targetName.contains('بانوه')) &&
            (name.contains('فوم') || name.contains('بانوه') || cat.contains('فوم') || cat.contains('بانوه'))) {
          return item;
        }
        if (targetName.contains('جسر') && (name.contains('جسر') || name.contains('main tee'))) {
          return item;
        }
      } else if (estimate.role == DecorationItemRole.adhesive) {
        if (name.contains('غراء') || name.contains('سيليكون') || name.contains('لاصق') || cat.contains('لواصق')) {
          return item;
        }
      } else if (estimate.role == DecorationItemRole.edgeTrim || estimate.role == DecorationItemRole.crossProfile) {
        if (targetName.contains('زاوية') && name.contains('زاوية')) return item;
        if (targetName.contains('فاصل') && (name.contains('فاصل') || name.contains('h-profile'))) return item;
        if (targetName.contains('عرضية') && (name.contains('عرضية') || name.contains('cross'))) return item;
      }
    }

    return null;
  }
}
