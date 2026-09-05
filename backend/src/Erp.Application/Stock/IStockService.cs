using Erp.Domain.Common;

namespace Erp.Application.Stock;

/// <summary>
/// Every method here assumes it is called inside a transaction the caller already opened
/// (db.Database.BeginTransactionAsync) — see ARCHITECTURE.md §22/§32/§12. None of these
/// methods commit; the caller commits once, alongside the rest of the business operation.
/// </summary>
public interface IStockService
{
    /// <summary>Negative stock is never allowed (confirmed rule). Throws ConflictAppException if insufficient quantity is available.
    /// For a serial-tracked item, <paramref name="serialIds"/> overrides the default FIFO (oldest-received-first)
    /// pick with the caller's exact chosen units — count must equal quantity. Null/empty falls back to FIFO.</summary>
    Task DecrementAsync(Guid itemId, decimal quantity, DocumentReferenceType referenceType, Guid referenceId, string? reason = null, List<Guid>? serialIds = null, CancellationToken ct = default);

    /// <summary>Increases stock. For a batch-tracked item, either creates a new batch (purchase receipts) or tops up an existing one (batchId supplied, e.g. restocking a return into its original batch).
    /// For a serial-tracked item, either creates one ItemSerial per entry in newSerialNumbers (purchase receipts — count must equal quantity) or restores existingSerialIds (e.g. reversing a sale).</summary>
    Task<Guid?> IncrementAsync(Guid itemId, decimal quantity, DocumentReferenceType referenceType, Guid referenceId,
        string? reason = null, string? newBatchNumber = null, DateTime? expiryDate = null, Guid? existingBatchId = null,
        List<string>? newSerialNumbers = null, List<Guid>? existingSerialIds = null, CancellationToken ct = default);

    /// <summary>Creates a reversal movement that undoes a prior movement (restores if it was a decrement, removes if it was an increment) — the original row is never edited.</summary>
    Task ReverseAsync(Guid originalMovementId, string reason, CancellationToken ct = default);
}
