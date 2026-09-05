using Erp.Domain.Common;

namespace Erp.Domain.Finance;

/// <summary>One row per recorded business expense (rent, electricity, salaries, ...). Always paired
/// with a debit FinancialTransaction (TransactionType.AmountOut) — same pattern as CustomerDeposit
/// pairing with a credit one — so it shows up in the existing Finance transaction list and shop
/// balance with no separate plumbing.</summary>
public class Expense : BaseEntity
{
    public string Category { get; set; } = default!;
    public decimal Amount { get; set; }
    public string Reason { get; set; } = default!;
    public string? PaymentMethod { get; set; }

    public Guid FinancialTransactionId { get; set; }
    public FinancialTransaction FinancialTransaction { get; set; } = default!;
}
