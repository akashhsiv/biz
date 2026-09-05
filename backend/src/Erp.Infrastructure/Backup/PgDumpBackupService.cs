using System.Diagnostics;
using Erp.Application.Backup;
using Erp.Domain.Common;
using Erp.Domain.System;
using Erp.Infrastructure.Persistence;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Npgsql;

namespace Erp.Infrastructure.Backup;

/// <summary>
/// Shells out to the PostgreSQL `pg_dump` tool (custom format, -Fc) so backups can be restored
/// selectively with `pg_restore` later. Destination directory and pg_dump path are configurable
/// (appsettings "Backup:Directory" / "Backup:PgDumpPath") — see ARCHITECTURE.md §11.
/// </summary>
public class PgDumpBackupService(ErpDbContext db, IConfiguration configuration, ILogger<PgDumpBackupService> logger) : IBackupService
{
    public async Task<BackupResult> RunBackupAsync(BackupType type, Guid? triggeredBy, CancellationToken ct = default)
    {
        var id = Guid.NewGuid();
        string filePath = "";

        try
        {
            var directory = ResolveBackupDirectory();
            Directory.CreateDirectory(directory);

            var timestamp = DateTime.UtcNow.ToString("yyyyMMdd_HHmmss");
            filePath = Path.Combine(directory, $"erp_backup_{timestamp}.dump");

            var connectionString = configuration.GetConnectionString("ErpDatabase")
                ?? throw new InvalidOperationException("ErpDatabase connection string is not configured.");
            var builder = new NpgsqlConnectionStringBuilder(connectionString);

            var pgDumpPath = configuration["Backup:PgDumpPath"] ?? "pg_dump";

            var startInfo = new ProcessStartInfo
            {
                FileName = pgDumpPath,
                ArgumentList =
                {
                    "-h", builder.Host ?? "localhost",
                    "-p", (builder.Port == 0 ? 5432 : builder.Port).ToString(),
                    "-U", builder.Username ?? "",
                    "-Fc", "-f", filePath,
                    builder.Database ?? "erp",
                },
                RedirectStandardError = true,
                RedirectStandardOutput = true,
                UseShellExecute = false,
                Environment = { ["PGPASSWORD"] = builder.Password ?? "" },
            };

            using var process = Process.Start(startInfo) ?? throw new InvalidOperationException("Failed to start pg_dump.");
            var stderr = await process.StandardError.ReadToEndAsync(ct);
            await process.WaitForExitAsync(ct);

            if (process.ExitCode != 0)
                throw new InvalidOperationException($"pg_dump exited with code {process.ExitCode}: {stderr}");

            var size = new FileInfo(filePath).Length;

            db.BackupHistories.Add(new Erp.Domain.System.BackupHistory
            {
                Id = id,
                FilePath = filePath,
                SizeBytes = size,
                BackupType = type,
                Status = Erp.Domain.Common.BackupStatus.Success,
                TriggeredBy = triggeredBy,
                CreatedAt = DateTime.UtcNow,
            });
            await db.SaveChangesAsync(ct);

            logger.LogInformation("Backup {Id} succeeded: {Path} ({Size} bytes)", id, filePath, size);
            return new BackupResult(id, true, filePath, size, null);
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Backup {Id} failed", id);

            db.BackupHistories.Add(new Erp.Domain.System.BackupHistory
            {
                Id = id,
                FilePath = filePath,
                SizeBytes = 0,
                BackupType = type,
                Status = Erp.Domain.Common.BackupStatus.Failed,
                TriggeredBy = triggeredBy,
                CreatedAt = DateTime.UtcNow,
            });
            await db.SaveChangesAsync(ct);

            return new BackupResult(id, false, filePath, 0, ex.Message);
        }
    }

    /// <summary>Exposed publicly (not just used internally by RunBackupAsync) so a status endpoint
    /// can show the admin exactly where backups land without duplicating the drive-picking logic.</summary>
    public string ResolveBackupDirectory()
    {
        var configured = configuration["Backup:Directory"];
        if (!string.IsNullOrWhiteSpace(configured)) return configured;

        // No path configured: prefer a second drive if one exists, otherwise fall back to a
        // subfolder here with a visible warning — a second physical location is recommended, not required.
        var secondDrive = DriveInfo.GetDrives().FirstOrDefault(d => d.IsReady && !AppContext.BaseDirectory.StartsWith(d.Name, StringComparison.OrdinalIgnoreCase));
        if (secondDrive is not null)
        {
            return Path.Combine(secondDrive.Name, "ERP-Backups");
        }

        logger.LogWarning("No second drive detected and no Backup:Directory configured — backups will be stored on the same drive as the application. Configure a second-location path for real protection.");
        return Path.Combine(AppContext.BaseDirectory, "Backups");
    }
}
