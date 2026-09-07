namespace Erp.Application.Auth;

public record LoginRequest(string Username, string Password);

public record LoginResult(string Token, DateTime ExpiresAt, Guid UserId, string Username, string FullName, string RoleName, IReadOnlyList<string> Permissions, bool IsSuperAdmin);

/// <summary>Returned by POST /api/auth/select-shop. The client re-derives its effective role/permissions
/// for the shop it just picked; the bearer token itself doesn't change.</summary>
public record SelectShopResult(Guid ShopId, string RoleName, IReadOnlyList<string> Permissions);

public record ShopSummaryDto(Guid Id, string Name, string Gstin, bool IsActive);

public interface IAuthService
{
    Task<LoginResult> LoginAsync(string username, string password, CancellationToken ct = default);
    Task LogoutAsync(string tokenHash, CancellationToken ct = default);
    Task<SelectShopResult> SelectShopAsync(Guid userId, string tokenHash, Guid shopId, CancellationToken ct = default);
    Task<IReadOnlyList<ShopSummaryDto>> GetAccessibleShopsAsync(Guid userId, CancellationToken ct = default);
}
