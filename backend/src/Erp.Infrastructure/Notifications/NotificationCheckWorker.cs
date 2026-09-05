using Erp.Application.Notifications;
using Erp.Domain.Common;
using Erp.Domain.Purchases;
using Erp.Infrastructure.Persistence;
using Erp.Infrastructure.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Erp.Infrastructure.Notifications;

/// <summary>Two jobs in one worker, mirroring DailyBackupWorker's once-a-day-at-a-configurable-hour
/// shape:
///   1. Once a day, sweep PurchaseOrders whose DueDate has passed with an outstanding balance still
///      owed, and raise a PURCHASE_OVERDUE NotificationEvent for each — "overdue" is a function of time
///      passing, not a state change, so there's no natural write-path hook to piggyback on the way
///      LowStock piggybacks on StockService.DecrementAsync.
///   2. On a much shorter interval, run NotificationDispatcher over whatever Pending events exist
///      (raised either by the sweep above or synchronously by business logic, e.g. StockService) so
///      dispatch latency isn't tied to the once-a-day cadence.
/// </summary>
public class NotificationCheckWorker(IServiceScopeFactory scopeFactory, IConfiguration configuration, ILogger<NotificationCheckWorker> logger) : BackgroundService
{
    private static readonly TimeSpan DispatchInterval = TimeSpan.FromMinutes(1);
    private DateTime _lastOverdueSweepDate = DateTime.MinValue;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(DispatchInterval);
        do
        {
            try
            {
                await RunOverdueSweepIfDueAsync(stoppingToken);
                await RunDispatchAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "NotificationCheckWorker tick failed unexpectedly");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    /// <summary>Runs at most once per calendar day (UTC), at/after the configured hour — same
    /// Backup:DailyHourUtc-style knob as DailyBackupWorker, but its own key so the two schedules are
    /// independently configurable.</summary>
    private async Task RunOverdueSweepIfDueAsync(CancellationToken ct)
    {
        var hour = configuration.GetValue<int?>("Notifications:OverdueSweepHourUtc") ?? 3;
        var now = DateTime.UtcNow;
        if (now.Date == _lastOverdueSweepDate.Date || now.Hour < hour) return;

        _lastOverdueSweepDate = now.Date;

        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ErpDbContext>();
        var notificationEvents = scope.ServiceProvider.GetRequiredService<INotificationEventService>();

        var overdue = await db.PurchaseOrders
            .Include(po => po.Supplier)
            .Include(po => po.Payments)
            .Where(po => po.DueDate != null && po.DueDate < now && po.Status != PurchaseOrderStatus.Cancelled)
            .ToListAsync(ct);

        foreach (var po in overdue)
        {
            var paid = po.Payments.Where(p => p.Status == Erp.Domain.Common.PurchasePaymentStatus.Completed).Sum(p => p.Amount);
            var outstanding = po.GrandTotal - paid;
            if (outstanding <= 0) continue;

            // Duplicate-prevention: skip if a NotificationEvent already exists for this exact PO
            // (ReferenceType/ReferenceId) created within the last 24h — cheaper and less fragile than
            // tracking "last swept date" per-PO, and self-heals if the worker misses a day.
            var alreadyRaisedRecently = await db.NotificationEvents.AnyAsync(e =>
                e.ReferenceType == DocumentReferenceType.PurchaseOrder &&
                e.ReferenceId == po.Id &&
                e.EventType == NotificationEventType.PurchaseOverdue &&
                e.CreatedAt > now.AddHours(-24), ct);
            if (alreadyRaisedRecently) continue;

            await notificationEvents.CreateEventAsync(po.ShopId, NotificationEventType.PurchaseOverdue, new
            {
                purchaseOrderId = po.Id,
                poNumber = po.PoNumber,
                supplierName = po.Supplier.Name,
                outstanding,
                dueDate = po.DueDate,
            }, referenceType: DocumentReferenceType.PurchaseOrder, referenceId: po.Id, ct: ct);
        }

        if (overdue.Count > 0) await db.SaveChangesAsync(ct);
    }

    private async Task RunDispatchAsync(CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var dispatcher = scope.ServiceProvider.GetRequiredService<NotificationDispatcher>();
        await dispatcher.ProcessPendingAsync(ct);
    }
}
