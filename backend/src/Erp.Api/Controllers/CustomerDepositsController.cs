using System.Text.Json;
using Erp.Api.Auth;
using Erp.Api.Common;
using Erp.Application.Common;
using Erp.Application.Finance;
using Erp.Application.Security;
using Erp.Domain.Customers;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record RecordDepositRequest(Guid CustomerId, decimal Amount, string? PaymentMethod, string? Notes);
public record DepositDto(Guid Id, Guid CustomerId, decimal Amount, string? PaymentMethod, string? Notes, DateTime CreatedAt);
public record DepositSummaryDto(Guid CustomerId, decimal TotalDeposited, decimal TotalAllocated, decimal Available);

[ApiController]
[Route("api/customer-deposits")]
public class CustomerDepositsController(ErpDbContext db, IFinanceLedgerService ledger, IAuditService audit, IIdempotencyService idempotency) : ControllerBase
{
    [HttpGet]
    [RequirePermission(PermissionKeys.CustomerDepositsRecord)]
    public async Task<ActionResult<List<DepositDto>>> List([FromQuery] Guid? customerId, CancellationToken ct)
    {
        var query = db.CustomerDeposits.AsQueryable();
        if (customerId is { } id) query = query.Where(d => d.CustomerId == id);

        var deposits = await query.OrderByDescending(d => d.CreatedAt)
            .Select(d => new DepositDto(d.Id, d.CustomerId, d.Amount, d.PaymentMethod, d.Notes, d.CreatedAt))
            .ToListAsync(ct);

        return Ok(deposits);
    }

    [HttpPost]
    [RequirePermission(PermissionKeys.CustomerDepositsRecord)]
    public async Task<ActionResult<DepositDto>> Record(RecordDepositRequest request, CancellationToken ct)
    {
        const string endpoint = "POST /api/customer-deposits";
        var key = IdempotencyGuard.RequireKey(Request);
        var hash = IdempotencyGuard.HashRequest(request);

        var replay = await idempotency.FindReplayAsync(key, endpoint, hash, ct);
        if (replay is not null)
            return new ContentResult { StatusCode = replay.StatusCode, Content = replay.ResponseBodyJson, ContentType = "application/json" };

        if (!await db.Customers.AnyAsync(c => c.Id == request.CustomerId && c.IsActive, ct))
            throw new NotFoundAppException(nameof(Customer), request.CustomerId);

        await using var tx = await db.Database.BeginTransactionAsync(ct);

        var depositId = await ledger.RecordDepositAsync(request.CustomerId, request.Amount, request.PaymentMethod, request.Notes, ct);
        await audit.LogAsync("amount_in.created", nameof(Erp.Domain.Finance.CustomerDeposit), depositId,
            newValue: new { request.CustomerId, request.Amount, request.PaymentMethod }, ct: ct);

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        var deposit = await db.CustomerDeposits.FirstAsync(d => d.Id == depositId, ct);
        var dto = new DepositDto(deposit.Id, deposit.CustomerId, deposit.Amount, deposit.PaymentMethod, deposit.Notes, deposit.CreatedAt);

        await idempotency.StoreAsync(key, endpoint, hash, StatusCodes.Status200OK, IdempotencyGuard.SerializeResponse(dto), ct);
        return Ok(dto);
    }

    [HttpGet("/api/customers/{customerId:guid}/deposit-summary")]
    [RequirePermission(PermissionKeys.CustomerDepositsRecord)]
    public async Task<ActionResult<DepositSummaryDto>> Summary(Guid customerId, CancellationToken ct)
    {
        if (!await db.Customers.AnyAsync(c => c.Id == customerId, ct))
            throw new NotFoundAppException(nameof(Customer), customerId);

        var totalDeposited = await db.CustomerDeposits.Where(d => d.CustomerId == customerId).SumAsync(d => (decimal?)d.Amount, ct) ?? 0m;
        var available = await ledger.GetAvailableDepositAsync(customerId, ct);

        return Ok(new DepositSummaryDto(customerId, totalDeposited, totalDeposited - available, available));
    }
}
