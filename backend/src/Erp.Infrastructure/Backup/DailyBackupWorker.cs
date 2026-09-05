using Erp.Application.Backup;
using Erp.Domain.Common;
using Erp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Erp.Infrastructure.Backup;

/// <summary>Runs once a day at a configurable local hour (default 02:00) — ARCHITECTURE.md §11. In-process so the shop owner never has to configure Windows Task Scheduler by hand.</summary>
public class DailyBackupWorker(IServiceScopeFactory scopeFactory, IConfiguration configuration, ILogger<DailyBackupWorker> logger) : BackgroundService
{
    private const int DefaultRetentionCount = 30;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            var delay = TimeUntilNextRun();
            try
            {
                await Task.Delay(delay, stoppingToken);
            }
            catch (TaskCanceledException)
            {
                break;
            }

            await RunAndPruneAsync(stoppingToken);
        }
    }

    private async Task RunAndPruneAsync(CancellationToken ct)
    {
        using var scope = scopeFactory.CreateScope();
        var backupService = scope.ServiceProvider.GetRequiredService<IBackupService>();
        var db = scope.ServiceProvider.GetRequiredService<ErpDbContext>();

        var result = await backupService.RunBackupAsync(BackupType.Automatic, triggeredBy: null, ct);
        if (!result.Success)
        {
            logger.LogError("Scheduled backup failed: {Error}", result.Error);
            return;
        }

        var retention = configuration.GetValue<int?>("Backup:RetentionCount") ?? DefaultRetentionCount;
        var old = await db.BackupHistories
            .Where(b => b.Status == BackupStatus.Success)
            .OrderByDescending(b => b.CreatedAt)
            .Skip(retention)
            .ToListAsync(ct);

        foreach (var backup in old)
        {
            try
            {
                if (File.Exists(backup.FilePath)) File.Delete(backup.FilePath);
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Could not delete old backup file {Path}", backup.FilePath);
            }
        }

        if (old.Count > 0)
        {
            db.BackupHistories.RemoveRange(old);
            await db.SaveChangesAsync(ct);
        }
    }

    private TimeSpan TimeUntilNextRun()
    {
        var hour = configuration.GetValue<int?>("Backup:DailyHourUtc") ?? 2;
        var now = DateTime.UtcNow;
        var next = new DateTime(now.Year, now.Month, now.Day, hour, 0, 0, DateTimeKind.Utc);
        if (next <= now) next = next.AddDays(1);
        return next - now;
    }
}
