class FinancialTransactionEntry {
  final String id;
  final int transactionType;
  final int direction; // 0 = Credit, 1 = Debit
  final double amount;
  final String? customerId;
  final String? reason;
  final DateTime createdAt;

  FinancialTransactionEntry({
    required this.id,
    required this.transactionType,
    required this.direction,
    required this.amount,
    this.customerId,
    this.reason,
    required this.createdAt,
  });

  factory FinancialTransactionEntry.fromJson(Map<String, dynamic> json) => FinancialTransactionEntry(
        id: json['id'] as String,
        transactionType: json['transactionType'] as int,
        direction: json['direction'] as int,
        amount: (json['amount'] as num).toDouble(),
        customerId: json['customerId'] as String?,
        reason: json['reason'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

const transactionTypeNames = ['Amount In', 'Amount Out', 'Deposit Allocation', 'Deposit Reversal', 'Purchase Payment', 'Refund', 'Adjustment'];
