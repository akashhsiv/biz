using Erp.Domain.Common;
using Erp.Domain.Customers;

namespace Erp.Domain.Sales;

public class Quotation : BaseEntity
{
    public string QuotationNumber { get; set; } = default!;
    public string FinancialYear { get; set; } = default!;

    public Guid CustomerId { get; set; }
    public Customer Customer { get; set; } = default!;

    public QuotationStatus Status { get; set; } = QuotationStatus.Draft;

    public decimal Subtotal { get; set; }
    public DiscountType? OverallDiscountType { get; set; }
    public decimal OverallDiscountValue { get; set; }
    public decimal OverallDiscountAmount { get; set; }
    public decimal TaxTotal { get; set; }
    public decimal GrandTotal { get; set; }

    public Guid SalesPersonId { get; set; }

    /// <summary>Optional free-text note specific to this quotation (payment terms, delivery notes,
    /// special instructions) — distinct from CompanySettings.QuotationTermsAndConditions, which is a
    /// shop-wide default printed on every quotation.</summary>
    public string? Notes { get; set; }

    /// <summary>Where the goods/services are actually being supplied to for this specific order —
    /// deliberately independent of the customer's own stored address/GST state (confirmed decision:
    /// an order can ship anywhere, not just "home"). Carries forward unchanged when this quotation
    /// converts to a Proforma or Sales Invoice, since it's the same order.</summary>
    public string? PlaceOfSupply { get; set; }

    public ICollection<QuotationLine> Lines { get; set; } = new List<QuotationLine>();
}

public class QuotationLine : DocumentLineBase
{
    public Guid QuotationId { get; set; }
    public Quotation Quotation { get; set; } = default!;
}
