namespace Erp.Domain.System;

/// <summary>Single-row table: the shop's own GST/company identity used on every document. No multi-entity support in v1 (confirmed).</summary>
public class CompanySettings
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public string ShopName { get; set; } = default!;
    public string Gstin { get; set; } = default!;
    public string State { get; set; } = default!;
    public string? Address { get; set; }
    public string? ContactNumber { get; set; }
    public byte[]? Logo { get; set; }

    // Shown on generated PDFs (invoices, quotations, etc.) so customers know where to pay.
    public string? BankName { get; set; }
    public string? BankAccountNumber { get; set; }
    public string? BankIfscCode { get; set; }
    public string? BankBranch { get; set; }
    public string? UpiId { get; set; }
    public byte[]? Signature { get; set; }

    // Admin-editable per-message-type text (confirmed decision 2026-08-28): null/blank keeps the
    // hardcoded default wording in WhatsappController.BuildMessageAsync - these only override it.
    // Supports {variable} placeholders (customerName, quotationNumber, grandTotal, etc.).
    public string? WhatsappQuotationMessageTemplate { get; set; }
    public string? WhatsappProformaMessageTemplate { get; set; }
    public string? WhatsappSalesInvoiceMessageTemplate { get; set; }
    public string? WhatsappDepositReceiptMessageTemplate { get; set; }

    // Admin-editable document template settings (confirmed decision 2026-08-20): Terms &
    // Conditions and the footer note are per document type since a Sales Invoice and a Purchase
    // Order sent to a supplier can reasonably need different wording; the logo/signature toggles
    // are shop-wide, not per document type, since the shop's own branding doesn't vary by document.
    public bool ShowLogoOnDocuments { get; set; } = true;
    public bool ShowSignatureBlock { get; set; }

    public string? QuotationTermsAndConditions { get; set; }
    public string? QuotationFooterNote { get; set; }
    public string? ProformaTermsAndConditions { get; set; }
    public string? ProformaFooterNote { get; set; }
    public string? SalesInvoiceTermsAndConditions { get; set; }
    public string? SalesInvoiceFooterNote { get; set; }
    public string? PurchaseOrderTermsAndConditions { get; set; }
    public string? PurchaseOrderFooterNote { get; set; }
}
