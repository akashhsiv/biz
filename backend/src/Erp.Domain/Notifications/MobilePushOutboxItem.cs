using Erp.Domain.Common;

namespace Erp.Domain.Notifications;

/// <summary>Placeholder outbox for the Mobile Push channel — mirrors WhatsappOutboxItem's shape so the
/// data model is ready, but NOTHING actually delivers these yet: no push provider (Firebase/APNs) has
/// been chosen. Rows are created by NotificationDispatcher whenever Mobile is enabled for an event
/// type and just sit Pending forever until a provider decision is made and a worker analogous to
/// WhatsappOutboxWorker is written to drain this table. Do not build provider integration against
/// this without that explicit decision.</summary>
public class MobilePushOutboxItem : IShopScoped
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public Guid NotificationEventId { get; set; }
    public NotificationEvent NotificationEvent { get; set; } = default!;

    /// <summary>Free-text description of the intended recipient(s) (e.g. "Shop Admins") — there is no
    /// device-token/registration model yet, so this is informational only until a provider is wired up.</summary>
    public string RecipientDescription { get; set; } = default!;

    public string PayloadJson { get; set; } = default!;

    public MobilePushOutboxStatus Status { get; set; } = MobilePushOutboxStatus.Pending;

    public DateTime CreatedAt { get; set; }
}
