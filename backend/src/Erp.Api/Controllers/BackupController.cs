using Erp.Api.Auth;
using Erp.Application.Backup;
using Erp.Application.Security;
using Erp.Domain.Common;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace Erp.Api.Controllers;

public record LastBackupDto(DateTime CreatedAt, BackupStatus Status, long SizeBytes, string FilePath);
public record BackupStatusDto(string BackupDirectory, string? DatabaseName, string? DatabaseHost, int DailyHourUtc, int RetentionCount, LastBackupDto? LastBackup);

/// <summary>Read-only visibility into the backup system for Shop Configuration - deliberately no
/// way to trigger a backup or change settings from here (confirmed decision), just where things are
/// and when the last one ran.</summary>
[ApiController]
[Route("api/backup")]
public class BackupController(ErpDbContext db, IBackupService backupService, IConfiguration configuration) : ControllerBase
{
    [HttpGet("status")]
    [RequirePermission(PermissionKeys.HostStatusView)]
    public async Task<ActionResult<BackupStatusDto>> Status(CancellationToken ct)
    {
        var directory = backupService.ResolveBackupDirectory();

        string? dbName = null, dbHost = null;
        var connectionString = configuration.GetConnectionString("ErpDatabase");
        if (!string.IsNullOrWhiteSpace(connectionString))
        {
            var builder = new NpgsqlConnectionStringBuilder(connectionString);
            dbName = builder.Database;
            dbHost = builder.Host;
        }

        var dailyHourUtc = configuration.GetValue("Backup:DailyHourUtc", 2);
        var retentionCount = configuration.GetValue("Backup:RetentionCount", 30);

        var last = await db.BackupHistories.AsNoTracking().OrderByDescending(b => b.CreatedAt).FirstOrDefaultAsync(ct);
        var lastDto = last is null ? null : new LastBackupDto(last.CreatedAt, last.Status, last.SizeBytes, last.FilePath);

        return Ok(new BackupStatusDto(directory, dbName, dbHost, dailyHourUtc, retentionCount, lastDto));
    }
}
