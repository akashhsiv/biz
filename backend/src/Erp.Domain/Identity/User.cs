using Erp.Domain.Common;

namespace Erp.Domain.Identity;

public class User : BaseEntity
{
    public string Username { get; set; } = default!;
    public string PasswordHash { get; set; } = default!;
    public string FullName { get; set; } = default!;
    public bool IsActive { get; set; } = true;
    public DateTime? LastLoginAt { get; set; }

    public Guid RoleId { get; set; }
    public Role Role { get; set; } = default!;

    public ICollection<Session> Sessions { get; set; } = new List<Session>();
}
