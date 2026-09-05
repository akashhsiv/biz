using Erp.Application.Common;
using Erp.Application.Finance;
using Erp.Domain.Common;
using Erp.Domain.Finance;
using Erp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Erp.Infrastructure.Services;

public class FinanceLedgerService(ErpDbContext db, ICurrentUserService currentUser) : IFinanceLedgerService
{
    // Deposit allocation/reversal are bookkeeping against a customer's deposit pool, not new cash
    // movements (the cash arrived when the deposit itself was recorded) — excluded from shop balance.
    private static readonly FinancialTransactionType[] ShopBalanceTypes =
    [
        FinancialTransactionType.AmountIn,
        FinancialTransactionType.AmountOut,
        FinancialTransactionType.Refund,
        FinancialTransactionType.Adjustment,
        FinancialTransactionType.PurchasePayment,
    ];

    public async Task<decimal> GetAvailableDepositAsync(Guid customerId, CancellationToken ct = default)
    {
        var totalDeposits = await db.CustomerDeposits.Where(d => d.CustomerId == customerId).SumAsync(d => (decimal?)d.Amount, ct) ?? 0m;
        var totalAllocated = await db.DepositAllocations
            .Where(a => a.CustomerId == customerId && a.Status == DepositAllocationStatus.Active)
            .SumAsync(a => (decimal?)a.AmountAllocated, ct) ?? 0m;

        return totalDeposits - totalAllocated;
    }

    public Task<Guid> RecordDepositAsync(Guid customerId, decimal amount, string? paymentMethod, string? notes, CancellationToken ct = default)
    {
        if (amount <= 0) throw new ValidationAppException("Deposit amount must be positive.");

        var transaction = new FinancialTransaction
        {
            TransactionType = FinancialTransactionType.AmountIn,
            Direction = FinancialDirection.Credit,
            Amount = amount,
            CustomerId = customerId,
            CreatedBy = currentUser.UserId,
            CreatedAt = DateTime.UtcNow,
        };
        db.FinancialTransactions.Add(transaction);

        var deposit = new CustomerDeposit
        {
            CustomerId = customerId,
            FinancialTransactionId = transaction.Id,
            Amount = amount,
            PaymentMethod = paymentMethod,
            ReceivedBy = currentUser.UserId,
            Notes = notes,
        };
        db.CustomerDeposits.Add(deposit);

        return Task.FromResult(deposit.Id);
    }

    public Task<Guid> CreditDepositAsync(Guid customerId, decimal amount, string paymentMethod, string? notes, CancellationToken ct = default)
    {
        if (amount <= 0) throw new ValidationAppException("Credit amount must be positive.");

        // Modeled as a Refund-type ledger entry so it's distinguishable from a genuine Amount In deposit,
        // while still counting toward the customer's available deposit pool via the CustomerDeposits table.
        var transaction = new FinancialTransaction
        {
            TransactionType = FinancialTransactionType.Refund,
            Direction = FinancialDirection.Credit,
            Amount = amount,
            CustomerId = customerId,
            Reason = notes,
            CreatedBy = currentUser.UserId,
            CreatedAt = DateTime.UtcNow,
        };
        db.FinancialTransactions.Add(transaction);

        var deposit = new CustomerDeposit
        {
            CustomerId = customerId,
            FinancialTransactionId = transaction.Id,
            Amount = amount,
            PaymentMethod = paymentMethod,
            ReceivedBy = currentUser.UserId,
            Notes = notes,
        };
        db.CustomerDeposits.Add(deposit);

        return Task.FromResult(deposit.Id);
    }

    public async Task<Guid> AllocateDepositAsync(Guid customerId, DepositAllocationDocumentType documentType, Guid documentId, decimal amount, CancellationToken ct = default)
    {
        if (amount <= 0) throw new ValidationAppException("Allocation amount must be positive.");

        // Locks the customer row for the rest of the caller's transaction, serializing concurrent
        // allocation attempts against the same customer's deposit pool across Slaves.
        await db.Customers.FromSqlInterpolated($"""SELECT * FROM customers WHERE "Id" = {customerId} FOR UPDATE""").AsTracking().ToListAsync(ct);

        var available = await GetAvailableDepositAsync(customerId, ct);
        if (available < amount)
            throw new ConflictAppException($"Insufficient customer deposit available (available {available:0.00}, requested {amount:0.00}).");

        var allocation = new DepositAllocation
        {
            CustomerId = customerId,
            DocumentType = documentType,
            DocumentId = documentId,
            AmountAllocated = amount,
            Status = DepositAllocationStatus.Active,
        };
        db.DepositAllocations.Add(allocation);

        return allocation.Id;
    }

    public async Task ReverseAllocationAsync(Guid allocationId, string reason, CancellationToken ct = default)
    {
        var allocation = await db.DepositAllocations.FirstOrDefaultAsync(a => a.Id == allocationId, ct)
            ?? throw new NotFoundAppException(nameof(DepositAllocation), allocationId);

        if (allocation.Status == DepositAllocationStatus.Reversed) return;

        allocation.Status = DepositAllocationStatus.Reversed;
        allocation.ReversedAt = DateTime.UtcNow;
        allocation.ReversedReason = reason;
    }

    public Task<Guid> RecordAmountOutAsync(decimal amount, string? reason, DocumentReferenceType? referenceType, Guid? referenceId, CancellationToken ct = default)
    {
        if (amount <= 0) throw new ValidationAppException("Amount must be positive.");

        var transaction = new FinancialTransaction
        {
            TransactionType = FinancialTransactionType.AmountOut,
            Direction = FinancialDirection.Debit,
            Amount = amount,
            ReferenceType = referenceType,
            ReferenceId = referenceId,
            Reason = reason,
            CreatedBy = currentUser.UserId,
            CreatedAt = DateTime.UtcNow,
        };
        db.FinancialTransactions.Add(transaction);

        return Task.FromResult(transaction.Id);
    }

    public Task<Guid> RecordAmountInAsync(decimal amount, string? reason, CancellationToken ct = default)
    {
        if (amount <= 0) throw new ValidationAppException("Amount must be positive.");

        // Deliberately no CustomerId - this is shop-level cash in that never touches any customer's
        // deposit pool (that path is RecordDepositAsync). See PermissionKeys.FinanceAdjustmentsManage.
        var transaction = new FinancialTransaction
        {
            TransactionType = FinancialTransactionType.AmountIn,
            Direction = FinancialDirection.Credit,
            Amount = amount,
            Reason = reason,
            CreatedBy = currentUser.UserId,
            CreatedAt = DateTime.UtcNow,
        };
        db.FinancialTransactions.Add(transaction);

        return Task.FromResult(transaction.Id);
    }

    public Task<Guid> RecordCashRefundAsync(Guid customerId, decimal amount, DocumentReferenceType referenceType, Guid referenceId, CancellationToken ct = default)
    {
        if (amount <= 0) throw new ValidationAppException("Refund amount must be positive.");

        var transaction = new FinancialTransaction
        {
            TransactionType = FinancialTransactionType.Refund,
            Direction = FinancialDirection.Debit,
            Amount = amount,
            CustomerId = customerId,
            ReferenceType = referenceType,
            ReferenceId = referenceId,
            CreatedBy = currentUser.UserId,
            CreatedAt = DateTime.UtcNow,
        };
        db.FinancialTransactions.Add(transaction);

        return Task.FromResult(transaction.Id);
    }

    public Task<Guid> RecordAdjustmentAsync(decimal amount, FinancialDirection direction, string reason, CancellationToken ct = default)
    {
        if (amount <= 0) throw new ValidationAppException("Adjustment amount must be positive.");
        if (string.IsNullOrWhiteSpace(reason)) throw new ValidationAppException("A reason is required for a balance adjustment.");

        var transaction = new FinancialTransaction
        {
            TransactionType = FinancialTransactionType.Adjustment,
            Direction = direction,
            Amount = amount,
            Reason = reason,
            CreatedBy = currentUser.UserId,
            CreatedAt = DateTime.UtcNow,
        };
        db.FinancialTransactions.Add(transaction);

        return Task.FromResult(transaction.Id);
    }

    public async Task<decimal> GetShopBalanceAsync(CancellationToken ct = default)
    {
        var transactions = await db.FinancialTransactions
            .Where(t => ShopBalanceTypes.Contains(t.TransactionType))
            .Select(t => new { t.Amount, t.Direction })
            .ToListAsync(ct);

        return transactions.Sum(t => t.Direction == FinancialDirection.Credit ? t.Amount : -t.Amount);
    }
}
