enum SalaryPaymentStatus { pending, partiallyPaid, paid }

String salaryPaymentStatusLabel(SalaryPaymentStatus s) => switch (s) {
      SalaryPaymentStatus.pending => 'Pending',
      SalaryPaymentStatus.partiallyPaid => 'Partially Paid',
      SalaryPaymentStatus.paid => 'Paid',
    };

class SalaryPaymentEntry {
  final String id;
  final double amount;
  final String? paymentMethod;
  final String paidBy;
  final DateTime paidAt;
  final String? notes;

  SalaryPaymentEntry({
    required this.id,
    required this.amount,
    this.paymentMethod,
    required this.paidBy,
    required this.paidAt,
    this.notes,
  });

  factory SalaryPaymentEntry.fromJson(Map<String, dynamic> json) => SalaryPaymentEntry(
        id: json['id'] as String,
        amount: (json['amount'] as num).toDouble(),
        paymentMethod: json['paymentMethod'] as String?,
        paidBy: json['paidBy'] as String,
        paidAt: DateTime.parse(json['paidAt'] as String),
        notes: json['notes'] as String?,
      );
}

class SalaryPayment {
  final String id;
  final String staffId;
  final String staffName;
  final int periodMonth;
  final int periodYear;
  final double basicSalary;
  final double allowance;
  final double deduction;
  final double netSalary;
  final double paidAmount;
  final double pendingAmount;
  final SalaryPaymentStatus status;
  final List<SalaryPaymentEntry> entries;

  SalaryPayment({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.periodMonth,
    required this.periodYear,
    required this.basicSalary,
    required this.allowance,
    required this.deduction,
    required this.netSalary,
    required this.paidAmount,
    required this.pendingAmount,
    required this.status,
    required this.entries,
  });

  factory SalaryPayment.fromJson(Map<String, dynamic> json) => SalaryPayment(
        id: json['id'] as String,
        staffId: json['staffId'] as String,
        staffName: json['staffName'] as String,
        periodMonth: json['periodMonth'] as int,
        periodYear: json['periodYear'] as int,
        basicSalary: (json['basicSalary'] as num).toDouble(),
        allowance: (json['allowance'] as num).toDouble(),
        deduction: (json['deduction'] as num).toDouble(),
        netSalary: (json['netSalary'] as num).toDouble(),
        paidAmount: (json['paidAmount'] as num).toDouble(),
        pendingAmount: (json['pendingAmount'] as num).toDouble(),
        status: SalaryPaymentStatus.values[json['status'] as int],
        entries: (json['entries'] as List? ?? [])
            .map((e) => SalaryPaymentEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

const List<String> monthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
