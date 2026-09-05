enum SalesReturnStatus { requested, approved, rejected, completed, cancelled }

class SalesReturnLine {
  final String id;
  final String salesInvoiceLineId;
  final String description;
  final double quantityReturned;
  final double refundAmount;
  final bool restock;

  SalesReturnLine({
    required this.id,
    required this.salesInvoiceLineId,
    this.description = '',
    required this.quantityReturned,
    required this.refundAmount,
    required this.restock,
  });

  factory SalesReturnLine.fromJson(Map<String, dynamic> json) => SalesReturnLine(
        id: json['id'] as String,
        salesInvoiceLineId: json['salesInvoiceLineId'] as String,
        description: json['description'] as String? ?? '',
        quantityReturned: (json['quantityReturned'] as num).toDouble(),
        refundAmount: (json['refundAmount'] as num).toDouble(),
        restock: json['restock'] as bool,
      );
}

class SalesReturn {
  final String id;
  final String returnNumber;
  final String salesInvoiceId;
  final String customerId;
  final SalesReturnStatus status;
  final String? reason;
  final double totalRefundAmount;
  final List<SalesReturnLine> lines;
  final DateTime createdAt;

  SalesReturn({
    required this.id,
    required this.returnNumber,
    required this.salesInvoiceId,
    required this.customerId,
    required this.status,
    this.reason,
    required this.totalRefundAmount,
    required this.lines,
    required this.createdAt,
  });

  factory SalesReturn.fromJson(Map<String, dynamic> json) => SalesReturn(
        id: json['id'] as String,
        returnNumber: json['returnNumber'] as String,
        salesInvoiceId: json['salesInvoiceId'] as String,
        customerId: json['customerId'] as String,
        status: SalesReturnStatus.values[json['status'] as int],
        reason: json['reason'] as String?,
        totalRefundAmount: (json['totalRefundAmount'] as num).toDouble(),
        lines: (json['lines'] as List).map((e) => SalesReturnLine.fromJson(e as Map<String, dynamic>)).toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
