import '../reports/document_payment_status.dart';

enum PurchaseOrderStatus { draft, submitted, processing, partiallyCompleted, completed, cancelled }

enum PurchasePaymentStatus { processing, completed, cancelled }

class PurchaseOrderLine {
  final String id;
  final String itemId;
  final double quantityOrdered;
  final double quantityReceived;
  final double rate;
  final double lineTotal;

  PurchaseOrderLine({
    required this.id,
    required this.itemId,
    required this.quantityOrdered,
    required this.quantityReceived,
    required this.rate,
    required this.lineTotal,
  });

  factory PurchaseOrderLine.fromJson(Map<String, dynamic> json) => PurchaseOrderLine(
        id: json['id'] as String,
        itemId: json['itemId'] as String,
        quantityOrdered: (json['quantityOrdered'] as num).toDouble(),
        quantityReceived: (json['quantityReceived'] as num).toDouble(),
        rate: (json['rate'] as num).toDouble(),
        lineTotal: (json['lineTotal'] as num).toDouble(),
      );
}

class PurchasePayment {
  final String id;
  final String purchaseOrderId;
  final double amount;
  final PurchasePaymentStatus status;
  final String? paymentMethod;

  PurchasePayment({required this.id, required this.purchaseOrderId, required this.amount, required this.status, this.paymentMethod});

  factory PurchasePayment.fromJson(Map<String, dynamic> json) => PurchasePayment(
        id: json['id'] as String,
        purchaseOrderId: json['purchaseOrderId'] as String,
        amount: (json['amount'] as num).toDouble(),
        status: PurchasePaymentStatus.values[json['status'] as int],
        paymentMethod: json['paymentMethod'] as String?,
      );
}

class PurchaseOrder {
  final String id;
  final String poNumber;
  final String supplierId;
  final String categoryId;
  final PurchaseOrderStatus status;
  final PurchasePaymentStatus paymentStatus;
  final DateTime? dueDate;
  final DocumentPaymentStatus balancePaymentStatus;
  final double outstandingTotal;
  final double grandTotal;
  final List<PurchaseOrderLine> lines;
  final List<PurchasePayment> payments;
  final DateTime createdAt;
  final String createdBy;

  PurchaseOrder({
    required this.id,
    required this.poNumber,
    required this.supplierId,
    required this.categoryId,
    required this.status,
    required this.paymentStatus,
    this.dueDate,
    this.balancePaymentStatus = DocumentPaymentStatus.paid,
    this.outstandingTotal = 0,
    required this.grandTotal,
    required this.lines,
    required this.payments,
    required this.createdAt,
    required this.createdBy,
  });

  factory PurchaseOrder.fromJson(Map<String, dynamic> json) => PurchaseOrder(
        id: json['id'] as String,
        poNumber: json['poNumber'] as String,
        supplierId: json['supplierId'] as String,
        categoryId: json['categoryId'] as String? ?? '',
        status: PurchaseOrderStatus.values[json['status'] as int],
        paymentStatus: PurchasePaymentStatus.values[json['paymentStatus'] as int],
        dueDate: json['dueDate'] == null ? null : DateTime.parse(json['dueDate'] as String),
        balancePaymentStatus: DocumentPaymentStatus.values[json['balancePaymentStatus'] as int? ?? 0],
        outstandingTotal: (json['outstandingTotal'] as num?)?.toDouble() ?? 0,
        grandTotal: (json['grandTotal'] as num).toDouble(),
        lines: (json['lines'] as List).map((e) => PurchaseOrderLine.fromJson(e as Map<String, dynamic>)).toList(),
        payments: (json['payments'] as List).map((e) => PurchasePayment.fromJson(e as Map<String, dynamic>)).toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        createdBy: json['createdBy'] as String? ?? '',
      );
}
