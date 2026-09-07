/// Matches `ShopAdminSummaryDto` from `AdminController.cs` (GET/POST `api/admin/shops`).
class Shop {
  final String id;
  final String name;
  final String gstin;
  final String? address;
  final String? contactNumber;
  final bool isActive;

  Shop({
    required this.id,
    required this.name,
    required this.gstin,
    this.address,
    this.contactNumber,
    required this.isActive,
  });

  factory Shop.fromJson(Map<String, dynamic> json) => Shop(
        id: json['id'] as String,
        name: json['name'] as String,
        gstin: json['gstin'] as String? ?? '',
        address: json['address'] as String?,
        contactNumber: json['contactNumber'] as String?,
        isActive: json['isActive'] as bool,
      );
}

/// Matches `CreateShopAdminResult` from `AdminController.cs` — the plaintext password is only ever
/// visible in this one response, so callers must show it to the user immediately.
class ShopAdminCreationResult {
  final String userId;
  final String username;
  final String fullName;
  final String password;

  ShopAdminCreationResult({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.password,
  });

  factory ShopAdminCreationResult.fromJson(Map<String, dynamic> json) => ShopAdminCreationResult(
        userId: json['userId'] as String,
        username: json['username'] as String,
        fullName: json['fullName'] as String,
        password: json['password'] as String,
      );
}
