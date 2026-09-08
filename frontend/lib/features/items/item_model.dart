enum ItemKind { stock, nonStock }

class Item {
  final String id;
  final String sku;
  final String name;
  final String? categoryId;
  final String? brandId;
  final String unit;
  final ItemKind itemKind;
  final double purchasePrice;
  final double sellingPrice;
  final double taxRatePercent;
  final String? hsnCode;
  final bool isBatchTracked;
  final bool isSerialTracked;
  final bool isActive;
  final double stockOnHand;

  Item({
    required this.id,
    required this.sku,
    required this.name,
    this.categoryId,
    this.brandId,
    required this.unit,
    required this.itemKind,
    required this.purchasePrice,
    required this.sellingPrice,
    this.taxRatePercent = 0,
    this.hsnCode,
    required this.isBatchTracked,
    this.isSerialTracked = false,
    required this.isActive,
    required this.stockOnHand,
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: json['id'] as String,
        sku: json['sku'] as String,
        name: json['name'] as String,
        categoryId: json['categoryId'] as String?,
        brandId: json['brandId'] as String?,
        unit: json['unit'] as String,
        itemKind: ItemKind.values[json['itemKind'] as int],
        purchasePrice: (json['purchasePrice'] as num).toDouble(),
        sellingPrice: (json['sellingPrice'] as num).toDouble(),
        taxRatePercent: (json['taxRatePercent'] as num).toDouble(),
        hsnCode: json['hsnCode'] as String?,
        isBatchTracked: json['isBatchTracked'] as bool,
        isSerialTracked: json['isSerialTracked'] as bool? ?? false,
        isActive: json['isActive'] as bool,
        stockOnHand: (json['stockOnHand'] as num).toDouble(),
      );
}

/// Common shop-inventory units — kept as a preset list so entry stays consistent (e.g. always
/// "pcs" not a mix of "pcs"/"pc"/"piece"), with a fallback so an existing item saved with some
/// other value still shows correctly in the dropdown instead of throwing.
const List<String> commonItemUnits = ['pcs', 'kg', 'g', 'ltr', 'ml', 'box', 'dozen', 'meter', 'pair', 'set'];
