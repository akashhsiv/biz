using Erp.Domain.Common;

namespace Erp.Application.Backup;

public record BackupResult(Guid Id, bool Success, string FilePath, long SizeBytes, string? Error);

/// <summary>Runs `pg_dump` to a configured destination and records the attempt — ARCHITECTURE.md §11. Never throws; failures are recorded, not propagated, so a failed backup never takes down a request.</summary>
public interface IBackupService
{
    Task<BackupResult> RunBackupAsync(BackupType type, Guid? triggeredBy, CancellationToken ct = default);

    /// <summary>Resolves where backups land (configured directory, or the auto-picked second drive/
    /// fallback) without actually running one — used to show the admin the path in the UI.</summary>
    string ResolveBackupDirectory();
}
