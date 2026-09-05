/// Mirrors backend ShopSummaryDto(Guid Id, string Name, string Gstin, bool IsActive).
class Shop {
  final String id;
  final String name;
  final String gstin;
  final bool isActive;

  Shop({
    required this.id,
    required this.name,
    required this.gstin,
    required this.isActive,
  });

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
        id: json['id'] as String,
        name: json['name'] as String,
        gstin: json['gstin'] as String,
        isActive: json['isActive'] as bool,
      );
}
