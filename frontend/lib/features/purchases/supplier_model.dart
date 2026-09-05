class Supplier {
  final String id;
  final String name;
  final String? gstNumber;
  final String? state;
  final String? contactNumber;
  final bool isActive;

  Supplier({required this.id, required this.name, this.gstNumber, this.state, this.contactNumber, required this.isActive});

  factory Supplier.fromJson(Map<String, dynamic> json) => Supplier(
        id: json['id'] as String,
        name: json['name'] as String,
        gstNumber: json['gstNumber'] as String?,
        state: json['state'] as String?,
        contactNumber: json['contactNumber'] as String?,
        isActive: json['isActive'] as bool,
      );
}
