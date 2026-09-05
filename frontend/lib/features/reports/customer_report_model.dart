class CustomerReportProductRow {
  final String itemId;
  final String itemName;
  final double quantity;
  final double amount;

  CustomerReportProductRow({required this.itemId, required this.itemName, required this.quantity, required this.amount});

  factory CustomerReportProductRow.fromJson(Map<String, dynamic> json) => CustomerReportProductRow(
        itemId: json['itemId'] as String,
        itemName: json['itemName'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        amount: (json['amount'] as num).toDouble(),
      );
}

class CustomerReportActivityRow {
  final DateTime date;
  final double amount;
  final int invoiceCount;

  CustomerReportActivityRow({required this.date, required this.amount, required this.invoiceCount});

  factory CustomerReportActivityRow.fromJson(Map<String, dynamic> json) => CustomerReportActivityRow(
        date: DateTime.parse(json['date'] as String),
        amount: (json['amount'] as num).toDouble(),
        invoiceCount: json['invoiceCount'] as int,
      );
}

class CustomerReportRow {
  final String customerId;
  final String customerName;
  final double totalSales;
  final double totalOutstanding;
  final double totalPayments;
  final int invoiceCount;
  final List<CustomerReportProductRow> products;
  final List<CustomerReportActivityRow> dateWiseActivity;

  CustomerReportRow({
    required this.customerId,
    required this.customerName,
    required this.totalSales,
    required this.totalOutstanding,
    required this.totalPayments,
    required this.invoiceCount,
    required this.products,
    required this.dateWiseActivity,
  });

  factory CustomerReportRow.fromJson(Map<String, dynamic> json) => CustomerReportRow(
        customerId: json['customerId'] as String,
        customerName: json['customerName'] as String,
        totalSales: (json['totalSales'] as num).toDouble(),
        totalOutstanding: (json['totalOutstanding'] as num).toDouble(),
        totalPayments: (json['totalPayments'] as num).toDouble(),
        invoiceCount: json['invoiceCount'] as int,
        products: (json['products'] as List).map((p) => CustomerReportProductRow.fromJson(p as Map<String, dynamic>)).toList(),
        dateWiseActivity: (json['dateWiseActivity'] as List).map((a) => CustomerReportActivityRow.fromJson(a as Map<String, dynamic>)).toList(),
      );
}

/// Filter params for [customerReportProvider] - kept as a value type with proper ==/hashCode so the
/// autoDispose.family provider caches correctly per distinct filter combination.
class CustomerReportFilter {
  final DateTime? from;
  final DateTime? to;
  final String? customerId;

  const CustomerReportFilter({this.from, this.to, this.customerId});

  @override
  bool operator ==(Object other) =>
      other is CustomerReportFilter && other.from == from && other.to == to && other.customerId == customerId;

  @override
  int get hashCode => Object.hash(from, to, customerId);
}
