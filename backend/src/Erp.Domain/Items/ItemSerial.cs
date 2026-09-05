namespace Erp.Domain.Items;

/// <summary>One physical unit of a serial-tracked item — the serial-tracked equivalent of an
/// [ItemBatch], but always quantity 1. Consumed oldest-received-first on a sale, same FIFO rule
/// used for batches, since neither flow lets the user hand-pick which unit/batch to sell.</summary>
public class ItemSerial
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid ItemId { get; set; }
    public Item Item { get; set; } = default!;

    public string SerialNumber { get; set; } = default!;
    public bool IsSold { get; set; }
    public DateTime ReceivedDate { get; set; }

    /// <summary>The purchase receipt line that created this serial, if any (opening-stock serials have none).</summary>
    public Guid? PurchaseReceiptLineId { get; set; }
}
