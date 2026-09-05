using Erp.Domain.Common;

namespace Erp.Domain.Identity;

public class Permission : BaseEntity
{
    public string Key { get; set; } = default!;
    public string Module { get; set; } = default!;
    public string? Description { get; set; }

    public ICollection<RolePermission> RolePermissions { get; set; } = new List<RolePermission>();
}
