class ItemCategory {
  final String id;
  final String name;
  final bool isActive;

  ItemCategory({required this.id, required this.name, required this.isActive});

  factory ItemCategory.fromJson(Map<String, dynamic> json) => ItemCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        isActive: json['isActive'] as bool,
      );
}
