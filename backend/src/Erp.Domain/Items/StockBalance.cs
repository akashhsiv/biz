namespace Erp.Domain.Items;

/// <summary>Cached current on-hand quantity per stock item. Derived from StockMovement; must always be reconcilable by re-summing movements.</summary>
public class StockBalance
{
    public Guid ItemId { get; set; }
    public Item Item { get; set; } = default!;

    public decimal QuantityOnHand { get; set; }
    public Guid? LastMovementId { get; set; }
    public DateTime UpdatedAt { get; set; }

    /// <summary>EF Core concurrency token to guard against lost updates under concurrent Slave writes.</summary>
    public uint Version { get; set; }
}
