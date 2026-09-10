class TaxGroup {
  final String id;
  final String name;
  final double ratePercent;
  final bool isActive;

  TaxGroup({required this.id, required this.name, required this.ratePercent, required this.isActive});

  factory TaxGroup.fromJson(Map<String, dynamic> json) => TaxGroup(
        id: json['id'] as String,
        name: json['name'] as String,
        ratePercent: (json['ratePercent'] as num).toDouble(),
        isActive: json['isActive'] as bool,
      );
}
