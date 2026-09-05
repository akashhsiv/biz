namespace Erp.Domain.Identity;

/// <summary>Server-side opaque session token. The primary key is the SHA-256 hash of the token, never the raw token.</summary>
public class Session
{
    public string TokenHash { get; set; } = default!;

    public Guid UserId { get; set; }
    public User User { get; set; } = default!;

    public DateTime CreatedAt { get; set; }
    public DateTime ExpiresAt { get; set; }
    public DateTime? RevokedAt { get; set; }
    public DateTime? LastSeenAt { get; set; }
}
