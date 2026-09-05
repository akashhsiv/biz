using System.Security.Claims;
using Erp.Application.Common;

namespace Erp.Api.Auth;

public class HttpCurrentUserService(IHttpContextAccessor accessor) : ICurrentUserService
{
    private ClaimsPrincipal? Principal => accessor.HttpContext?.User;

    public bool IsAuthenticated => Principal?.Identity?.IsAuthenticated ?? false;

    public Guid UserId => Guid.TryParse(Principal?.FindFirstValue(ClaimTypes.NameIdentifier), out var id) ? id : Guid.Empty;

    public string Username => Principal?.FindFirstValue(ClaimTypes.Name) ?? string.Empty;

    public string RoleName => Principal?.FindFirstValue(ClaimTypes.Role) ?? string.Empty;

    public IReadOnlySet<string> Permissions => Principal?
        .FindAll(SessionAuthDefaults.PermissionClaimType)
        .Select(c => c.Value)
        .ToHashSet() ?? new HashSet<string>();

    public bool HasPermission(string permissionKey) => Permissions.Contains(permissionKey);
}
