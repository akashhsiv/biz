using Erp.Api.Auth;
using Erp.Application.Common;
using Erp.Application.Security;
using Erp.Domain.Identity;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record UserDto(Guid Id, string Username, string FullName, string RoleName, Guid RoleId, bool IsActive, DateTime? LastLoginAt);
public record UserDirectoryEntryDto(Guid Id, string FullName);
public record CreateUserRequest(string Username, string Password, string FullName, Guid RoleId);
public record UpdateUserRequest(string FullName, Guid RoleId, bool IsActive);

[ApiController]
[Route("api/users")]
public class UsersController(ErpDbContext db, IAuditService audit) : ControllerBase
{
    [HttpGet]
    [RequirePermission(PermissionKeys.UsersManage)]
    public async Task<ActionResult<List<UserDto>>> List(CancellationToken ct)
    {
        var users = await db.Users.Include(u => u.Role)
            .Select(u => new UserDto(u.Id, u.Username, u.FullName, u.Role.Name, u.RoleId, u.IsActive, u.LastLoginAt))
            .ToListAsync(ct);

        return Ok(users);
    }

    /// <summary>Id + full name only, for any authenticated user - lets list screens show "Created By"
    /// without needing UsersManage (which most staff roles don't have). Never exposes username,
    /// role, active status, or login history - see UserDto/List above for the gated full record.</summary>
    [HttpGet("directory")]
    public async Task<ActionResult<List<UserDirectoryEntryDto>>> Directory(CancellationToken ct)
    {
        var users = await db.Users.Select(u => new UserDirectoryEntryDto(u.Id, u.FullName)).ToListAsync(ct);
        return Ok(users);
    }

    [HttpPost]
    [RequirePermission(PermissionKeys.UsersManage)]
    public async Task<ActionResult<UserDto>> Create(CreateUserRequest request, CancellationToken ct)
    {
        if (await db.Users.AnyAsync(u => u.Username == request.Username, ct))
            throw new ValidationAppException($"Username '{request.Username}' is already taken.");

        var role = await db.Roles.FindAsync([request.RoleId], ct)
            ?? throw new NotFoundAppException(nameof(Role), request.RoleId);

        var user = new User
        {
            Username = request.Username,
            FullName = request.FullName,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            RoleId = role.Id,
            IsActive = true,
        };

        db.Users.Add(user);
        await audit.LogAsync("user.created", nameof(User), user.Id, newValue: new { user.Username, RoleName = role.Name }, ct: ct);
        await db.SaveChangesAsync(ct);

        return Ok(new UserDto(user.Id, user.Username, user.FullName, role.Name, role.Id, user.IsActive, null));
    }

    [HttpPut("{id:guid}")]
    [RequirePermission(PermissionKeys.UsersManage)]
    public async Task<ActionResult<UserDto>> Update(Guid id, UpdateUserRequest request, CancellationToken ct)
    {
        var user = await db.Users.Include(u => u.Role).FirstOrDefaultAsync(u => u.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(User), id);

        var role = await db.Roles.FindAsync([request.RoleId], ct)
            ?? throw new NotFoundAppException(nameof(Role), request.RoleId);

        var oldValue = new { user.FullName, RoleName = user.Role.Name, user.IsActive };

        user.FullName = request.FullName;
        user.RoleId = role.Id;
        user.IsActive = request.IsActive;

        await audit.LogAsync("user.updated", nameof(User), user.Id, oldValue, new { user.FullName, RoleName = role.Name, user.IsActive }, ct: ct);
        await db.SaveChangesAsync(ct);

        return Ok(new UserDto(user.Id, user.Username, user.FullName, role.Name, role.Id, user.IsActive, user.LastLoginAt));
    }
}
