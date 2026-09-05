using Erp.Application.Notifications;
using Erp.Domain.Common;
using Erp.Domain.Purchases;
using Erp.Domain.Sales;
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

        var dueSoonDaysByShop = await db.ShopNotificationSettings
            .Select(s => new { s.ShopId, s.DueSoonDays })
            .ToDictionaryAsync(s => s.ShopId, s => s.DueSoonDays, ct);
        var defaultDueSoonDays = configuration.GetValue("Notifications:DueSoonDays", 3);

        await RunPurchaseDueSweepAsync(db, notificationEvents, now, dueSoonDaysByShop, defaultDueSoonDays, ct);
        await RunSalesPaymentSweepAsync(db, notificationEvents, now, dueSoonDaysByShop, defaultDueSoonDays, ct);
    }

    /// <summary>PurchaseDue: PurchaseOrders whose DueDate falls within the next N days (not yet passed —
    /// once passed it's the PurchaseOverdue sweep above's job) with an outstanding balance still owed.
    /// N comes from the PO's own shop's ShopNotificationSettings.DueSoonDays (runtime-configurable by a
    /// shop admin), falling back to the static Notifications:DueSoonDays config value if that shop has
    /// no settings row yet. Same 24h duplicate-prevention pattern as PurchaseOverdue.</summary>
    private async Task RunPurchaseDueSweepAsync(ErpDbContext db, INotificationEventService notificationEvents, DateTime now, IReadOnlyDictionary<Guid, int> dueSoonDaysByShop, int defaultDueSoonDays, CancellationToken ct)
    {
        var maxHorizon = now.AddDays(dueSoonDaysByShop.Count > 0 ? Math.Max(dueSoonDaysByShop.Values.Max(), defaultDueSoonDays) : defaultDueSoonDays);

        var dueSoon = await db.PurchaseOrders
            .Include(po => po.Supplier)
            .Include(po => po.Payments)
            .Where(po => po.DueDate != null && po.DueDate >= now && po.DueDate <= maxHorizon && po.Status != PurchaseOrderStatus.Cancelled)
            .ToListAsync(ct);

        var raised = 0;
        foreach (var po in dueSoon)
        {
            var dueSoonDays = dueSoonDaysByShop.GetValueOrDefault(po.ShopId, defaultDueSoonDays);
            if (po.DueDate > now.AddDays(dueSoonDays)) continue;

            var paid = po.Payments.Where(p => p.Status == PurchasePaymentStatus.Completed).Sum(p => p.Amount);
            var outstanding = po.GrandTotal - paid;
            if (outstanding <= 0) continue;

            var alreadyRaisedRecently = await db.NotificationEvents.AnyAsync(e =>
                e.ReferenceType == DocumentReferenceType.PurchaseOrder &&
                e.ReferenceId == po.Id &&
                e.EventType == NotificationEventType.PurchaseDue &&
                e.CreatedAt > now.AddHours(-24), ct);
            if (alreadyRaisedRecently) continue;

            await notificationEvents.CreateEventAsync(po.ShopId, NotificationEventType.PurchaseDue, new
            {
                purchaseOrderId = po.Id,
                poNumber = po.PoNumber,
                supplierName = po.Supplier.Name,
                outstanding,
                dueDate = po.DueDate,
            }, referenceType: DocumentReferenceType.PurchaseOrder, referenceId: po.Id, ct: ct);
            raised++;
        }

        if (raised > 0) await db.SaveChangesAsync(ct);
    }

    /// <summary>SalesPaymentDue (DueDate within the next N days, not yet passed) and SalesPaymentOverdue
    /// (DueDate already passed), both gated on OutstandingTotal > 0. N comes from the invoice's own
    /// shop's ShopNotificationSettings.DueSoonDays, same fallback rule as the purchase sweep above.
    /// Same 24h duplicate-prevention pattern as the PurchaseOverdue sweep above.</summary>
    private async Task RunSalesPaymentSweepAsync(ErpDbContext db, INotificationEventService notificationEvents, DateTime now, IReadOnlyDictionary<Guid, int> dueSoonDaysByShop, int defaultDueSoonDays, CancellationToken ct)
    {
        var maxHorizon = now.AddDays(dueSoonDaysByShop.Count > 0 ? Math.Max(dueSoonDaysByShop.Values.Max(), defaultDueSoonDays) : defaultDueSoonDays);

        var candidates = await db.SalesInvoices
            .Include(i => i.Customer)
            .Where(i => i.DueDate != null && i.OutstandingTotal > 0 && i.Status != SalesInvoiceStatus.Cancelled && i.DueDate <= maxHorizon)
            .ToListAsync(ct);

        var raised = 0;
        foreach (var invoice in candidates)
        {
            var isOverdue = invoice.DueDate!.Value < now;
            if (!isOverdue)
            {
                var dueSoonDays = dueSoonDaysByShop.GetValueOrDefault(invoice.ShopId, defaultDueSoonDays);
                if (invoice.DueDate > now.AddDays(dueSoonDays)) continue;
            }
            var eventType = isOverdue ? NotificationEventType.SalesPaymentOverdue : NotificationEventType.SalesPaymentDue;

            var alreadyRaisedRecently = await db.NotificationEvents.AnyAsync(e =>
                e.ReferenceType == DocumentReferenceType.SalesInvoice &&
                e.ReferenceId == invoice.Id &&
                e.EventType == eventType &&
                e.CreatedAt > now.AddHours(-24), ct);
            if (alreadyRaisedRecently) continue;

            await notificationEvents.CreateEventAsync(invoice.ShopId, eventType, new
            {
                salesInvoiceId = invoice.Id,
                invoiceNumber = invoice.InvoiceNumber,
                customerName = invoice.Customer.Name,
                outstanding = invoice.OutstandingTotal,
                dueDate = invoice.DueDate,
            }, referenceType: DocumentReferenceType.SalesInvoice, referenceId: invoice.Id, ct: ct);
            raised++;
        }

        if (raised > 0) await db.SaveChangesAsync(ct);
    }

    private async Task RunDispatchAsync(CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var dispatcher = scope.ServiceProvider.GetRequiredService<NotificationDispatcher>();
        await dispatcher.ProcessPendingAsync(ct);
    }
}
