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

class StockMovement {
  final String id;
  final String itemId;
  final int movementType;
  final double quantityDelta;
  final double quantityAfter;
  final String? reason;
  final DateTime createdAt;

  StockMovement({
    required this.id,
    required this.itemId,
    required this.movementType,
    required this.quantityDelta,
    required this.quantityAfter,
    this.reason,
    required this.createdAt,
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
        id: json['id'] as String,
        itemId: json['itemId'] as String,
        movementType: json['movementType'] as int,
        quantityDelta: (json['quantityDelta'] as num).toDouble(),
        quantityAfter: (json['quantityAfter'] as num).toDouble(),
        reason: json['reason'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

const movementTypeNames = ['Opening', 'Purchase', 'Sale', 'Return', 'Adjustment', 'Reversal'];
