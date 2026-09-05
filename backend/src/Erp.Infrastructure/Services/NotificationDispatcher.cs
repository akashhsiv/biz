using System.Text.Json;
using Erp.Domain.Common;
using Erp.Domain.Notifications;
using Erp.Domain.Whatsapp;
using Erp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace Erp.Infrastructure.Services;

/// <summary>Fans each Pending NotificationEvent out to whichever channels that shop enabled in
/// ShopNotificationSettings, then marks it Dispatched (or Failed with a reason). This is the ONLY
/// place that knows a WhatsappOutboxItem or MobilePushOutboxItem exists — business logic that raises
/// events (StockService, NotificationCheckWorker) never references either.
///
/// Mobile push: creating a MobilePushOutboxItem is as far as this goes. There is no push provider
/// (Firebase/APNs) wired up — that is an explicit future decision — so a Mobile-enabled event just
/// leaves a Pending row in that table forever today. Do not treat "Mobile enabled" as "delivered".</summary>
public class NotificationDispatcher(ErpDbContext db, ILogger<NotificationDispatcher> logger)
{
    public async Task ProcessPendingAsync(CancellationToken ct)
    {
        var pending = await db.NotificationEvents
            .Where(e => e.Status == NotificationEventStatus.Pending)
            .OrderBy(e => e.CreatedAt)
            .Take(50)
            .ToListAsync(ct);

        if (pending.Count == 0) return;

        foreach (var evt in pending)
        {
            try
            {
                await DispatchAsync(evt, ct);
                evt.Status = NotificationEventStatus.Dispatched;
                evt.DispatchedAt = DateTime.UtcNow;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed to dispatch NotificationEvent {Id}", evt.Id);
                evt.Status = NotificationEventStatus.Failed;
                evt.FailureReason = ex.Message;
            }
        }

        await db.SaveChangesAsync(ct);
    }

    private async Task DispatchAsync(NotificationEvent evt, CancellationToken ct)
    {
        var settings = await db.ShopNotificationSettings.AsNoTracking().FirstOrDefaultAsync(s => s.ShopId == evt.ShopId, ct);
        // No settings row yet for this shop — fall back to "nothing enabled" rather than guessing;
        // an admin who never opened Notification Settings gets no sends, not silent surprises.
        var (whatsapp, mobile) = settings is null ? (false, false) : ChannelsFor(evt.EventType, settings);

        if (whatsapp)
        {
            // There is no per-event recipient list yet (see ARCHITECTURE notes on "Notification
            // recipients" as an unresolved decision) — CompanySettings.ContactNumber is the closest
            // thing to a shop-level WhatsApp recipient today, so it's reused here rather than left
            // blank. A shop with no contact number configured simply gets no WhatsApp send for events.
            var contactNumber = await db.CompanySettings.AsNoTracking().Select(s => s.ContactNumber).FirstOrDefaultAsync(ct);
            if (!string.IsNullOrWhiteSpace(contactNumber))
            {
                db.WhatsappOutboxItems.Add(new WhatsappOutboxItem
                {
                    ShopId = evt.ShopId,
                    MessageType = WhatsappMessageType.Custom,
                    ReferenceType = evt.ReferenceType ?? DocumentReferenceType.ManualAdjustment,
                    ReferenceId = evt.ReferenceId ?? evt.Id,
                    RecipientNumber = contactNumber,
                    PayloadJson = JsonSerializer.Serialize(new { to = contactNumber, message = BuildMessage(evt) }),
                    Status = WhatsappOutboxStatus.Queued,
                    CreatedBy = Guid.Empty,
                    CreatedAt = DateTime.UtcNow,
                });
            }
        }

        if (mobile)
        {
            db.MobilePushOutboxItems.Add(new MobilePushOutboxItem
            {
                ShopId = evt.ShopId,
                NotificationEventId = evt.Id,
                RecipientDescription = "Shop Admins", // no device-registration model yet — see MobilePushOutboxItem doc comment.
                PayloadJson = evt.PayloadJson,
                Status = MobilePushOutboxStatus.Pending,
                CreatedAt = DateTime.UtcNow,
            });
        }
    }

    private static (bool Whatsapp, bool Mobile) ChannelsFor(NotificationEventType type, ShopNotificationSettings s) => type switch
    {
        NotificationEventType.LowStock => (s.LowStockWhatsapp, s.LowStockMobile),
        NotificationEventType.PurchaseDue => (s.PurchaseDueWhatsapp, s.PurchaseDueMobile),
        NotificationEventType.PurchaseOverdue => (s.PurchaseOverdueWhatsapp, s.PurchaseOverdueMobile),
        NotificationEventType.CustomerOutstanding => (s.CustomerOutstandingWhatsapp, s.CustomerOutstandingMobile),
        _ => (false, false),
    };

    private static string BuildMessage(NotificationEvent evt) => evt.EventType switch
    {
        NotificationEventType.LowStock => $"Low stock alert: {evt.PayloadJson}",
        NotificationEventType.PurchaseOverdue => $"Purchase overdue: {evt.PayloadJson}",
        _ => evt.PayloadJson,
    };
}
