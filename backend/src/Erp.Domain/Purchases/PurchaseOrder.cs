using Erp.Domain.Common;
using Erp.Domain.Items;

namespace Erp.Domain.Purchases;

public class PurchaseOrder : BaseEntity
{
    public string PoNumber { get; set; } = default!;
    public string FinancialYear { get; set; } = default!;

    public Guid SupplierId { get; set; }
    public Supplier Supplier { get; set; } = default!;

    public PurchaseOrderStatus Status { get; set; } = PurchaseOrderStatus.Draft;

    /// <summary>Independent from Status — driven by PurchasePayment completion, not by goods-received completeness.</summary>
    public PurchasePaymentStatus PaymentStatus { get; set; } = PurchasePaymentStatus.Processing;

    public decimal Subtotal { get; set; }
    public decimal TaxTotal { get; set; }
    public decimal GrandTotal { get; set; }

    public ICollection<PurchaseOrderLine> Lines { get; set; } = new List<PurchaseOrderLine>();
    public ICollection<PurchaseReceipt> Receipts { get; set; } = new List<PurchaseReceipt>();
    public ICollection<PurchasePayment> Payments { get; set; } = new List<PurchasePayment>();
}

public class PurchaseOrderLine
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid PurchaseOrderId { get; set; }
    public PurchaseOrder PurchaseOrder { get; set; } = default!;

    public Guid ItemId { get; set; }
    public Item Item { get; set; } = default!;

    public decimal QuantityOrdered { get; set; }
    public decimal QuantityReceived { get; set; }
    public decimal Rate { get; set; }
    public decimal TaxRatePercent { get; set; }
    public decimal CgstAmount { get; set; }
    public decimal SgstAmount { get; set; }
    public decimal IgstAmount { get; set; }
    public decimal LineTotal { get; set; }
}
