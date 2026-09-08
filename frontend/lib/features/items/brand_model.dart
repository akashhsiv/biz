class Brand {
  final String id;
  final String name;
  final String categoryId;
  final bool isActive;

  Brand({required this.id, required this.name, required this.categoryId, required this.isActive});

  factory Brand.fromJson(Map<String, dynamic> json) => Brand(
        id: json['id'] as String,
        name: json['name'] as String,
        categoryId: json['categoryId'] as String,
        isActive: json['isActive'] as bool,
      );
}

/// A Brand this Vendor (Supplier) is linked to supply — the link a Purchase Order line's Item.Brand
/// must belong to when its Supplier is this one.
class VendorBrand {
  final String id;
  final String supplierId;
  final String brandId;
  final String brandName;
  final String categoryId;

  VendorBrand({required this.id, required this.supplierId, required this.brandId, required this.brandName, required this.categoryId});

  factory VendorBrand.fromJson(Map<String, dynamic> json) => VendorBrand(
        id: json['id'] as String,
        supplierId: json['supplierId'] as String,
        brandId: json['brandId'] as String,
        brandName: json['brandName'] as String,
        categoryId: json['categoryId'] as String,
      );
}
