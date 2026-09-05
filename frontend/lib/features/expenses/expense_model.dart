class Expense {
  final String id;
  final String category;
  final double amount;
  final String reason;
  final String? paymentMethod;
  final DateTime createdAt;

  Expense({
    required this.id,
    required this.category,
    required this.amount,
    required this.reason,
    this.paymentMethod,
    required this.createdAt,
  });

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        category: json['category'] as String,
        amount: (json['amount'] as num).toDouble(),
        reason: json['reason'] as String,
        paymentMethod: json['paymentMethod'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// Common shop expense categories — kept as a preset list so entry stays consistent, with a
/// custom option always available, same pattern as `commonItemUnits` for Items.
const List<String> commonExpenseCategories = ['Rent', 'Electricity', 'Water', 'Salaries', 'Transport', 'Maintenance', 'Miscellaneous'];
