using Erp.Application.Auth;
using Erp.Application.Common;
using Erp.Application.Security;
using Erp.Domain.Audit;
using Erp.Domain.Identity;
using Erp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Erp.Infrastructure.Services;

public class AuthService(ErpDbContext db) : IAuthService
{
    private static readonly TimeSpan SessionLifetime = TimeSpan.FromHours(12);

    public async Task<LoginResult> LoginAsync(string username, string password, CancellationToken ct = default)
    {
        var user = await db.Users
            .Include(u => u.Role).ThenInclude(r => r.RolePermissions).ThenInclude(rp => rp.Permission)
            .FirstOrDefaultAsync(u => u.Username == username, ct);

        if (user is null || !user.IsActive || !BCrypt.Net.BCrypt.Verify(password, user.PasswordHash))
        {
            throw new ValidationAppException("Invalid username or password.");
        }

        var rawToken = TokenHasher.GenerateRawToken();
        var expiresAt = DateTime.UtcNow.Add(SessionLifetime);

        db.Sessions.Add(new Session
        {
            TokenHash = TokenHasher.Hash(rawToken),
            UserId = user.Id,
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = expiresAt,
        });

        user.LastLoginAt = DateTime.UtcNow;

        db.AuditLogs.Add(new AuditLog
        {
            UserId = user.Id,
            RoleAtTime = user.Role.Name,
            Action = "user.login",
            EntityType = nameof(User),
            EntityId = user.Id,
            CreatedAt = DateTime.UtcNow,
        });

        await db.SaveChangesAsync(ct);

        var permissions = user.Role.RolePermissions.Select(rp => rp.Permission.Key).ToList();
        return new LoginResult(rawToken, expiresAt, user.Id, user.Username, user.FullName, user.Role.Name, permissions);
    }

    public async Task<SelectShopResult> SelectShopAsync(Guid userId, string tokenHash, Guid shopId, CancellationToken ct = default)
    {
        var grant = await db.Set<UserShopRole>()
            .Include(usr => usr.Role).ThenInclude(r => r.RolePermissions).ThenInclude(rp => rp.Permission)
            .FirstOrDefaultAsync(usr => usr.UserId == userId && usr.ShopId == shopId, ct)
            ?? throw new ValidationAppException("You do not have access to this shop.");

        var session = await db.Sessions.FirstOrDefaultAsync(s => s.TokenHash == tokenHash && s.UserId == userId, ct)
            ?? throw new ConflictAppException("Session not found.");

        session.ShopId = shopId;
        await db.SaveChangesAsync(ct);

        var permissions = grant.Role.RolePermissions.Select(rp => rp.Permission.Key).ToList();
        return new SelectShopResult(shopId, grant.Role.Name, permissions);
    }

    public async Task<IReadOnlyList<ShopSummaryDto>> GetAccessibleShopsAsync(Guid userId, CancellationToken ct = default)
    {
        return await db.Set<UserShopRole>()
            .Where(usr => usr.UserId == userId)
            .Select(usr => usr.Shop)
            .Distinct()
            .Select(s => new ShopSummaryDto(s.Id, s.Name, s.Gstin, s.IsActive))
            .ToListAsync(ct);
    }

    public async Task LogoutAsync(string tokenHash, CancellationToken ct = default)
    {
        var session = await db.Sessions.Include(s => s.User).ThenInclude(u => u.Role).FirstOrDefaultAsync(s => s.TokenHash == tokenHash, ct);
        if (session is null) return;

        session.RevokedAt = DateTime.UtcNow;

        db.AuditLogs.Add(new AuditLog
        {
            UserId = session.UserId,
            RoleAtTime = session.User.Role.Name,
            Action = "user.logout",
            EntityType = nameof(User),
            EntityId = session.UserId,
            CreatedAt = DateTime.UtcNow,
        });

        await db.SaveChangesAsync(ct);
    }
}
