using System.Text.Json;
using Erp.Application.Notifications;
using Erp.Domain.Common;
using Erp.Domain.Notifications;
using Erp.Infrastructure.Persistence;

namespace Erp.Infrastructure.Services;

/// <summary>Deliberately dumb: just inserts a Pending NotificationEvent row and lets the caller's own
/// SaveChangesAsync persist it (same "don't commit, the caller commits" convention IStockService
/// documents) so raising a low-stock event can happen inside the same transaction as the stock
/// adjustment that triggered it, without a separate round-trip.</summary>
public class NotificationEventService(ErpDbContext db) : INotificationEventService
{
    public Task CreateEventAsync(Guid shopId, NotificationEventType eventType, object payload,
        DocumentReferenceType? referenceType = null, Guid? referenceId = null, CancellationToken ct = default)
    {
        db.NotificationEvents.Add(new NotificationEvent
        {
            ShopId = shopId,
            EventType = eventType,
            PayloadJson = JsonSerializer.Serialize(payload),
            Status = NotificationEventStatus.Pending,
            ReferenceType = referenceType,
            ReferenceId = referenceId,
        });

        return Task.CompletedTask;
    }
}
