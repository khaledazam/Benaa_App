import '../../data/models/item_model.dart';
import '../../data/models/product_unit_model.dart';

class UnitQuantityInput {
  final String unitName;
  final double quantity;

  UnitQuantityInput({
    required this.unitName,
    required this.quantity,
  });

  Map<String, dynamic> toMap() => {
        'unit_name': unitName,
        'quantity': quantity,
      };
}

class StockMovementSnapshot {
  final String transactionId;
  final String transactionType; // SALE, PURCHASE, TRANSFER, ADJUSTMENT, AUDIT, OPENING
  final String productCode;
  final double enteredQuantity;
  final String enteredUnit;
  final double conversionFactor; // Historical snapshot factor
  final double baseQuantity;
  final String baseUnit;
  final String date;
  final String? notes;

  StockMovementSnapshot({
    required this.transactionId,
    required this.transactionType,
    required this.productCode,
    required this.enteredQuantity,
    required this.enteredUnit,
    required this.conversionFactor,
    required this.baseQuantity,
    required this.baseUnit,
    required this.date,
    this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': transactionId,
        'transaction_type': transactionType,
        'product_code': productCode,
        'entered_quantity': enteredQuantity,
        'entered_unit': enteredUnit,
        'conversion_factor': conversionFactor,
        'base_quantity': baseQuantity,
        'base_unit': baseUnit,
        'created_at': date,
        'notes': notes,
      };
}

class UnitConversionEngine {
  /// Converts a given quantity in any unit of a product to its Base Unit quantity.
  static double convertToBaseUnit({
    required ItemModel item,
    required String unitName,
    required double quantity,
  }) {
    if (quantity <= 0) return 0.0;
    final targetUnit = item.getUnitByName(unitName);
    if (targetUnit == null) {
      throw ArgumentError("الوحدة '$unitName' غير مسجلة للمنتج [${item.code}] ${item.name}");
    }
    if (!targetUnit.isActive) {
      throw StateError("الوحدة '$unitName' معطلة حالياً للمنتج [${item.code}]");
    }
    if (targetUnit.conversionFactor <= 0) {
      throw ArgumentError("معامل التحويل للوحدة '$unitName' يجب أن يكون أكبر من 0");
    }

    final result = quantity * targetUnit.conversionFactor;
    return double.parse(result.toStringAsFixed(6)).clamp(0.0, double.infinity);
  }

  /// Converts a Base Unit quantity to a target Product Unit quantity.
  static double convertFromBaseUnit({
    required ItemModel item,
    required String targetUnitName,
    required double baseQuantity,
  }) {
    final targetUnit = item.getUnitByName(targetUnitName);
    if (targetUnit == null) {
      throw ArgumentError("الوحدة '$targetUnitName' غير مسجلة للمنتج [${item.code}] ${item.name}");
    }
    if (targetUnit.conversionFactor <= 0) {
      throw ArgumentError("معامل التحويل للوحدة '$targetUnitName' يجب أن يكون أكبر من 0");
    }

    final result = baseQuantity / targetUnit.conversionFactor;
    return double.parse(result.toStringAsFixed(6)).clamp(0.0, double.infinity);
  }

  /// Converts a quantity from one unit to another unit for a specific product.
  static double convertQuantity({
    required ItemModel item,
    required String fromUnit,
    required String toUnit,
    required double quantity,
  }) {
    final baseQty = convertToBaseUnit(item: item, unitName: fromUnit, quantity: quantity);
    return convertFromBaseUnit(item: item, targetUnitName: toUnit, baseQuantity: baseQty);
  }

  /// Calculates total Base Unit quantity from mixed hybrid inputs (e.g. 3 Cartons + 5 Pieces).
  static double calculateHybridQuantity({
    required ItemModel item,
    required List<UnitQuantityInput> inputs,
  }) {
    validateHybridInput(item: item, inputs: inputs);

    double totalBaseQty = 0.0;
    for (var input in inputs) {
      totalBaseQty += convertToBaseUnit(
        item: item,
        unitName: input.unitName,
        quantity: input.quantity,
      );
    }
    return double.parse(totalBaseQty.toStringAsFixed(6));
  }

  /// Validates that units belong to the product and are active.
  static bool validateHybridInput({
    required ItemModel item,
    required List<UnitQuantityInput> inputs,
  }) {
    if (inputs.isEmpty) {
      throw ArgumentError("يجب إدخال كميات صالحة");
    }

    final unitNames = inputs.map((i) => i.unitName).toList();
    if (!validateUnitCompatibility(item: item, units: unitNames)) {
      throw ArgumentError("تحتوي المدخلات على وحدات غير متوافقة أو غير مسجلة للمنتج [${item.name}]");
    }

    for (var input in inputs) {
      if (input.quantity < 0) {
        throw ArgumentError("لا يمكن إدخال كميات سالبة");
      }
    }

    return true;
  }

  /// Validates that all unit names exist for the given product.
  static bool validateUnitCompatibility({
    required ItemModel item,
    required List<String> units,
  }) {
    for (var unitName in units) {
      final unit = item.getUnitByName(unitName);
      if (unit == null || !unit.isActive) {
        return false;
      }
    }
    return true;
  }

  /// Formats quantity with appropriate decimal precision based on UnitType.
  static String formatQuantity({
    required double quantity,
    required UnitType unitType,
    int? precision,
  }) {
    final decimals = precision ?? unitType.defaultDecimalPrecision;
    if (decimals == 0) {
      return quantity.round().toString();
    }
    return quantity.toStringAsFixed(decimals).replaceAll(RegExp(r'\.?0+$'), '');
  }

  /// Generates a historical transaction snapshot preserving the conversion factor used at transaction time.
  static StockMovementSnapshot createHistoricalSnapshot({
    required String transactionId,
    required String transactionType,
    required ItemModel item,
    required String enteredUnit,
    required double enteredQuantity,
    String? notes,
  }) {
    final unit = item.getUnitByName(enteredUnit);
    final factor = unit?.conversionFactor ?? 1.0;
    final baseQty = convertToBaseUnit(item: item, unitName: enteredUnit, quantity: enteredQuantity);

    return StockMovementSnapshot(
      transactionId: transactionId,
      transactionType: transactionType,
      productCode: item.code,
      enteredQuantity: enteredQuantity,
      enteredUnit: enteredUnit,
      conversionFactor: factor,
      baseQuantity: baseQty,
      baseUnit: item.unit,
      date: DateTime.now().toIso8601String(),
      notes: notes,
    );
  }
}
