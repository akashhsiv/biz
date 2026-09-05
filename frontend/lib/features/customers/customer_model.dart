enum CustomerType { registered, unregistered }

class Customer {
  final String id;
  final String customerCode;
  final String name;
  final CustomerType customerType;
  final String? gstNumber;
  final String? gstState;
  final String? contactNumber;
  final String? email;
  final bool isActive;

  Customer({
    required this.id,
    required this.customerCode,
    required this.name,
    required this.customerType,
    this.gstNumber,
    this.gstState,
    this.contactNumber,
    this.email,
    required this.isActive,
  });

  factory Customer.fromJson(Map<String, dynamic> json) => Customer(
        id: json['id'] as String,
        customerCode: json['customerCode'] as String,
        name: json['name'] as String,
        customerType: CustomerType.values[json['customerType'] as int],
        gstNumber: json['gstNumber'] as String?,
        gstState: json['gstState'] as String?,
        contactNumber: json['contactNumber'] as String?,
        email: json['email'] as String?,
        isActive: json['isActive'] as bool,
      );
}
