using Erp.Domain.Common;

namespace Erp.Domain.Notifications;

/// <summary>A channel-agnostic notification event raised by business logic (e.g. a stock adjustment
/// dropping a StockBalance to/under Item.MinimumStock, or a daily overdue-purchase sweep). Business
/// code only calls INotificationEventService.CreateEventAsync — it never knows about WhatsApp or
/// mobile push. NotificationDispatcher later fans a Pending row out to whichever channels are enabled
/// in that shop's ShopNotificationSettings, then marks it Dispatched/Failed.</summary>
public class NotificationEvent : BaseEntity, IShopScoped
{
    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public NotificationEventType EventType { get; set; }

    /// <summary>Event-specific data (item name/current stock/minimum for LowStock; vendor/outstanding/
    /// due date for PurchaseOverdue, etc.) — kept as a JSON blob so new event types don't need schema
    /// changes, mirroring WhatsappOutboxItem.PayloadJson.</summary>
    public string PayloadJson { get; set; } = default!;

    public NotificationEventStatus Status { get; set; } = NotificationEventStatus.Pending;

    /// <summary>Set when dispatch fails on both channels (or on an unexpected exception) so an admin
    /// can see why. Null while Pending/Dispatched.</summary>
    public string? FailureReason { get; set; }

    /// <summary>Optional link back to the document/entity that caused this event (e.g. the
    /// PurchaseOrder for a PurchaseOverdue event). Used by NotificationCheckWorker's daily overdue
    /// sweep to avoid re-raising an event for the same PO more than once a day — see ReferenceType.</summary>
    public DocumentReferenceType? ReferenceType { get; set; }
    public Guid? ReferenceId { get; set; }

    public DateTime? DispatchedAt { get; set; }
}
