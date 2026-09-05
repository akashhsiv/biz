using Erp.Domain.Common;
using Erp.Domain.Customers;

namespace Erp.Domain.Sales;

public class SalesReturn : BaseEntity, IShopScoped
{
    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public string ReturnNumber { get; set; } = default!;
    public string FinancialYear { get; set; } = default!;

    public Guid SalesInvoiceId { get; set; }
    public SalesInvoice SalesInvoice { get; set; } = default!;

    public Guid CustomerId { get; set; }
    public Customer Customer { get; set; } = default!;

    public SalesReturnStatus Status { get; set; } = SalesReturnStatus.Requested;
    public string? Reason { get; set; }
    public Guid? ApprovedBy { get; set; }
    public DateTime? ApprovedAt { get; set; }

    /// <summary>Chosen by the approver when completing the return; drives which kind of FinancialTransaction gets written.</summary>
    public RefundMethod? RefundMethod { get; set; }
    public decimal TotalRefundAmount { get; set; }

    public ICollection<SalesReturnLine> Lines { get; set; } = new List<SalesReturnLine>();
}

public class SalesReturnLine
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid SalesReturnId { get; set; }
    public SalesReturn SalesReturn { get; set; } = default!;

    public Guid SalesInvoiceLineId { get; set; }
    public SalesInvoiceLine SalesInvoiceLine { get; set; } = default!;

    public decimal QuantityReturned { get; set; }
    public decimal RefundAmount { get; set; }
    public bool Restock { get; set; }
}
