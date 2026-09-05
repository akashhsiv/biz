namespace Erp.Domain.Items;

public class ItemBatch
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid ItemId { get; set; }
    public Item Item { get; set; } = default!;

    public string BatchNumber { get; set; } = default!;
    public decimal QuantityOnHand { get; set; }
    public DateTime ReceivedDate { get; set; }
    public DateTime? ExpiryDate { get; set; }

    /// <summary>The purchase receipt line that created this batch, if any (opening-stock batches have none).</summary>
    public Guid? PurchaseReceiptLineId { get; set; }
}
