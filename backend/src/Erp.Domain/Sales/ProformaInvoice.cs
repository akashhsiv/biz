using Erp.Domain.Common;
using Erp.Domain.Customers;

namespace Erp.Domain.Sales;

public class ProformaInvoice : BaseEntity
{
    public string ProformaNumber { get; set; } = default!;
    public string FinancialYear { get; set; } = default!;

    public Guid QuotationId { get; set; }
    public Quotation Quotation { get; set; } = default!;

    public Guid CustomerId { get; set; }
    public Customer Customer { get; set; } = default!;

    public ProformaStatus Status { get; set; } = ProformaStatus.Open;

    public decimal Subtotal { get; set; }
    public DiscountType? OverallDiscountType { get; set; }
    public decimal OverallDiscountValue { get; set; }
    public decimal OverallDiscountAmount { get; set; }
    public decimal TaxTotal { get; set; }
    public decimal GrandTotal { get; set; }

    public decimal AllocatedTotal { get; set; }
    public decimal OutstandingTotal { get; set; }

    /// <summary>Carried over unchanged from the source Quotation at conversion time — see
    /// Quotation.PlaceOfSupply.</summary>
    public string? PlaceOfSupply { get; set; }

    public ICollection<ProformaLine> Lines { get; set; } = new List<ProformaLine>();
}

/// <summary>Snapshot copy of the quotation's lines at conversion time, so later edits to the quotation never alter an issued proforma.</summary>
public class ProformaLine : DocumentLineBase
{
    public Guid ProformaId { get; set; }
    public ProformaInvoice Proforma { get; set; } = default!;
}
