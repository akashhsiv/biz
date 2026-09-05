namespace Erp.Domain.Identity;

/// <summary>Server-side opaque session token. The primary key is the SHA-256 hash of the token, never the raw token.</summary>
public class Session
{
    public string TokenHash { get; set; } = default!;

    public Guid UserId { get; set; }
    public User User { get; set; } = default!;

    /// <summary>Set when the user selects an active shop after login (POST /api/auth/select-shop).
    /// Null until then — a freshly logged-in session has no shop context yet, and requests get
    /// resolved against the legacy User.RoleId until one is picked.</summary>
    public Guid? ShopId { get; set; }
    public Erp.Domain.Shops.Shop? Shop { get; set; }

    public DateTime CreatedAt { get; set; }
    public DateTime ExpiresAt { get; set; }
    public DateTime? RevokedAt { get; set; }
    public DateTime? LastSeenAt { get; set; }
}
