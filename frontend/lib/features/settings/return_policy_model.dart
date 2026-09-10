class ReturnPolicy {
  final String id;
  final String name;
  final String? categoryId;
  final int returnWindowDays;
  final double restockingFeePercent;
  final bool isActive;

  ReturnPolicy({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.returnWindowDays,
    required this.restockingFeePercent,
    required this.isActive,
  });

  factory ReturnPolicy.fromJson(Map<String, dynamic> json) => ReturnPolicy(
        id: json['id'] as String,
        name: json['name'] as String,
        categoryId: json['categoryId'] as String?,
        returnWindowDays: json['returnWindowDays'] as int,
        restockingFeePercent: (json['restockingFeePercent'] as num).toDouble(),
        isActive: json['isActive'] as bool,
      );
}
