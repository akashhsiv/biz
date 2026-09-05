namespace Erp.Application.Common;

/// <summary>Resolved server-side from the session token on every request. Never trust role/permission claims supplied by the client — see ARCHITECTURE.md §40.</summary>
public interface ICurrentUserService
{
    bool IsAuthenticated { get; }
    Guid UserId { get; }
    string Username { get; }
    string RoleName { get; }
    IReadOnlySet<string> Permissions { get; }

    /// <summary>The shop the current session has selected (POST /api/auth/select-shop), resolved from
    /// the session/JWT claim. Null until a shop is selected — callers that require a shop (document
    /// numbering, most writes once the query filter is enforced) should treat null as "no shop chosen
    /// yet" and fail with a clear error rather than silently operating unscoped.</summary>
    Guid? CurrentShopId { get; }

    bool HasPermission(string permissionKey);
}
