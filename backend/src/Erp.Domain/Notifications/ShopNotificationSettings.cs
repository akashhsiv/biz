using Erp.Domain.Common;

namespace Erp.Domain.Notifications;

/// <summary>One row per shop (get-or-create-on-first-access, same pattern as CompanySettings) holding
/// which channels are enabled per event type — see Biz_Product_Requirements.md §23 "Notification
/// Settings" for the exact event x channel matrix this mirrors. Plain bool columns rather than a
/// generic (EventType, Channel) table: only four event types exist today and a normalized table would
/// buy flexibility this product doesn't need yet.</summary>
public class ShopNotificationSettings : BaseEntity, IShopScoped
{
    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public bool LowStockWhatsapp { get; set; } = true;
    public bool LowStockMobile { get; set; } = true;

    public bool PurchaseDueWhatsapp { get; set; } = true;
    public bool PurchaseDueMobile { get; set; } = true;

    public bool PurchaseOverdueWhatsapp { get; set; } = true;
    public bool PurchaseOverdueMobile { get; set; } = true;

    public bool CustomerOutstandingWhatsapp { get; set; }
    public bool CustomerOutstandingMobile { get; set; } = true;

    public bool SalesPaymentDueWhatsapp { get; set; } = true;
    public bool SalesPaymentDueMobile { get; set; } = true;

    public bool SalesPaymentOverdueWhatsapp { get; set; } = true;
    public bool SalesPaymentOverdueMobile { get; set; } = true;
}
