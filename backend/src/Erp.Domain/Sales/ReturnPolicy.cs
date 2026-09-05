using Erp.Domain.Common;
using Erp.Domain.Items;

namespace Erp.Domain.Sales;

public class ReturnPolicy : BaseEntity, IShopScoped
{
    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public string Name { get; set; } = default!;

    /// <summary>Null means the policy applies to all categories.</summary>
    public Guid? CategoryId { get; set; }
    public ItemCategory? Category { get; set; }

    public int ReturnWindowDays { get; set; }
    public decimal RestockingFeePercent { get; set; }
    public bool IsActive { get; set; } = true;
}
