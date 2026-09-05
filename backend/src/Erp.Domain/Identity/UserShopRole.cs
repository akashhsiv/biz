using Erp.Domain.Common;
using Erp.Domain.Shops;

namespace Erp.Domain.Identity;

/// <summary>Grants a User a Role within one specific Shop. This replaces User.RoleId as the source of
/// truth for "what can this user do" — a user's role is only meaningful per-shop now, since the same
/// person can be Sales Team in one shop and Shop Admin in another. User.RoleId/User.Role are kept
/// (not dropped) purely as a migration-era fallback: see the comment on User.RoleId.</summary>
public class UserShopRole : BaseEntity
{
    public Guid UserId { get; set; }
    public User User { get; set; } = default!;

    public Guid ShopId { get; set; }
    public Shop Shop { get; set; } = default!;

    public Guid RoleId { get; set; }
    public Role Role { get; set; } = default!;
}
