import 'product_unit_model.dart';

class ItemModel {
  final String code;
  final String name;
  final String category;
  final String legacyUnit; // Base Unit fallback (e.g., متر, حبة, كجم)
  final String? legacyPackagingUnit; // Optional Packaging Unit fallback
  final double legacyConversionFactor; // Factor fallback
  final double currentStock; // ALWAYS stored in Base Unit
  final double unitPrice; // Default selling price per Base Unit
  final String location;
  final String? size; // المقاس (مثل: 60x60 سم)
  final String? color; // اللون (مثل: رمادي كلاسيك)
  final String? finishType; // النوع / الفرز (مثل: فرز أول مط)
  final List<ProductUnitModel> units;

  ItemModel({
    required this.code,
    required this.name,
    required this.category,
    required this.legacyUnit,
    this.legacyPackagingUnit,
    this.legacyConversionFactor = 1.0,
    required this.currentStock,
    this.unitPrice = 25.0,
    this.location = 'ممر A - رف 1',
    this.size,
    this.color,
    this.finishType,
    List<ProductUnitModel>? units,
  }) : units = units ?? _buildDefaultUnits(code, legacyUnit, legacyPackagingUnit, legacyConversionFactor, unitPrice);

  // Backward compatibility getters
  String get unit => baseUnit.unitName;
  String? get packagingUnit => primaryPackagingUnit?.unitName;
  double get conversionFactor => primaryPackagingUnit?.conversionFactor ?? legacyConversionFactor;

  ProductUnitModel get baseUnit {
    return units.firstWhere(
      (u) => u.isBase,
      orElse: () => ProductUnitModel(
        id: 'base-$code',
        productCode: code,
        unitName: legacyUnit.isNotEmpty ? legacyUnit : 'حبة',
        unitType: ProductUnitModel.inferUnitType(legacyUnit),
        conversionFactor: 1.0,
        isBase: true,
        salePrice: unitPrice,
      ),
    );
  }

  ProductUnitModel? get primaryPackagingUnit {
    final nonBase = units.where((u) => !u.isBase && u.isActive).toList();
    if (nonBase.isNotEmpty) return nonBase.first;
    if (legacyPackagingUnit != null && legacyPackagingUnit!.isNotEmpty) {
      return ProductUnitModel(
        id: 'pkg-$code',
        productCode: code,
        unitName: legacyPackagingUnit!,
        unitType: ProductUnitModel.inferUnitType(legacyPackagingUnit!),
        conversionFactor: legacyConversionFactor,
        isBase: false,
        salePrice: unitPrice * legacyConversionFactor,
      );
    }
    return null;
  }

  ProductUnitModel? getUnitByName(String unitName) {
    final query = unitName.trim().toLowerCase();
    for (var u in units) {
      if (u.unitName.trim().toLowerCase() == query) return u;
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'name': name,
      'category': category,
      'unit': unit,
      'packaging_unit': packagingUnit,
      'conversion_factor': conversionFactor,
      'current_stock': currentStock,
      'unit_price': unitPrice,
      'location': location,
      'size': size,
      'color': color,
      'finish_type': finishType,
      'units': units.map((u) => u.toMap()).toList(),
    };
  }

  factory ItemModel.fromMap(Map<String, dynamic> map, {List<ProductUnitModel>? loadedUnits}) {
    final code = map['code']?.toString() ?? '';
    final legacyU = map['unit'] ?? 'حبة';
    final legacyPkg = map['packaging_unit'];
    final legacyFactor = (map['conversion_factor'] as num?)?.toDouble() ?? 1.0;
    final price = (map['unit_price'] as num?)?.toDouble() ?? (map['price'] as num?)?.toDouble() ?? 25.0;

    List<ProductUnitModel> unitsList = loadedUnits ?? [];
    if (unitsList.isEmpty && map['units'] != null && map['units'] is List) {
      unitsList = (map['units'] as List)
          .map((u) => ProductUnitModel.fromMap(Map<String, dynamic>.from(u)))
          .toList();
    }

    if (unitsList.isEmpty) {
      unitsList = _buildDefaultUnits(code, legacyU, legacyPkg, legacyFactor, price);
    }

    return ItemModel(
      code: code,
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      legacyUnit: legacyU,
      legacyPackagingUnit: legacyPkg,
      legacyConversionFactor: legacyFactor,
      currentStock: (map['current_stock'] as num?)?.toDouble() ?? 0.0,
      unitPrice: price,
      location: map['location'] ?? 'ممر A - رف 1',
      size: map['size'],
      color: map['color'],
      finishType: map['finish_type'],
      units: unitsList,
    );
  }

  static List<ProductUnitModel> _buildDefaultUnits(
    String code,
    String baseUnitName,
    String? pkgUnitName,
    double factor,
    double price,
  ) {
    final List<ProductUnitModel> list = [];
    final baseName = baseUnitName.isNotEmpty ? baseUnitName : 'حبة';
    
    list.add(ProductUnitModel(
      id: 'base-$code',
      productCode: code,
      unitName: baseName,
      unitType: ProductUnitModel.inferUnitType(baseName),
      conversionFactor: 1.0,
      isBase: true,
      salePrice: price,
    ));

    if (pkgUnitName != null && pkgUnitName.isNotEmpty && pkgUnitName != baseName) {
      list.add(ProductUnitModel(
        id: 'pkg-$code',
        productCode: code,
        unitName: pkgUnitName,
        unitType: ProductUnitModel.inferUnitType(pkgUnitName),
        conversionFactor: factor > 0 ? factor : 1.0,
        isBase: false,
        salePrice: price * (factor > 0 ? factor : 1.0),
      ));
    }

    return list;
  }
}
