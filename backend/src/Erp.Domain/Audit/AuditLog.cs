namespace Erp.Domain.Audit;

/// <summary>Append-only. No update/delete path is ever exposed anywhere in the application.
///
/// ShopId is deliberately nullable and AuditLog does NOT implement IShopScoped (unlike the other
/// entities touched by the multi-shop rework): some audited actions genuinely have no shop yet
/// (user.login/user.logout happen before a session selects a shop), and an audit trail an Admin can
/// review across every shop they have access to is more useful than one silently filtered to
/// "whichever shop happens to be active right now". Set it when the action is shop-scoped, leave it
/// null otherwise.</summary>
public class AuditLog
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid? ShopId { get; set; }
    public Erp.Domain.Shops.Shop? Shop { get; set; }

    public Guid UserId { get; set; }
    public string RoleAtTime { get; set; } = default!;

    /// <summary>e.g. "quotation.converted", "amount_in.created" — a stable dotted action key, not a free-text sentence.</summary>
    public string Action { get; set; } = default!;

    public string EntityType { get; set; } = default!;
    public Guid EntityId { get; set; }

    public string? OldValueJson { get; set; }
    public string? NewValueJson { get; set; }
    public string? Reason { get; set; }

    public DateTime CreatedAt { get; set; }
}
