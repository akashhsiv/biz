using System.Security.Claims;
using Erp.Api.Auth;
using Erp.Application.Auth;
using Erp.Application.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Erp.Api.Controllers;

public record SelectShopRequest(Guid ShopId);

[ApiController]
[Route("api/auth")]
public class AuthController(IAuthService authService) : ControllerBase
{
    [HttpPost("login")]
    [AllowAnonymous]
    public async Task<ActionResult<LoginResult>> Login(LoginRequest request, CancellationToken ct)
    {
        var result = await authService.LoginAsync(request.Username, request.Password, ct);
        return Ok(result);
    }

    /// Lets a client confirm its cached token is still valid for whichever Host it's currently
    /// pointed at - a Slave caches its token/profile locally with no per-Host scoping, so switching
    /// which Host it connects to (or a session being revoked/expired server-side) needs this
    /// round-trip to be caught instead of trusting the local cache blindly.
    [HttpGet("me")]
    [Authorize(AuthenticationSchemes = SessionAuthDefaults.Scheme)]
    public IActionResult Me() => NoContent();

    /// Sets the active shop for the caller's current session (multi-shop rework). Requires a
    /// UserShopRole grant for that shop; the returned role/permissions reflect that shop, not
    /// whatever the legacy User.RoleId says.
    [HttpPost("select-shop")]
    [Authorize(AuthenticationSchemes = SessionAuthDefaults.Scheme)]
    public async Task<ActionResult<SelectShopResult>> SelectShop(SelectShopRequest request, CancellationToken ct)
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var header = Request.Headers.Authorization.ToString();
        var rawToken = header["Bearer ".Length..].Trim();

        var result = await authService.SelectShopAsync(userId, TokenHasher.Hash(rawToken), request.ShopId, ct);
        return Ok(result);
    }

    [HttpPost("logout")]
    [Authorize(AuthenticationSchemes = SessionAuthDefaults.Scheme)]
    public async Task<IActionResult> Logout(CancellationToken ct)
    {
        var header = Request.Headers.Authorization.ToString();
        var rawToken = header["Bearer ".Length..].Trim();
        await authService.LogoutAsync(TokenHasher.Hash(rawToken), ct);
        return NoContent();
    }
}
