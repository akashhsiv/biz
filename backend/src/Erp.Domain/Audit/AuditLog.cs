namespace Erp.Domain.Audit;

/// <summary>Append-only. No update/delete path is ever exposed anywhere in the application.</summary>
public class AuditLog
{
    public Guid Id { get; set; } = Guid.NewGuid();

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
