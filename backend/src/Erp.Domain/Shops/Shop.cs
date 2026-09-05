using Erp.Domain.Common;
using Erp.Domain.Identity;
using Erp.Domain.System;

namespace Erp.Domain.Shops;

/// <summary>A single branch/location under the Company. This is the unit every transactional entity
/// (Customer, Item, SalesInvoice, ...) is scoped to via IShopScoped.
///
/// Design choice (multi-shop rework, step 1): CompanySettings — the branding/bank/WhatsApp-template/
/// document-terms profile — is kept as its own table rather than folded onto Shop, and simply gains a
/// required ShopId making it a 1:1 child of Shop. That was the lower-disruption option: it leaves
/// CompanySettingsController, its DTOs, and every PDF/WhatsApp template consumer untouched (they still
/// read "the" CompanySettings row; the new per-shop query filter is what makes that resolve to the
/// caller's shop instead of a global singleton). The cost is that Shop's own identity fields below
/// (Name/Gstin/Address/ContactNumber) duplicate a few CompanySettings fields (ShopName/Gstin/Address/
/// ContactNumber) rather than being the single source of truth for them; reconciling that duplication
/// is left to a later step once the shop-switcher UI and reports need it.</summary>
public class Shop : BaseEntity
{
    public Guid CompanyId { get; set; }
    public Company Company { get; set; } = default!;

    public string Name { get; set; } = default!;
    public string Gstin { get; set; } = default!;
    public string? Address { get; set; }
    public string? ContactNumber { get; set; }
    public bool IsActive { get; set; } = true;

    public CompanySettings? Settings { get; set; }
    public ICollection<UserShopRole> UserShopRoles { get; set; } = new List<UserShopRole>();
}
