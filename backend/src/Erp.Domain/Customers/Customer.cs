using Erp.Domain.Common;

namespace Erp.Domain.Customers;

public class Customer : BaseEntity, IShopScoped
{
    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public string CustomerCode { get; set; } = default!;
    public string Name { get; set; } = default!;
    public CustomerType CustomerType { get; set; }
    public string? GstNumber { get; set; }
    public string? GstState { get; set; }
    public string? ContactNumber { get; set; }
    public string? Email { get; set; }
    public string? BillingAddress { get; set; }
    public string? ShippingAddress { get; set; }
    public bool IsActive { get; set; } = true;

    /// <summary>Out of scope for v1 business rules; column reserved to avoid a future migration.</summary>
    public decimal? CreditLimit { get; set; }
}
