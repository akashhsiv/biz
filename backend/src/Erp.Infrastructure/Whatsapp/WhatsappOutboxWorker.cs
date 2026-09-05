using Erp.Domain.Common;
using Erp.Domain.Whatsapp;
using Erp.Infrastructure.Common;
using Erp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Erp.Infrastructure.Whatsapp;

/// <summary>
/// Polls the outbox and attempts delivery via a local Baileys HTTP service. Runs independently of
/// every ERP transaction — a down/unreachable Baileys service just leaves rows Queued/Failed for
/// later retry, never blocks or rolls back a sale — ARCHITECTURE.md §36/§37.
/// </summary>
public class WhatsappOutboxWorker(IServiceScopeFactory scopeFactory, WhatsappBridgeLocator bridgeLocator, WhatsappSenderService sender, ILogger<WhatsappOutboxWorker> logger)
    : BackgroundService
{
    private const int MaxAttempts = 5;
    private static readonly TimeSpan PollInterval = TimeSpan.FromSeconds(30);
    private static bool _loggedMissingConfig;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(PollInterval);
        do
        {
            try
            {
                await ProcessQueueAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "WhatsApp outbox processing failed unexpectedly");
                await ServerFileLogger.LogAsync("whatsapp", $"Outbox processing failed unexpectedly.\n{ex}");
            }
        }
        while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    private async Task ProcessQueueAsync(CancellationToken ct)
    {
        var baseUrl = bridgeLocator.BaseUrl;
        if (string.IsNullOrWhiteSpace(baseUrl))
        {
            // Logged once (not every 30s poll) so "WhatsApp isn't sending" has a real trace somewhere
            // instead of silently doing nothing forever, without flooding the log on every tick.
            if (!_loggedMissingConfig)
            {
                _loggedMissingConfig = true;
                await ServerFileLogger.LogAsync("whatsapp", "Could not resolve the WhatsApp bridge's URL (no Whatsapp:BaileysBaseUrl configured and no resolved-port.txt found next to the bridge) - outbox will not be processed until this is set.");
            }
            return;
        }

        using var scope = scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ErpDbContext>();

        var pending = await db.WhatsappOutboxItems
            .Where(w => w.Status == WhatsappOutboxStatus.Queued)
            .OrderBy(w => w.CreatedAt)
            .Take(20)
            .ToListAsync(ct);

        if (pending.Count == 0) return;

        foreach (var item in pending)
        {
            var (success, error) = await sender.TrySendAsync(item.PayloadJson, ct);
            item.Attempts++;

            if (success)
            {
                item.Status = WhatsappOutboxStatus.Sent;
                item.SentAt = DateTime.UtcNow;
            }
            else
            {
                item.LastError = error;
                item.Status = item.Attempts >= MaxAttempts ? WhatsappOutboxStatus.Failed : WhatsappOutboxStatus.Queued;
                await ServerFileLogger.LogAsync("whatsapp", $"Send failed for outbox item {item.Id} (attempt {item.Attempts}): {error}");
            }
        }

        await db.SaveChangesAsync(ct);
    }
}
