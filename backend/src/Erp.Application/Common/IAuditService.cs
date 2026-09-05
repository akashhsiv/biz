namespace Erp.Application.Common;

/// <summary>Writes an append-only AuditLog row. No update/delete path is ever exposed — see ARCHITECTURE.md §30.</summary>
public interface IAuditService
{
    Task LogAsync(string action, string entityType, Guid entityId, object? oldValue = null, object? newValue = null, string? reason = null, CancellationToken ct = default);
}
