enum UnitType {
  weight,
  length,
  area,
  volume,
  count,
  packaging,
}

extension UnitTypeExtension on UnitType {
  String get displayName {
    switch (this) {
      case UnitType.weight:
        return 'وزن (كجم / طن)';
      case UnitType.length:
        return 'طول (متر / سم)';
      case UnitType.area:
        return 'مساحة (م² / متر مربع)';
      case UnitType.volume:
        return 'حجم (م³ / متر مكعب)';
      case UnitType.count:
        return 'عدد (حبة / قطعة)';
      case UnitType.packaging:
        return 'تعبئة (كرتونة / علبة / طبلية / ربطة / كيس)';
    }
  }

  int get defaultDecimalPrecision {
    switch (this) {
      case UnitType.weight:
      case UnitType.length:
      case UnitType.area:
      case UnitType.volume:
        return 3;
      case UnitType.count:
      case UnitType.packaging:
        return 0;
    }
  }
}

class ProductUnitModel {
  final String id;
  final String productCode;
  final String unitName;
  final UnitType unitType;
  final double conversionFactor; // Relative to Base Unit (Base = 1.0)
  final bool isBase;
  final bool isActive;
  final double? salePrice;
  final double? purchasePrice;

  ProductUnitModel({
    required this.id,
    required this.productCode,
    required this.unitName,
    required this.unitType,
    required this.conversionFactor,
    this.isBase = false,
    this.isActive = true,
    this.salePrice,
    this.purchasePrice,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'product_code': productCode,
      'unit_name': unitName,
      'unit_type': unitType.name,
      'conversion_factor': conversionFactor,
      'is_base': isBase ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'sale_price': salePrice,
      'purchase_price': purchasePrice,
    };
  }

  factory ProductUnitModel.fromMap(Map<String, dynamic> map) {
    UnitType parsedType = UnitType.count;
    final typeStr = map['unit_type']?.toString().toLowerCase() ?? '';
    if (typeStr.contains('weight') || typeStr.contains('وزن') || typeStr.contains('كجم') || typeStr.contains('طن')) {
      parsedType = UnitType.weight;
    } else if (typeStr.contains('area') || typeStr.contains('م²') || typeStr.contains('مربع')) {
      parsedType = UnitType.area;
    } else if (typeStr.contains('volume') || typeStr.contains('م³') || typeStr.contains('مكعب')) {
      parsedType = UnitType.volume;
    } else if (typeStr.contains('length') || typeStr.contains('طول') || typeStr.contains('متر')) {
      parsedType = UnitType.length;
    } else if (typeStr.contains('pack') || typeStr.contains('كرتون') || typeStr.contains('علبة') || typeStr.contains('طبلية') || typeStr.contains('ربطة')) {
      parsedType = UnitType.packaging;
    }

    return ProductUnitModel(
      id: map['id']?.toString() ?? 'u-${DateTime.now().millisecondsSinceEpoch}',
      productCode: map['product_code']?.toString() ?? '',
      unitName: map['unit_name'] ?? 'حبة',
      unitType: parsedType,
      conversionFactor: (map['conversion_factor'] as num?)?.toDouble() ?? 1.0,
      isBase: (map['is_base'] == 1 || map['is_base'] == true),
      isActive: (map['is_active'] == 1 || map['is_active'] == true || map['is_active'] == null),
      salePrice: (map['sale_price'] as num?)?.toDouble(),
      purchasePrice: (map['purchase_price'] as num?)?.toDouble(),
    );
  }

  static UnitType inferUnitType(String unitName) {
    final u = unitName.toLowerCase();
    if (u.contains('طن') || u.contains('كجم') || u.contains('جرام') || u.contains('kg') || u.contains('ton')) {
      return UnitType.weight;
    }
    if (u.contains('م²') || u.contains('متر مربع') || u.contains('مربع') || u.contains('sqm') || u.contains('m2')) {
      return UnitType.area;
    }
    if (u.contains('م³') || u.contains('متر مكعب') || u.contains('مكعب') || u.contains('cbm') || u.contains('m3')) {
      return UnitType.volume;
    }
    if (u.contains('متر') || u.contains('سم') || u.contains('طول') || u.contains('meter')) {
      return UnitType.length;
    }
    if (u.contains('كرتون') || u.contains('طبلية') || u.contains('علبة') || u.contains('باك') || u.contains('ربطة') || u.contains('كيس') || u.contains('حزمة') || u.contains('box') || u.contains('carton') || u.contains('pallet')) {
      return UnitType.packaging;
    }
    return UnitType.count;
  }
}
