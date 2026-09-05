using Erp.Domain.Common;

namespace Erp.Domain.Items;

public class ItemCategory : BaseEntity, IShopScoped
{
    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public string Name { get; set; } = default!;
    public bool IsActive { get; set; } = true;
}
