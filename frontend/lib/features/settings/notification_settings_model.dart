class NotificationSettings {
  final bool lowStockWhatsapp;
  final bool lowStockMobile;
  final bool purchaseDueWhatsapp;
  final bool purchaseDueMobile;
  final bool purchaseOverdueWhatsapp;
  final bool purchaseOverdueMobile;
  final bool customerOutstandingWhatsapp;
  final bool customerOutstandingMobile;
  final int dueSoonDays;

  NotificationSettings({
    required this.lowStockWhatsapp,
    required this.lowStockMobile,
    required this.purchaseDueWhatsapp,
    required this.purchaseDueMobile,
    required this.purchaseOverdueWhatsapp,
    required this.purchaseOverdueMobile,
    required this.customerOutstandingWhatsapp,
    required this.customerOutstandingMobile,
    required this.dueSoonDays,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) => NotificationSettings(
        lowStockWhatsapp: json['lowStockWhatsapp'] as bool,
        lowStockMobile: json['lowStockMobile'] as bool,
        purchaseDueWhatsapp: json['purchaseDueWhatsapp'] as bool,
        purchaseDueMobile: json['purchaseDueMobile'] as bool,
        purchaseOverdueWhatsapp: json['purchaseOverdueWhatsapp'] as bool,
        purchaseOverdueMobile: json['purchaseOverdueMobile'] as bool,
        customerOutstandingWhatsapp: json['customerOutstandingWhatsapp'] as bool,
        customerOutstandingMobile: json['customerOutstandingMobile'] as bool,
        dueSoonDays: json['dueSoonDays'] as int,
      );

  Map<String, dynamic> toJson() => {
        'lowStockWhatsapp': lowStockWhatsapp,
        'lowStockMobile': lowStockMobile,
        'purchaseDueWhatsapp': purchaseDueWhatsapp,
        'purchaseDueMobile': purchaseDueMobile,
        'purchaseOverdueWhatsapp': purchaseOverdueWhatsapp,
        'purchaseOverdueMobile': purchaseOverdueMobile,
        'customerOutstandingWhatsapp': customerOutstandingWhatsapp,
        'customerOutstandingMobile': customerOutstandingMobile,
        'dueSoonDays': dueSoonDays,
      };

  NotificationSettings copyWith({
    bool? lowStockWhatsapp,
    bool? lowStockMobile,
    bool? purchaseDueWhatsapp,
    bool? purchaseDueMobile,
    bool? purchaseOverdueWhatsapp,
    bool? purchaseOverdueMobile,
    bool? customerOutstandingWhatsapp,
    bool? customerOutstandingMobile,
    int? dueSoonDays,
  }) =>
      NotificationSettings(
        lowStockWhatsapp: lowStockWhatsapp ?? this.lowStockWhatsapp,
        lowStockMobile: lowStockMobile ?? this.lowStockMobile,
        purchaseDueWhatsapp: purchaseDueWhatsapp ?? this.purchaseDueWhatsapp,
        purchaseDueMobile: purchaseDueMobile ?? this.purchaseDueMobile,
        purchaseOverdueWhatsapp: purchaseOverdueWhatsapp ?? this.purchaseOverdueWhatsapp,
        purchaseOverdueMobile: purchaseOverdueMobile ?? this.purchaseOverdueMobile,
        customerOutstandingWhatsapp: customerOutstandingWhatsapp ?? this.customerOutstandingWhatsapp,
        customerOutstandingMobile: customerOutstandingMobile ?? this.customerOutstandingMobile,
        dueSoonDays: dueSoonDays ?? this.dueSoonDays,
      );
}
