enum SalesInvoiceStatus { active, cancelled }

class SalesInvoiceLine {
  final String id;
  final String? itemId;
  final String description;
  final double quantity;
  final double rate;
  final double discount;
  final double taxRatePercent;
  final double cgst;
  final double sgst;
  final double igst;
  final double lineTotal;
  final List<String>? serialNumbers;

  SalesInvoiceLine({
    required this.id,
    this.itemId,
    required this.description,
    required this.quantity,
    required this.rate,
    required this.discount,
    required this.taxRatePercent,
    this.cgst = 0,
    this.sgst = 0,
    this.igst = 0,
    required this.lineTotal,
    this.serialNumbers,
  });

  factory SalesInvoiceLine.fromJson(Map<String, dynamic> json) => SalesInvoiceLine(
        id: json['id'] as String,
        itemId: json['itemId'] as String?,
        description: json['description'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        rate: (json['rate'] as num).toDouble(),
        discount: (json['discount'] as num).toDouble(),
        taxRatePercent: (json['taxRatePercent'] as num).toDouble(),
        cgst: (json['cgst'] as num?)?.toDouble() ?? 0,
        sgst: (json['sgst'] as num?)?.toDouble() ?? 0,
        igst: (json['igst'] as num?)?.toDouble() ?? 0,
        lineTotal: (json['lineTotal'] as num).toDouble(),
        serialNumbers: (json['serialNumbers'] as List?)?.cast<String>(),
      );
}

class SalesInvoice {
  final String id;
  final String invoiceNumber;
  final String customerId;
  final SalesInvoiceStatus status;
  final double subtotal;
  final double overallDiscountAmount;
  final double taxTotal;
  final double grandTotal;
  final double depositAllocatedTotal;
  final List<SalesInvoiceLine> lines;
  final String? cancellationReason;
  final String? placeOfSupply;
  final DateTime createdAt;
  final String createdBy;

  SalesInvoice({
    required this.id,
    required this.invoiceNumber,
    required this.customerId,
    required this.status,
    this.subtotal = 0,
    this.overallDiscountAmount = 0,
    this.taxTotal = 0,
    required this.grandTotal,
    required this.depositAllocatedTotal,
    this.lines = const [],
    this.cancellationReason,
    this.placeOfSupply,
    required this.createdAt,
    required this.createdBy,
  });

  factory SalesInvoice.fromJson(Map<String, dynamic> json) => SalesInvoice(
        id: json['id'] as String,
        invoiceNumber: json['invoiceNumber'] as String,
        customerId: json['customerId'] as String,
        status: SalesInvoiceStatus.values[json['status'] as int],
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
        overallDiscountAmount: (json['overallDiscountAmount'] as num?)?.toDouble() ?? 0,
        taxTotal: (json['taxTotal'] as num?)?.toDouble() ?? 0,
        grandTotal: (json['grandTotal'] as num).toDouble(),
        depositAllocatedTotal: (json['depositAllocatedTotal'] as num).toDouble(),
        lines: (json['lines'] as List? ?? []).map((e) => SalesInvoiceLine.fromJson(e as Map<String, dynamic>)).toList(),
        cancellationReason: json['cancellationReason'] as String?,
        placeOfSupply: json['placeOfSupply'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        createdBy: json['createdBy'] as String? ?? '',
      );
}
