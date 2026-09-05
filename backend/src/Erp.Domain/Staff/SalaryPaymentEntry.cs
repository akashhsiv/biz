using Erp.Domain.Common;

namespace Erp.Domain.Staff;

/// <summary>Payment ledger line against a SalaryPayment — mirrors PurchasePayment's role against
/// PurchaseOrder, but applied immediately (no Processing/Completed two-step) since a salary payout
/// has no separate approval workflow in this codebase; see SalaryController for the decision note.</summary>
public class SalaryPaymentEntry : BaseEntity
{
    public Guid SalaryPaymentId { get; set; }
    public SalaryPayment SalaryPayment { get; set; } = default!;

    public decimal Amount { get; set; }
    public string? PaymentMethod { get; set; }
    public Guid PaidBy { get; set; }
    public DateTime PaidAt { get; set; }
    public string? Notes { get; set; }
}
