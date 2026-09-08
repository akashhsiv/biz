class CompanySettings {
  final String shopName;
  final String gstin;
  final String state;
  final String? address;
  final String? contactNumber;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankIfscCode;
  final String? bankBranch;
  final String? upiId;
  final bool hasLogo;
  final bool hasSignature;
  final bool showLogoOnDocuments;
  final bool showSignatureBlock;
  final String? salesInvoiceTermsAndConditions;
  final String? salesInvoiceFooterNote;
  final String? purchaseOrderTermsAndConditions;
  final String? purchaseOrderFooterNote;
  final String? whatsappSalesInvoiceMessageTemplate;
  final String? whatsappDepositReceiptMessageTemplate;

  CompanySettings({
    required this.shopName,
    required this.gstin,
    required this.state,
    this.address,
    this.contactNumber,
    this.bankName,
    this.bankAccountNumber,
    this.bankIfscCode,
    this.bankBranch,
    this.upiId,
    required this.hasLogo,
    required this.hasSignature,
    required this.showLogoOnDocuments,
    required this.showSignatureBlock,
    this.salesInvoiceTermsAndConditions,
    this.salesInvoiceFooterNote,
    this.purchaseOrderTermsAndConditions,
    this.purchaseOrderFooterNote,
    this.whatsappSalesInvoiceMessageTemplate,
    this.whatsappDepositReceiptMessageTemplate,
  });

  factory CompanySettings.fromJson(Map<String, dynamic> json) => CompanySettings(
        shopName: json['shopName'] as String,
        gstin: json['gstin'] as String,
        state: json['state'] as String,
        address: json['address'] as String?,
        contactNumber: json['contactNumber'] as String?,
        bankName: json['bankName'] as String?,
        bankAccountNumber: json['bankAccountNumber'] as String?,
        bankIfscCode: json['bankIfscCode'] as String?,
        bankBranch: json['bankBranch'] as String?,
        upiId: json['upiId'] as String?,
        hasLogo: json['hasLogo'] as bool,
        hasSignature: json['hasSignature'] as bool,
        showLogoOnDocuments: json['showLogoOnDocuments'] as bool,
        showSignatureBlock: json['showSignatureBlock'] as bool,
        salesInvoiceTermsAndConditions: json['salesInvoiceTermsAndConditions'] as String?,
        salesInvoiceFooterNote: json['salesInvoiceFooterNote'] as String?,
        purchaseOrderTermsAndConditions: json['purchaseOrderTermsAndConditions'] as String?,
        purchaseOrderFooterNote: json['purchaseOrderFooterNote'] as String?,
        whatsappSalesInvoiceMessageTemplate: json['whatsappSalesInvoiceMessageTemplate'] as String?,
        whatsappDepositReceiptMessageTemplate: json['whatsappDepositReceiptMessageTemplate'] as String?,
      );
}
