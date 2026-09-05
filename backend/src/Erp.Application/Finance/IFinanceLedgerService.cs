using Erp.Domain.Common;

namespace Erp.Application.Finance;

/// <summary>
/// The append-only financial ledger — see ARCHITECTURE.md §17/§18/§28. Every method assumes it
/// runs inside a transaction the caller already opened; none of these commit.
/// </summary>
public interface IFinanceLedgerService
{
    /// <summary>SUM(CustomerDeposit) - SUM(active DepositAllocation) for this customer.</summary>
    Task<decimal> GetAvailableDepositAsync(Guid customerId, CancellationToken ct = default);

    /// <summary>Records an Amount In deposit event. Always creates a matching credit FinancialTransaction.</summary>
    Task<Guid> RecordDepositAsync(Guid customerId, decimal amount, string? paymentMethod, string? notes, CancellationToken ct = default);

    /// <summary>Allocates from the customer's available deposit pool to a document. Throws ConflictAppException if insufficient (locks the customer row for the duration of the caller's transaction to serialize concurrent allocations).</summary>
    Task<Guid> AllocateDepositAsync(Guid customerId, DepositAllocationDocumentType documentType, Guid documentId, decimal amount, CancellationToken ct = default);

    /// <summary>Reverses an active allocation, returning that amount to the customer's available pool. The original allocation row is never edited.</summary>
    Task ReverseAllocationAsync(Guid allocationId, string reason, CancellationToken ct = default);

    /// <summary>Grants deposit-equivalent credit to a customer without a cash deposit event (e.g. a return refunded as store credit).</summary>
    Task<Guid> CreditDepositAsync(Guid customerId, decimal amount, string paymentMethod, string? notes, CancellationToken ct = default);

    /// <summary>Records a general Amount Out expense/payment. Always creates a matching debit FinancialTransaction.</summary>
    Task<Guid> RecordAmountOutAsync(decimal amount, string? reason, DocumentReferenceType? referenceType, Guid? referenceId, CancellationToken ct = default);

    /// <summary>Records a general Amount In cash receipt that isn't a customer deposit (e.g. misc/other
    /// income) — a shop-level credit with no CustomerId. Always creates a matching credit FinancialTransaction.</summary>
    Task<Guid> RecordAmountInAsync(decimal amount, string? reason, CancellationToken ct = default);

    /// <summary>Records a cash refund paid out (Amount Out variant tagged Refund).</summary>
    Task<Guid> RecordCashRefundAsync(Guid customerId, decimal amount, DocumentReferenceType referenceType, Guid referenceId, CancellationToken ct = default);

    /// <summary>Derived from summing the ledger — never a manually-editable field.</summary>
    Task<decimal> GetShopBalanceAsync(CancellationToken ct = default);

    /// <summary>Records a manual correction (e.g. reconciling the computed shop balance against the
    /// real bank/cash balance). Reason is required — same convention as every other Adjustment row.</summary>
    Task<Guid> RecordAdjustmentAsync(decimal amount, FinancialDirection direction, string reason, CancellationToken ct = default);
}
