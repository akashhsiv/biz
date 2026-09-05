using Erp.Domain.Common;
using Erp.Domain.Customers;

namespace Erp.Domain.Finance;

/// <summary>Single append-only ledger row for every rupee that moves. Shop balance and customer deposit balance are always derived by summing this table, never stored as an independently-editable field.</summary>
public class FinancialTransaction
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public FinancialTransactionType TransactionType { get; set; }
    public FinancialDirection Direction { get; set; }
    public decimal Amount { get; set; }

    public Guid? CustomerId { get; set; }
    public Customer? Customer { get; set; }

    public Guid? SupplierId { get; set; }

    public DocumentReferenceType? ReferenceType { get; set; }
    public Guid? ReferenceId { get; set; }

    /// <summary>Required when TransactionType is Adjustment, Refund, or a reversal.</summary>
    public string? Reason { get; set; }

    /// <summary>Self-reference: a correction is a new row pointing back at the transaction it reverses. The original row is never edited.</summary>
    public Guid? IsReversalOf { get; set; }

    public Guid CreatedBy { get; set; }
    public DateTime CreatedAt { get; set; }
}
