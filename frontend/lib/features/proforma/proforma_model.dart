enum ProformaStatus { open, fullyFunded, converted, cancelled }

class ProformaLine {
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

  ProformaLine({
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

  factory ProformaLine.fromJson(Map<String, dynamic> json) => ProformaLine(
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

class Proforma {
  final String id;
  final String proformaNumber;
  final String customerId;
  final ProformaStatus status;
  final double subtotal;
  final double overallDiscountAmount;
  final double taxTotal;
  final double grandTotal;
  final double allocatedTotal;
  final double outstandingTotal;
  final List<ProformaLine> lines;
  final String? placeOfSupply;
  final DateTime createdAt;

  Proforma({
    required this.id,
    required this.proformaNumber,
    required this.customerId,
    required this.status,
    this.subtotal = 0,
    this.overallDiscountAmount = 0,
    this.taxTotal = 0,
    required this.grandTotal,
    required this.allocatedTotal,
    required this.outstandingTotal,
    this.lines = const [],
    this.placeOfSupply,
    required this.createdAt,
  });

  factory Proforma.fromJson(Map<String, dynamic> json) => Proforma(
        id: json['id'] as String,
        proformaNumber: json['proformaNumber'] as String,
        customerId: json['customerId'] as String,
        status: ProformaStatus.values[json['status'] as int],
        subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
        overallDiscountAmount: (json['overallDiscountAmount'] as num?)?.toDouble() ?? 0,
        taxTotal: (json['taxTotal'] as num?)?.toDouble() ?? 0,
        grandTotal: (json['grandTotal'] as num).toDouble(),
        allocatedTotal: (json['allocatedTotal'] as num).toDouble(),
        outstandingTotal: (json['outstandingTotal'] as num).toDouble(),
        lines: (json['lines'] as List? ?? []).map((e) => ProformaLine.fromJson(e as Map<String, dynamic>)).toList(),
        placeOfSupply: json['placeOfSupply'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
