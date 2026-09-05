using System.Text.Json;
using Erp.Application.Common;
using Erp.Domain.Audit;
using Erp.Infrastructure.Persistence;

namespace Erp.Infrastructure.Services;

public class AuditService(ErpDbContext db, ICurrentUserService currentUser) : IAuditService
{
    public Task LogAsync(string action, string entityType, Guid entityId, object? oldValue = null, object? newValue = null, string? reason = null, CancellationToken ct = default)
    {
        db.AuditLogs.Add(new AuditLog
        {
            UserId = currentUser.UserId,
            RoleAtTime = currentUser.RoleName,
            Action = action,
            EntityType = entityType,
            EntityId = entityId,
            OldValueJson = oldValue is null ? null : JsonSerializer.Serialize(oldValue),
            NewValueJson = newValue is null ? null : JsonSerializer.Serialize(newValue),
            Reason = reason,
            CreatedAt = DateTime.UtcNow,
        });

        // Intentionally not saved here — audit rows are added to the same DbContext/transaction
        // as the business change they describe, and committed together by the caller's SaveChangesAsync.
        return Task.CompletedTask;
    }
}
