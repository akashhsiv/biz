enum QuotationStatus { draft, issued, converted, cancelled, expired }

class QuotationLine {
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
  final String? hsnCode;

  QuotationLine({
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
    this.hsnCode,
  });

  factory QuotationLine.fromJson(Map<String, dynamic> json) => QuotationLine(
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
        hsnCode: json['hsnCode'] as String?,
      );
}

class Quotation {
  final String id;
  final String quotationNumber;
  final String customerId;
  final QuotationStatus status;
  final double subtotal;
  final double overallDiscountAmount;
  final double taxTotal;
  final double grandTotal;
  final List<QuotationLine> lines;
  final String? notes;
  final String? placeOfSupply;
  final DateTime createdAt;
  final String createdBy;

  Quotation({
    required this.id,
    required this.quotationNumber,
    required this.customerId,
    required this.status,
    this.subtotal = 0,
    this.overallDiscountAmount = 0,
    this.taxTotal = 0,
    required this.grandTotal,
    required this.lines,
    this.notes,
    this.placeOfSupply,
    required this.createdAt,
    required this.createdBy,
  });

  factory Quotation.fromJson(Map<String, dynamic> json) => Quotation(
        id: json['id'] as String,
        quotationNumber: json['quotationNumber'] as String,
        customerId: json['customerId'] as String,
        status: QuotationStatus.values[json['status'] as int],
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
        overallDiscountAmount: (json['overallDiscountAmount'] as num?)?.toDouble() ?? 0,
        taxTotal: (json['taxTotal'] as num?)?.toDouble() ?? 0,
        grandTotal: (json['grandTotal'] as num).toDouble(),
        lines: (json['lines'] as List).map((e) => QuotationLine.fromJson(e as Map<String, dynamic>)).toList(),
        notes: json['notes'] as String?,
        placeOfSupply: json['placeOfSupply'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
        createdBy: json['createdBy'] as String? ?? '',
      );
}

class ConvertResult {
  final String resultType; // "SalesInvoice" or "ProformaInvoice"
  final String documentNumber;
  final double grandTotal;
  final double depositApplied;
  final double outstanding;

  ConvertResult({
    required this.resultType,
    required this.documentNumber,
    required this.grandTotal,
    required this.depositApplied,
    required this.outstanding,
  });

  factory ConvertResult.fromJson(Map<String, dynamic> json) => ConvertResult(
        resultType: json['resultType'] as String,
        documentNumber: json['documentNumber'] as String,
        grandTotal: (json['grandTotal'] as num).toDouble(),
        depositApplied: (json['depositApplied'] as num).toDouble(),
        outstanding: (json['outstanding'] as num).toDouble(),
      );
}
