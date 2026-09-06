using Erp.Domain.Common;

namespace Erp.Domain.Items;

public class Item : BaseEntity, IShopScoped
{
    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public string Sku { get; set; } = default!;
    public string Name { get; set; } = default!;
    public Guid? CategoryId { get; set; }
    public ItemCategory? Category { get; set; }
    public string Unit { get; set; } = default!;
    public ItemKind ItemKind { get; set; }
    public decimal PurchasePrice { get; set; }
    public decimal SellingPrice { get; set; }
    public decimal TaxRatePercent { get; set; }
    public string? HsnCode { get; set; }
    public bool IsActive { get; set; } = true;

    public byte[]? Image { get; set; }

    /// <summary>Threshold for the LOW_STOCK notification event (Biz_Product_Requirements.md §16) — the
    /// stock adjustment handler raises the event when QuantityOnHand drops to/under this value. Null
    /// means the item has no configured threshold, so low-stock checking is skipped for it.</summary>
    public decimal? MinimumStock { get; set; }

    /// <summary>When true, stock is tracked per-batch (ItemBatch) and negative-stock validation happens at the batch level.</summary>
    public bool IsBatchTracked { get; set; }

    /// <summary>When true, stock is tracked per-unit (ItemSerial) — one serial number per physical unit, quantity always 1 each. Mutually exclusive with IsBatchTracked.</summary>
    public bool IsSerialTracked { get; set; }

    public StockBalance? StockBalance { get; set; }
    public ICollection<ItemBatch> Batches { get; set; } = new List<ItemBatch>();
    public ICollection<ItemSerial> Serials { get; set; } = new List<ItemSerial>();
}
