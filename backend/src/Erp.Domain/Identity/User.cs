using Erp.Domain.Common;

namespace Erp.Domain.Identity;

public class User : BaseEntity
{
    public string Username { get; set; } = default!;
    public string PasswordHash { get; set; } = default!;
    public string FullName { get; set; } = default!;
    public bool IsActive { get; set; } = true;
    public DateTime? LastLoginAt { get; set; }

    /// <summary>Deprecated by the multi-shop rework — a user's role is now resolved per-shop via
    /// UserShopRole. Kept (not dropped) only as a migration-era fallback for sessions/code paths that
    /// haven't gone through shop selection yet; do not read this for authorization decisions in new
    /// code, use UserShopRole for the relevant ShopId instead.</summary>
    public Guid RoleId { get; set; }
    public Role Role { get; set; } = default!;

    public ICollection<Session> Sessions { get; set; } = new List<Session>();
    public ICollection<UserShopRole> UserShopRoles { get; set; } = new List<UserShopRole>();
}
