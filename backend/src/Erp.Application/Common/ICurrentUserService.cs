namespace Erp.Application.Common;

/// <summary>Resolved server-side from the session token on every request. Never trust role/permission claims supplied by the client — see ARCHITECTURE.md §40.</summary>
public interface ICurrentUserService
{
    bool IsAuthenticated { get; }
    Guid UserId { get; }
    string Username { get; }
    string RoleName { get; }
    IReadOnlySet<string> Permissions { get; }

    bool HasPermission(string permissionKey);
}
