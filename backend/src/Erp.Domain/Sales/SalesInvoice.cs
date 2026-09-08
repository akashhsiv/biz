using Erp.Domain.Common;
using Erp.Domain.Customers;
using Erp.Domain.Items;

namespace Erp.Domain.Sales;

public class SalesInvoice : BaseEntity, IShopScoped
{
    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public string InvoiceNumber { get; set; } = default!;
    public string FinancialYear { get; set; } = default!;

    public SalesInvoiceSourceType SourceType { get; set; }
    public Guid SourceId { get; set; }

    public Guid CustomerId { get; set; }
    public Customer Customer { get; set; } = default!;

    /// <summary>The category (Paint, Iron, Plumbing, etc.) this invoice is placed under, chosen at
    /// creation. Every line's Item must belong to this same category — see SalesInvoicesController.Create.</summary>
    public Guid CategoryId { get; set; }
    public ItemCategory Category { get; set; } = default!;

    public SalesInvoiceStatus Status { get; set; } = SalesInvoiceStatus.Active;

    public decimal Subtotal { get; set; }
    public DiscountType? OverallDiscountType { get; set; }
    public decimal OverallDiscountValue { get; set; }
    public decimal OverallDiscountAmount { get; set; }
    public decimal TaxTotal { get; set; }
    public decimal GrandTotal { get; set; }

    public decimal DepositAllocatedTotal { get; set; }

    /// <summary>Optional payment due date, flowing from an optional parameter on quotation/proforma
    /// conversion — null for invoices created before this field existed, and for any invoice created
    /// without one. Used by NotificationCheckWorker's daily sweep (SalesPaymentDue/SalesPaymentOverdue)
    /// and by DocumentPaymentStatusCalculator.</summary>
    public DateTime? DueDate { get; set; }

    /// <summary>Stored, recomputed via DocumentPaymentStatusCalculator whenever DepositAllocatedTotal
    /// changes (creation, deposit allocation/reversal) or the invoice is cancelled — never computed ad hoc.</summary>
    public decimal OutstandingTotal { get; set; }

    /// <summary>Stored, recomputed alongside OutstandingTotal — see DocumentPaymentStatusCalculator.
    /// Unrelated to Status (Active/Cancelled): a Cancelled invoice is forced to Paid/0-outstanding since
    /// nothing is owed on it any more.</summary>
    public DocumentPaymentStatus PaymentStatus { get; set; } = DocumentPaymentStatus.Credit;

    /// <summary>Required when Status is Cancelled (Admin-only, per confirmed business rule).</summary>
    public string? CancellationReason { get; set; }

    /// <summary>Place of supply for GST purposes, set at invoice creation time.</summary>
    public string? PlaceOfSupply { get; set; }

    public ICollection<SalesInvoiceLine> Lines { get; set; } = new List<SalesInvoiceLine>();
}

/// <summary>Snapshot lines at invoice creation time.</summary>
public class SalesInvoiceLine : DocumentLineBase
{
    public Guid SalesInvoiceId { get; set; }
    public SalesInvoice SalesInvoice { get; set; } = default!;
}
