namespace Erp.Application.Notifications;

/// <summary>Mobile push delivery via Firebase Cloud Messaging. Implementations MUST be a safe no-op
/// (never throw, never block a caller) when Firebase isn't configured yet — see
/// Erp.Infrastructure.Services.PushNotificationService's doc comment. NotificationDispatcher calls
/// this once per registered DeviceToken for a Mobile-enabled event; a missing/broken push provider
/// must never stop dispatch from marking the underlying NotificationEvent Dispatched.</summary>
public interface IPushNotificationService
{
    /// <summary>True once a Firebase service account has been loaded successfully. NotificationDispatcher
    /// uses this to decide whether a MobilePushOutboxItem should end up NotConfigured vs Sent/Failed —
    /// it does not by itself guarantee any given SendAsync call will succeed.</summary>
    bool IsConfigured { get; }

    /// <summary>Sends one push message. Returns true if the message was accepted by FCM, false if
    /// Firebase isn't configured or the send failed for any reason — this method itself never throws.</summary>
    Task<bool> SendAsync(string token, string title, string body, CancellationToken ct = default);
}
