using System.Text.Json;
using Erp.Api.Auth;
using Erp.Api.Common;
using Erp.Application.Common;
using Erp.Application.Finance;
using Erp.Application.Security;
using Erp.Domain.Common;
using Erp.Domain.Finance;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record RecordAmountOutRequest(decimal Amount, string Reason);
public record RecordAmountInRequest(decimal Amount, string Reason);
public record SetBalanceRequest(decimal TargetBalance, string Reason);
public record SetBalanceResultDto(decimal PreviousBalance, decimal NewBalance, decimal Delta);
public record FinancialTransactionDto(Guid Id, FinancialTransactionType TransactionType, FinancialDirection Direction, decimal Amount, Guid? CustomerId, string? Reason, DateTime CreatedAt);
public record ShopBalanceDto(decimal Balance);

[ApiController]
[Route("api")]
public class FinanceController(ErpDbContext db, IFinanceLedgerService ledger, IAuditService audit, IIdempotencyService idempotency) : ControllerBase
{
    [HttpPost("amount-out")]
    [RequirePermission(PermissionKeys.FinanceAmountOutManage)]
    public async Task<ActionResult<FinancialTransactionDto>> RecordAmountOut(RecordAmountOutRequest request, CancellationToken ct)
    {
        const string endpoint = "POST /api/amount-out";
        var key = IdempotencyGuard.RequireKey(Request);
        var hash = IdempotencyGuard.HashRequest(request);

        var replay = await idempotency.FindReplayAsync(key, endpoint, hash, ct);
        if (replay is not null)
            return new ContentResult { StatusCode = replay.StatusCode, Content = replay.ResponseBodyJson, ContentType = "application/json" };

        if (string.IsNullOrWhiteSpace(request.Reason))
            throw new ValidationAppException("A reason is required for an Amount Out entry.");

        await using var tx = await db.Database.BeginTransactionAsync(ct);

        var transactionId = await ledger.RecordAmountOutAsync(request.Amount, request.Reason, null, null, ct);
        await audit.LogAsync("amount_out.created", nameof(FinancialTransaction), transactionId, newValue: request, ct: ct);

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        var transaction = await db.FinancialTransactions.AsNoTracking().FirstAsync(t => t.Id == transactionId, ct);
        var dto = ToDto(transaction);

        await idempotency.StoreAsync(key, endpoint, hash, StatusCodes.Status200OK, IdempotencyGuard.SerializeResponse(dto), ct);
        return Ok(dto);
    }

    [HttpPost("amount-in")]
    [RequirePermission(PermissionKeys.FinanceAmountOutManage)]
    public async Task<ActionResult<FinancialTransactionDto>> RecordAmountIn(RecordAmountInRequest request, CancellationToken ct)
    {
        const string endpoint = "POST /api/amount-in";
        var key = IdempotencyGuard.RequireKey(Request);
        var hash = IdempotencyGuard.HashRequest(request);

        var replay = await idempotency.FindReplayAsync(key, endpoint, hash, ct);
        if (replay is not null)
            return new ContentResult { StatusCode = replay.StatusCode, Content = replay.ResponseBodyJson, ContentType = "application/json" };

        if (string.IsNullOrWhiteSpace(request.Reason))
            throw new ValidationAppException("A reason is required for an Amount In entry.");

        await using var tx = await db.Database.BeginTransactionAsync(ct);

        var transactionId = await ledger.RecordAmountInAsync(request.Amount, request.Reason, ct);
        await audit.LogAsync("amount_in.created", nameof(FinancialTransaction), transactionId, newValue: request, ct: ct);

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        var transaction = await db.FinancialTransactions.AsNoTracking().FirstAsync(t => t.Id == transactionId, ct);
        var dto = ToDto(transaction);

        await idempotency.StoreAsync(key, endpoint, hash, StatusCodes.Status200OK, IdempotencyGuard.SerializeResponse(dto), ct);
        return Ok(dto);
    }

    /// <summary>Lets the Shop Admin reconcile the computed shop balance against the real-world
    /// bank/cash balance — not a directly-editable balance field (the ledger never has one), just a
    /// convenience that posts a single Adjustment transaction for the difference.</summary>
    [HttpPost("finance/set-balance")]
    [RequirePermission(PermissionKeys.FinanceAdjustmentsManage)]
    public async Task<ActionResult<SetBalanceResultDto>> SetBalance(SetBalanceRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Reason))
            throw new ValidationAppException("A reason is required to adjust the balance.");

        await using var tx = await db.Database.BeginTransactionAsync(ct);

        var current = await ledger.GetShopBalanceAsync(ct);
        var delta = request.TargetBalance - current;

        if (delta == 0)
            throw new ConflictAppException($"Balance is already ₹{current:0.00} — nothing to adjust.");

        var transactionId = await ledger.RecordAdjustmentAsync(Math.Abs(delta), delta > 0 ? FinancialDirection.Credit : FinancialDirection.Debit, request.Reason, ct);
        await audit.LogAsync("finance.balance_adjusted", nameof(FinancialTransaction), transactionId, newValue: new { PreviousBalance = current, request.TargetBalance, Delta = delta }, ct: ct);

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        return Ok(new SetBalanceResultDto(current, request.TargetBalance, delta));
    }

    [HttpGet("finance/shop-balance")]
    [RequirePermission(PermissionKeys.FinanceShopBalanceView)]
    public async Task<ActionResult<ShopBalanceDto>> ShopBalance(CancellationToken ct) =>
        Ok(new ShopBalanceDto(await ledger.GetShopBalanceAsync(ct)));

    [HttpGet("finance/transactions")]
    [RequirePermission(PermissionKeys.FinanceShopBalanceView)]
    public async Task<ActionResult<List<FinancialTransactionDto>>> Transactions([FromQuery] Guid? customerId, [FromQuery] int take = 200, CancellationToken ct = default)
    {
        var query = db.FinancialTransactions.AsQueryable();
        if (customerId is { } id) query = query.Where(t => t.CustomerId == id);

        var transactions = await query.OrderByDescending(t => t.CreatedAt).Take(Math.Clamp(take, 1, 1000)).ToListAsync(ct);
        return Ok(transactions.Select(ToDto));
    }

    private static FinancialTransactionDto ToDto(FinancialTransaction t) =>
        new(t.Id, t.TransactionType, t.Direction, t.Amount, t.CustomerId, t.Reason, t.CreatedAt);
}
