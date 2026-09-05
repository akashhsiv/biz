namespace Erp.Application.Auth;

public record LoginRequest(string Username, string Password);

public record LoginResult(string Token, DateTime ExpiresAt, Guid UserId, string Username, string FullName, string RoleName, IReadOnlyList<string> Permissions);

public interface IAuthService
{
    Task<LoginResult> LoginAsync(string username, string password, CancellationToken ct = default);
    Task LogoutAsync(string tokenHash, CancellationToken ct = default);
}
