using System.Security.Claims;
using System.Text.Encodings.Web;
using Erp.Application.Security;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authentication;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace Erp.Api.Auth;

public static class SessionAuthDefaults
{
    public const string Scheme = "Session";
    public const string PermissionClaimType = "permission";
}

/// <summary>Resolves the caller from the opaque bearer token against the sessions table. Never trusts a role/permission claim supplied by the client (there isn't one to supply — everything is looked up server-side).</summary>
public class SessionAuthenticationHandler(
    IOptionsMonitor<AuthenticationSchemeOptions> options,
    ILoggerFactory logger,
    UrlEncoder encoder,
    ErpDbContext db)
    : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!Request.Headers.TryGetValue("Authorization", out var headerValue))
            return AuthenticateResult.NoResult();

        var header = headerValue.ToString();
        if (!header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
            return AuthenticateResult.NoResult();

        var rawToken = header["Bearer ".Length..].Trim();
        if (string.IsNullOrEmpty(rawToken))
            return AuthenticateResult.Fail("Missing bearer token.");

        var tokenHash = TokenHasher.Hash(rawToken);

        var session = await db.Sessions
            .Include(s => s.User).ThenInclude(u => u.Role).ThenInclude(r => r.RolePermissions).ThenInclude(rp => rp.Permission)
            .FirstOrDefaultAsync(s => s.TokenHash == tokenHash);

        if (session is null || session.RevokedAt is not null || session.ExpiresAt < DateTime.UtcNow)
            return AuthenticateResult.Fail("Session is invalid or expired.");

        if (!session.User.IsActive)
            return AuthenticateResult.Fail("User account is deactivated.");

        session.LastSeenAt = DateTime.UtcNow;
        await db.SaveChangesAsync();

        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, session.User.Id.ToString()),
            new(ClaimTypes.Name, session.User.Username),
            new(ClaimTypes.Role, session.User.Role.Name),
        };
        claims.AddRange(session.User.Role.RolePermissions.Select(rp => new Claim(SessionAuthDefaults.PermissionClaimType, rp.Permission.Key)));

        var identity = new ClaimsIdentity(claims, SessionAuthDefaults.Scheme);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, SessionAuthDefaults.Scheme);

        return AuthenticateResult.Success(ticket);
    }
}
