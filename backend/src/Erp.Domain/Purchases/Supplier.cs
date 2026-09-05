using Erp.Domain.Common;

namespace Erp.Domain.Purchases;

public class Supplier : BaseEntity, IShopScoped
{
    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public string Name { get; set; } = default!;
    public string? GstNumber { get; set; }
    public string? State { get; set; }
    public string? ContactNumber { get; set; }
    public string? Address { get; set; }
    public bool IsActive { get; set; } = true;
}
