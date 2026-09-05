class Deposit {
  final String id;
  final String customerId;
  final double amount;
  final String? paymentMethod;
  final String? notes;
  final DateTime createdAt;

  Deposit({
    required this.id,
    required this.customerId,
    required this.amount,
    this.paymentMethod,
    this.notes,
    required this.createdAt,
  });

  factory Deposit.fromJson(Map<String, dynamic> json) => Deposit(
        id: json['id'] as String,
        customerId: json['customerId'] as String,
        amount: (json['amount'] as num).toDouble(),
        paymentMethod: json['paymentMethod'] as String?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

class DepositSummary {
  final double totalDeposited;
  final double totalAllocated;
  final double available;

  DepositSummary({required this.totalDeposited, required this.totalAllocated, required this.available});

  factory DepositSummary.fromJson(Map<String, dynamic> json) => DepositSummary(
        totalDeposited: (json['totalDeposited'] as num).toDouble(),
        totalAllocated: (json['totalAllocated'] as num).toDouble(),
        available: (json['available'] as num).toDouble(),
      );
}
