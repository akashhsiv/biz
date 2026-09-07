using Erp.Domain.Common;

namespace Erp.Domain.Notifications;

/// <summary>An FCM registration token for one device, used to deliver mobile push via
/// PushNotificationService. A token belongs to exactly one device, so re-registering the same token
/// under a different user (device changed hands, or the app re-registered after a re-login) is an
/// upsert keyed on Token — see NotificationsController.RegisterDeviceToken — rather than a duplicate
/// row.</summary>
public class DeviceToken : BaseEntity, IShopScoped
{
    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public Guid UserId { get; set; }

    public string Token { get; set; } = default!;

    /// <summary>e.g. "android" / "ios" / "windows" — informational, used only for logging/diagnostics.</summary>
    public string Platform { get; set; } = default!;

    public DateTime LastSeenAt { get; set; }
}
