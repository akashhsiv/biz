enum CommissionEntryStatus { pending, partiallyPaid, paid, cancelled, adjusted }

String commissionEntryStatusLabel(CommissionEntryStatus s) => switch (s) {
      CommissionEntryStatus.pending => 'Pending',
      CommissionEntryStatus.partiallyPaid => 'Partially Paid',
      CommissionEntryStatus.paid => 'Paid',
      CommissionEntryStatus.cancelled => 'Cancelled',
      CommissionEntryStatus.adjusted => 'Adjusted',
    };

class CustomerProductRate {
  final String id;
  final String customerId;
  final String customerName;
  final String itemId;
  final String itemName;
  final double? specialRate;
  final double? commissionRate;
  final DateTime effectiveFrom;
  final bool isActive;

  CustomerProductRate({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.itemId,
    required this.itemName,
    this.specialRate,
    this.commissionRate,
    required this.effectiveFrom,
    required this.isActive,
  });

  factory CustomerProductRate.fromJson(Map<String, dynamic> json) => CustomerProductRate(
        id: json['id'] as String,
        customerId: json['customerId'] as String,
        customerName: json['customerName'] as String,
        itemId: json['itemId'] as String,
        itemName: json['itemName'] as String,
        specialRate: (json['specialRate'] as num?)?.toDouble(),
        commissionRate: (json['commissionRate'] as num?)?.toDouble(),
        effectiveFrom: DateTime.parse(json['effectiveFrom'] as String),
        isActive: json['isActive'] as bool,
      );
}

class CommissionEntry {
  final String id;
  final String customerId;
  final String customerName;
  final String salesInvoiceId;
  final String invoiceNumber;
  final String itemId;
  final String itemName;
  final double amount;
  final CommissionEntryStatus status;
  final double paidAmount;
  final DateTime createdAt;

  CommissionEntry({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.salesInvoiceId,
    required this.invoiceNumber,
    required this.itemId,
    required this.itemName,
    required this.amount,
    required this.status,
    required this.paidAmount,
    required this.createdAt,
  });

  double get pendingAmount => amount - paidAmount;

  factory CommissionEntry.fromJson(Map<String, dynamic> json) => CommissionEntry(
        id: json['id'] as String,
        customerId: json['customerId'] as String,
        customerName: json['customerName'] as String,
        salesInvoiceId: json['salesInvoiceId'] as String,
        invoiceNumber: json['invoiceNumber'] as String,
        itemId: json['itemId'] as String,
        itemName: json['itemName'] as String,
        amount: (json['amount'] as num).toDouble(),
        status: CommissionEntryStatus.values[json['status'] as int],
        paidAmount: (json['paidAmount'] as num).toDouble(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
