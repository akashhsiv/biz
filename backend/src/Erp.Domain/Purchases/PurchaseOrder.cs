using Erp.Domain.Common;
using Erp.Domain.Items;

namespace Erp.Domain.Purchases;

public class PurchaseOrder : BaseEntity, IShopScoped
{
    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public string PoNumber { get; set; } = default!;
    public string FinancialYear { get; set; } = default!;

    public Guid SupplierId { get; set; }
    public Supplier Supplier { get; set; } = default!;

    public PurchaseOrderStatus Status { get; set; } = PurchaseOrderStatus.Draft;

    /// <summary>Optional payment due date, used by NotificationCheckWorker's daily sweep to raise a
    /// PURCHASE_OVERDUE event once this date has passed and an outstanding balance remains. Did not
    /// exist before the notification engine — null for POs created before this field was added, which
    /// simply never trigger the overdue check.</summary>
    public DateTime? DueDate { get; set; }

    /// <summary>Independent from Status — driven by PurchasePayment completion, not by goods-received completeness.</summary>
    public PurchasePaymentStatus PaymentStatus { get; set; } = PurchasePaymentStatus.Processing;

    /// <summary>Unified Full/Partial/Credit/Overdue balance status — deliberately a DIFFERENT concept
    /// from PaymentStatus above (that tracks the payment-record workflow; this tracks money owed against
    /// DueDate). Stored, recomputed via DocumentPaymentStatusCalculator whenever a PurchasePayment is
    /// recorded/completed or the PO is cancelled.</summary>
    public DocumentPaymentStatus BalancePaymentStatus { get; set; } = DocumentPaymentStatus.Credit;

    /// <summary>Stored, recomputed alongside BalancePaymentStatus = GrandTotal minus completed payments.</summary>
    public decimal OutstandingTotal { get; set; }

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
