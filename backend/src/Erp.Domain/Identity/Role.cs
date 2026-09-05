using Erp.Domain.Common;

namespace Erp.Domain.Identity;

public class Role : BaseEntity
{
    public string Name { get; set; } = default!;
    public string? Description { get; set; }
    public bool IsSystemRole { get; set; }

    public ICollection<RolePermission> RolePermissions { get; set; } = new List<RolePermission>();
    public ICollection<User> Users { get; set; } = new List<User>();
}
