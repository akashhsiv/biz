using Erp.Domain.Common;

namespace Erp.Domain.Items;

/// <summary>A Brand belongs to exactly one Category (ItemCategory) and is supplied by zero or more
/// Vendors (Supplier) via VendorBrand. An Item optionally belongs to one Brand (Item.BrandId).</summary>
public class Brand : BaseEntity, IShopScoped
{
    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public string Name { get; set; } = default!;
    public Guid CategoryId { get; set; }
    public ItemCategory Category { get; set; } = default!;
    public bool IsActive { get; set; } = true;
}
