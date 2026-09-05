using Erp.Domain.Common;

namespace Erp.Application.Notifications;

/// <summary>The only notification touchpoint business logic should know about. Implementations just
/// insert a Pending NotificationEvent row — delivery (WhatsApp/Mobile) is entirely NotificationDispatcher's
/// concern, resolved later from that shop's ShopNotificationSettings. Callers never learn or care which
/// channels end up used.</summary>
public interface INotificationEventService
{
    /// <summary>Creates a Pending event for the given shop. <paramref name="payload"/> is serialized to
    /// JSON as-is (an anonymous object is fine) — keep it small and event-specific (e.g. item name/
    /// current stock/minimum for LowStock).</summary>
    Task CreateEventAsync(Guid shopId, NotificationEventType eventType, object payload,
        DocumentReferenceType? referenceType = null, Guid? referenceId = null, CancellationToken ct = default);
}
