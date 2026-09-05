using Erp.Domain.Common;
using Erp.Domain.Customers;
using Erp.Domain.Items;

namespace Erp.Domain.Commission;

/// <summary>
/// A customer+item specific pricing/commission override. The exact business meaning of "commission"
/// is an UNRESOLVED DECISION as of 2026-09 (could be commission paid TO the customer, commission
/// earned THROUGH the customer, a customer-specific discount/rate, or something else — see product
/// requirements). This entity therefore only stores the raw configurable inputs; it does not encode
/// any particular business interpretation. See CommissionCalculationService for the (deliberately
/// simple, provisional) calculation that consumes CommissionRate.
/// </summary>
public class CustomerProductRate : BaseEntity, IShopScoped
{
    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public Guid CustomerId { get; set; }
    public Customer Customer { get; set; } = default!;

    public Guid ItemId { get; set; }
    public Item Item { get; set; } = default!;

    /// <summary>Customer's special selling price for this item, if any. Purely informational at
    /// this stage — nothing currently reads this to override SalesInvoiceLine.Rate; wiring it into
    /// invoice pricing is a separate decision pending business sign-off.</summary>
    public decimal? SpecialRate { get; set; }

    /// <summary>
    /// PROVISIONAL — pending business sign-off. Interpreted, for now, as "percentage of the invoice
    /// line total" (the simplest possible default), e.g. CommissionRate = 5 means 5% of LineTotal.
    /// See CommissionCalculationService.CalculateAmount for the exact formula. Null means no
    /// commission applies for this customer+item pair.
    /// </summary>
    public decimal? CommissionRate { get; set; }

    public DateTime EffectiveFrom { get; set; }

    public bool IsActive { get; set; } = true;
}
