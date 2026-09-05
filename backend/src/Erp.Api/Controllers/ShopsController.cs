using System.Security.Claims;
using Erp.Api.Auth;
using Erp.Application.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Erp.Api.Controllers;

/// <summary>Multi-shop rework: lets a logged-in user see which shops they can switch into (via
/// UserShopRole) before calling POST /api/auth/select-shop.</summary>
[ApiController]
[Route("api/shops")]
public class ShopsController(IAuthService authService) : ControllerBase
{
    [HttpGet]
    [Authorize(AuthenticationSchemes = SessionAuthDefaults.Scheme)]
    public async Task<ActionResult<IReadOnlyList<ShopSummaryDto>>> GetMyShops(CancellationToken ct)
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);
        var shops = await authService.GetAccessibleShopsAsync(userId, ct);
        return Ok(shops);
    }
}
