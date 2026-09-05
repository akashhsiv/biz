using Erp.Api.Auth;
using Erp.Application.Auth;
using Erp.Application.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Erp.Api.Controllers;

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
