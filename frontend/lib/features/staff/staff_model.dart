enum StaffEmploymentStatus { active, inactive, terminated }

enum StaffSalaryType { monthly, daily, hourly }

String staffEmploymentStatusLabel(StaffEmploymentStatus s) => switch (s) {
      StaffEmploymentStatus.active => 'Active',
      StaffEmploymentStatus.inactive => 'Inactive',
      StaffEmploymentStatus.terminated => 'Terminated',
    };

String staffSalaryTypeLabel(StaffSalaryType s) => switch (s) {
      StaffSalaryType.monthly => 'Monthly',
      StaffSalaryType.daily => 'Daily',
      StaffSalaryType.hourly => 'Hourly',
    };

class Staff {
  final String id;
  final String name;
  final String employeeCode;
  final String? mobile;
  final String? address;
  final DateTime joiningDate;
  final String? designation;
  final String? categoryId;
  final StaffEmploymentStatus employmentStatus;
  final StaffSalaryType salaryType;
  final double basicSalary;
  final double allowances;
  final double deductions;
  final String? notes;
  final bool isActive;

  Staff({
    required this.id,
    required this.name,
    required this.employeeCode,
    this.mobile,
    this.address,
    required this.joiningDate,
    this.designation,
    this.categoryId,
    required this.employmentStatus,
    required this.salaryType,
    required this.basicSalary,
    required this.allowances,
    required this.deductions,
    this.notes,
    required this.isActive,
  });

  double get netSalary => basicSalary + allowances - deductions;

  factory Staff.fromJson(Map<String, dynamic> json) => Staff(
        id: json['id'] as String,
        name: json['name'] as String,
        employeeCode: json['employeeCode'] as String,
        mobile: json['mobile'] as String?,
        address: json['address'] as String?,
        joiningDate: DateTime.parse(json['joiningDate'] as String),
        designation: json['designation'] as String?,
        categoryId: json['categoryId'] as String?,
        employmentStatus: StaffEmploymentStatus.values[json['employmentStatus'] as int],
        salaryType: StaffSalaryType.values[json['salaryType'] as int],
        basicSalary: (json['basicSalary'] as num).toDouble(),
        allowances: (json['allowances'] as num).toDouble(),
        deductions: (json['deductions'] as num).toDouble(),
        notes: json['notes'] as String?,
        isActive: json['isActive'] as bool,
      );
}
