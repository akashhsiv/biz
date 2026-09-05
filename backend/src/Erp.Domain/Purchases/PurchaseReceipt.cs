using Erp.Domain.Common;

namespace Erp.Domain.Purchases;

public class PurchaseReceipt : IShopScoped
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public string ReceiptNumber { get; set; } = default!;
    public string FinancialYear { get; set; } = default!;

    public Guid PurchaseOrderId { get; set; }
    public PurchaseOrder PurchaseOrder { get; set; } = default!;

    public Guid ReceivedBy { get; set; }
    public DateTime ReceivedAt { get; set; }

    public ICollection<PurchaseReceiptLine> Lines { get; set; } = new List<PurchaseReceiptLine>();
}

public class PurchaseReceiptLine
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid PurchaseReceiptId { get; set; }
    public PurchaseReceipt PurchaseReceipt { get; set; } = default!;

    public Guid PoLineId { get; set; }
    public PurchaseOrderLine PoLine { get; set; } = default!;

    public decimal QuantityReceived { get; set; }

    /// <summary>Batch this receipt line created, when the item is batch-tracked.</summary>
    public Guid? ItemBatchId { get; set; }
}
