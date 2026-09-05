/// Mirrors the backend's `Erp.Domain.Common.StockMovementType` enum — ordinal-matched, since the
/// API serializes enums as their integer index (no JsonStringEnumConverter registered).
enum StockMovementType { opening, purchase, sale, returned, adjustment, reversal }

/// Mirrors `Erp.Domain.Common.DocumentReferenceType`.
enum DocumentReferenceType { quotation, proformaInvoice, salesInvoice, purchaseReceipt, salesReturn, manualAdjustment, expense }

extension StockMovementTypeLabel on StockMovementType {
  String get label => switch (this) {
        StockMovementType.opening => 'Opening',
        StockMovementType.purchase => 'Purchase',
        StockMovementType.sale => 'Sale',
        StockMovementType.returned => 'Return',
        StockMovementType.adjustment => 'Adjustment',
        StockMovementType.reversal => 'Reversal',
      };
}

extension DocumentReferenceTypeLabel on DocumentReferenceType {
  String get label => switch (this) {
        DocumentReferenceType.quotation => 'Quotation',
        DocumentReferenceType.proformaInvoice => 'Proforma Invoice',
        DocumentReferenceType.salesInvoice => 'Sales Invoice',
        DocumentReferenceType.purchaseReceipt => 'Purchase Receipt',
        DocumentReferenceType.salesReturn => 'Sales Return',
        DocumentReferenceType.manualAdjustment => 'Manual Adjustment',
        DocumentReferenceType.expense => 'Expense',
      };
}

/// One row of the append-only stock ledger (`StockMovementDto` from `GET /api/stock/movements`).
class StockMovement {
  final String id;
  final String itemId;
  final String? batchId;
  final StockMovementType movementType;
  final double quantityDelta;
  final double quantityBefore;
  final double quantityAfter;
  final DocumentReferenceType referenceType;
  final String referenceId;
  final String? reason;
  final DateTime createdAt;

  StockMovement({
    required this.id,
    required this.itemId,
    this.batchId,
    required this.movementType,
    required this.quantityDelta,
    required this.quantityBefore,
    required this.quantityAfter,
    required this.referenceType,
    required this.referenceId,
    this.reason,
    required this.createdAt,
  });

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
        id: json['id'] as String,
        itemId: json['itemId'] as String,
        batchId: json['batchId'] as String?,
        movementType: StockMovementType.values[json['movementType'] as int],
        quantityDelta: (json['quantityDelta'] as num).toDouble(),
        quantityBefore: (json['quantityBefore'] as num).toDouble(),
        quantityAfter: (json['quantityAfter'] as num).toDouble(),
        referenceType: DocumentReferenceType.values[json['referenceType'] as int],
        referenceId: json['referenceId'] as String,
        reason: json['reason'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
