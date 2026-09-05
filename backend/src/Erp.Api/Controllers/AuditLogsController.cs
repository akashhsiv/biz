using Erp.Api.Auth;
using Erp.Application.Security;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record AuditLogDto(Guid Id, Guid UserId, string RoleAtTime, string Action, string EntityType, Guid EntityId, string? OldValueJson, string? NewValueJson, string? Reason, DateTime CreatedAt);

[ApiController]
[Route("api/audit-logs")]
public class AuditLogsController(ErpDbContext db) : ControllerBase
{
    [HttpGet]
    [RequirePermission(PermissionKeys.AuditLogsView)]
    public async Task<ActionResult<List<AuditLogDto>>> List(
        [FromQuery] string? entityType, [FromQuery] Guid? entityId, [FromQuery] Guid? userId,
        [FromQuery] int take = 200, CancellationToken ct = default)
    {
        var query = db.AuditLogs.AsQueryable();
        if (!string.IsNullOrWhiteSpace(entityType)) query = query.Where(a => a.EntityType == entityType);
        if (entityId is { } eid) query = query.Where(a => a.EntityId == eid);
        if (userId is { } uid) query = query.Where(a => a.UserId == uid);

        var logs = await query.OrderByDescending(a => a.CreatedAt).Take(Math.Clamp(take, 1, 1000))
            .Select(a => new AuditLogDto(a.Id, a.UserId, a.RoleAtTime, a.Action, a.EntityType, a.EntityId, a.OldValueJson, a.NewValueJson, a.Reason, a.CreatedAt))
            .ToListAsync(ct);

        return Ok(logs);
    }
}
