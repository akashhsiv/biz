using Erp.Api.Auth;
using Erp.Application.Common;
using Erp.Application.Security;
using Erp.Domain.Identity;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record RoleDto(Guid Id, string Name, string? Description, bool IsSystemRole, List<string> Permissions);
public record PermissionDto(string Key, string Module, string? Description);
public record SetRolePermissionsRequest(List<string> PermissionKeys);

[ApiController]
[Route("api")]
public class RolesController(ErpDbContext db, IAuditService audit) : ControllerBase
{
    [HttpGet("roles")]
    [RequirePermission(PermissionKeys.RolesManage)]
    public async Task<ActionResult<List<RoleDto>>> ListRoles(CancellationToken ct)
    {
        var roles = await db.Roles
            .Include(r => r.RolePermissions).ThenInclude(rp => rp.Permission)
            .Select(r => new RoleDto(r.Id, r.Name, r.Description, r.IsSystemRole, r.RolePermissions.Select(rp => rp.Permission.Key).ToList()))
            .ToListAsync(ct);

        return Ok(roles);
    }

    [HttpGet("permissions")]
    [RequirePermission(PermissionKeys.RolesManage)]
    public async Task<ActionResult<List<PermissionDto>>> ListPermissions(CancellationToken ct)
    {
        var permissions = await db.Permissions
            .Select(p => new PermissionDto(p.Key, p.Module, p.Description))
            .ToListAsync(ct);

        return Ok(permissions);
    }

    [HttpPut("roles/{id:guid}/permissions")]
    [RequirePermission(PermissionKeys.RolesManage)]
    public async Task<IActionResult> SetRolePermissions(Guid id, SetRolePermissionsRequest request, CancellationToken ct)
    {
        var role = await db.Roles.Include(r => r.RolePermissions).ThenInclude(rp => rp.Permission).FirstOrDefaultAsync(r => r.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Role), id);

        var permissions = await db.Permissions.Where(p => request.PermissionKeys.Contains(p.Key)).ToListAsync(ct);
        var unknownKeys = request.PermissionKeys.Except(permissions.Select(p => p.Key)).ToList();
        if (unknownKeys.Count > 0)
            throw new ValidationAppException($"Unknown permission key(s): {string.Join(", ", unknownKeys)}");

        var oldKeys = role.RolePermissions.Select(rp => rp.Permission.Key).ToList();

        db.RolePermissions.RemoveRange(role.RolePermissions);
        role.RolePermissions = permissions.Select(p => new RolePermission { RoleId = role.Id, PermissionId = p.Id }).ToList();

        await audit.LogAsync("role.permissions_changed", nameof(Role), role.Id, oldValue: oldKeys, newValue: request.PermissionKeys, ct: ct);
        await db.SaveChangesAsync(ct);

        return NoContent();
    }
}
