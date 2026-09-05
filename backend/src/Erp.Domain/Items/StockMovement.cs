using Erp.Domain.Common;

namespace Erp.Domain.Items;

/// <summary>Append-only ledger of every stock change. Never updated or deleted after insert; corrections are new rows of type Reversal.</summary>
public class StockMovement : IShopScoped
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public Guid ItemId { get; set; }
    public Item Item { get; set; } = default!;

    /// <summary>Populated only for batch-tracked items; null for non-batch items.</summary>
    public Guid? BatchId { get; set; }
    public ItemBatch? Batch { get; set; }

    /// <summary>Populated only for serial-tracked items; null otherwise.</summary>
    public Guid? SerialId { get; set; }
    public ItemSerial? Serial { get; set; }

    public StockMovementType MovementType { get; set; }
    public decimal QuantityDelta { get; set; }
    public decimal QuantityBefore { get; set; }
    public decimal QuantityAfter { get; set; }

    public DocumentReferenceType ReferenceType { get; set; }
    public Guid ReferenceId { get; set; }

    /// <summary>Required for Adjustment and Reversal movement types.</summary>
    public string? Reason { get; set; }

    public Guid CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
}
