using Erp.Domain.Common;
using Erp.Domain.Items;

namespace Erp.Domain.Purchases;

/// <summary>Join entity: a Supplier (Vendor) supplies zero or more Brands, many-to-many. A Purchase
/// Order line's Item must have a Brand that is linked to the PO's chosen Supplier via this table —
/// see PurchaseOrdersController.Create validation.</summary>
public class VendorBrand : BaseEntity, IShopScoped
{
    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public Guid SupplierId { get; set; }
    public Supplier Supplier { get; set; } = default!;

    public Guid BrandId { get; set; }
    public Brand Brand { get; set; } = default!;
}
