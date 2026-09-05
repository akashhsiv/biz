class StockLevel {
  final String itemId;
  final String sku;
  final String name;
  final double quantityOnHand;
  final bool isBatchTracked;
  final bool isSerialTracked;

  StockLevel({
    required this.itemId,
    required this.sku,
    required this.name,
    required this.quantityOnHand,
    required this.isBatchTracked,
    this.isSerialTracked = false,
  });

  factory StockLevel.fromJson(Map<String, dynamic> json) => StockLevel(
        itemId: json['itemId'] as String,
        sku: json['sku'] as String,
        name: json['name'] as String,
        quantityOnHand: (json['quantityOnHand'] as num).toDouble(),
        isBatchTracked: json['isBatchTracked'] as bool,
        isSerialTracked: json['isSerialTracked'] as bool? ?? false,
      );
}

