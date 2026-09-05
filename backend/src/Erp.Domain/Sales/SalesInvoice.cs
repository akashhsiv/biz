using Erp.Domain.Common;
using Erp.Domain.Customers;

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

    public SalesInvoiceStatus Status { get; set; } = SalesInvoiceStatus.Active;

    public decimal Subtotal { get; set; }
    public DiscountType? OverallDiscountType { get; set; }
    public decimal OverallDiscountValue { get; set; }
    public decimal OverallDiscountAmount { get; set; }
    public decimal TaxTotal { get; set; }
    public decimal GrandTotal { get; set; }

    public decimal DepositAllocatedTotal { get; set; }

    /// <summary>Required when Status is Cancelled (Admin-only, per confirmed business rule).</summary>
    public string? CancellationReason { get; set; }

    /// <summary>Carried over unchanged from the source Quotation/Proforma at conversion time — see
    /// Quotation.PlaceOfSupply.</summary>
    public string? PlaceOfSupply { get; set; }

    public ICollection<SalesInvoiceLine> Lines { get; set; } = new List<SalesInvoiceLine>();
}

/// <summary>Snapshot lines at invoice creation time.</summary>
public class SalesInvoiceLine : DocumentLineBase
{
    public Guid SalesInvoiceId { get; set; }
    public SalesInvoice SalesInvoice { get; set; } = default!;
}
