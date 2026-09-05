using Erp.Api.Auth;
using Erp.Application.Common;
using Erp.Application.Security;
using Erp.Domain.Commission;
using Erp.Domain.Common;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record CustomerProductRateDto(
    Guid Id, Guid CustomerId, string CustomerName, Guid ItemId, string ItemName,
    decimal? SpecialRate, decimal? CommissionRate, DateTime EffectiveFrom, bool IsActive);

public record UpsertCustomerProductRateRequest(Guid CustomerId, Guid ItemId, decimal? SpecialRate, decimal? CommissionRate, DateTime EffectiveFrom);

public record CommissionEntryDto(
    Guid Id, Guid CustomerId, string CustomerName, Guid SalesInvoiceId, string InvoiceNumber, Guid ItemId, string ItemName,
    decimal Amount, CommissionEntryStatus Status, decimal PaidAmount, DateTime CreatedAt);

public record RecordCommissionPaymentRequest(decimal Amount);

/// <summary>
/// Provisional CRUD/reporting scaffolding for the customer commission module — see
/// Erp.Domain.Commission.CustomerProductRate / CommissionEntry doc comments: the exact business
/// meaning of "commission" is unresolved pending sign-off. This controller only exposes plain
/// CRUD + a simple pay/cancel lifecycle, mirroring SuppliersController and SalaryController.
/// </summary>
[ApiController]
[Route("api/commission")]
public class CommissionController(ErpDbContext db) : ControllerBase
{
    // ---- Customer product rates ----

    [HttpGet("customer-rates")]
    [RequirePermission(PermissionKeys.CommissionView)]
    public async Task<ActionResult<List<CustomerProductRateDto>>> ListRates(
        [FromQuery] Guid? customerId, [FromQuery] bool includeInactive, CancellationToken ct)
    {
        var query = db.CustomerProductRates.Include(r => r.Customer).Include(r => r.Item).AsQueryable();
        if (customerId is { } cid) query = query.Where(r => r.CustomerId == cid);
        if (!includeInactive) query = query.Where(r => r.IsActive);

        var rates = await query.OrderByDescending(r => r.EffectiveFrom).ToListAsync(ct);
        return Ok(rates.Select(ToDto));
    }

    [HttpPost("customer-rates")]
    [RequirePermission(PermissionKeys.CommissionManage)]
    public async Task<ActionResult<CustomerProductRateDto>> CreateRate(UpsertCustomerProductRateRequest request, CancellationToken ct)
    {
        var customer = await db.Customers.FirstOrDefaultAsync(c => c.Id == request.CustomerId, ct)
            ?? throw new NotFoundAppException(nameof(Erp.Domain.Customers.Customer), request.CustomerId);
        var item = await db.Items.FirstOrDefaultAsync(i => i.Id == request.ItemId, ct)
            ?? throw new NotFoundAppException(nameof(Erp.Domain.Items.Item), request.ItemId);

        if (request.SpecialRate is < 0) throw new ValidationAppException("SpecialRate cannot be negative.");
        if (request.CommissionRate is < 0) throw new ValidationAppException("CommissionRate cannot be negative.");

        var rate = new CustomerProductRate
        {
            CustomerId = customer.Id,
            ItemId = item.Id,
            SpecialRate = request.SpecialRate,
            CommissionRate = request.CommissionRate,
            EffectiveFrom = request.EffectiveFrom,
            IsActive = true,
        };
        db.CustomerProductRates.Add(rate);
        await db.SaveChangesAsync(ct);

        rate.Customer = customer;
        rate.Item = item;
        return Ok(ToDto(rate));
    }

    [HttpPut("customer-rates/{id:guid}")]
    [RequirePermission(PermissionKeys.CommissionManage)]
    public async Task<ActionResult<CustomerProductRateDto>> UpdateRate(Guid id, UpsertCustomerProductRateRequest request, CancellationToken ct)
    {
        var rate = await db.CustomerProductRates.Include(r => r.Customer).Include(r => r.Item)
            .FirstOrDefaultAsync(r => r.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(CustomerProductRate), id);

        if (request.SpecialRate is < 0) throw new ValidationAppException("SpecialRate cannot be negative.");
        if (request.CommissionRate is < 0) throw new ValidationAppException("CommissionRate cannot be negative.");

        if (rate.CustomerId != request.CustomerId)
        {
            var customer = await db.Customers.FirstOrDefaultAsync(c => c.Id == request.CustomerId, ct)
                ?? throw new NotFoundAppException(nameof(Erp.Domain.Customers.Customer), request.CustomerId);
            rate.CustomerId = customer.Id;
            rate.Customer = customer;
        }

        if (rate.ItemId != request.ItemId)
        {
            var item = await db.Items.FirstOrDefaultAsync(i => i.Id == request.ItemId, ct)
                ?? throw new NotFoundAppException(nameof(Erp.Domain.Items.Item), request.ItemId);
            rate.ItemId = item.Id;
            rate.Item = item;
        }

        rate.SpecialRate = request.SpecialRate;
        rate.CommissionRate = request.CommissionRate;
        rate.EffectiveFrom = request.EffectiveFrom;

        await db.SaveChangesAsync(ct);
        return Ok(ToDto(rate));
    }

    [HttpPost("customer-rates/{id:guid}/deactivate")]
    [RequirePermission(PermissionKeys.CommissionManage)]
    public async Task<IActionResult> DeactivateRate(Guid id, CancellationToken ct)
    {
        var rate = await db.CustomerProductRates.FirstOrDefaultAsync(r => r.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(CustomerProductRate), id);

        rate.IsActive = false;
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    // ---- Commission entries ----

    [HttpGet("entries")]
    [RequirePermission(PermissionKeys.CommissionView)]
    public async Task<ActionResult<List<CommissionEntryDto>>> ListEntries(
        [FromQuery] Guid? customerId, [FromQuery] CommissionEntryStatus? status,
        [FromQuery] DateTime? fromDate, [FromQuery] DateTime? toDate, CancellationToken ct)
    {
        var query = db.CommissionEntries.Include(e => e.Customer).Include(e => e.SalesInvoice).Include(e => e.Item).AsQueryable();
        if (customerId is { } cid) query = query.Where(e => e.CustomerId == cid);
        if (status is { } s) query = query.Where(e => e.Status == s);
        if (fromDate is { } from) query = query.Where(e => e.CreatedAt >= from);
        if (toDate is { } to) query = query.Where(e => e.CreatedAt <= to);

        var entries = await query.OrderByDescending(e => e.CreatedAt).ToListAsync(ct);
        return Ok(entries.Select(ToDto));
    }

    [HttpGet("entries/{id:guid}")]
    [RequirePermission(PermissionKeys.CommissionView)]
    public async Task<ActionResult<CommissionEntryDto>> GetEntry(Guid id, CancellationToken ct)
    {
        var entry = await db.CommissionEntries.Include(e => e.Customer).Include(e => e.SalesInvoice).Include(e => e.Item)
            .FirstOrDefaultAsync(e => e.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(CommissionEntry), id);

        return Ok(ToDto(entry));
    }

    /// <summary>Simple "add amount, update status" pattern, mirroring SalaryController.RecordPayment.</summary>
    [HttpPost("entries/{id:guid}/pay")]
    [RequirePermission(PermissionKeys.CommissionManage)]
    public async Task<ActionResult<CommissionEntryDto>> Pay(Guid id, RecordCommissionPaymentRequest request, CancellationToken ct)
    {
        if (request.Amount <= 0) throw new ValidationAppException("Payment amount must be positive.");

        var entry = await db.CommissionEntries.Include(e => e.Customer).Include(e => e.SalesInvoice).Include(e => e.Item)
            .FirstOrDefaultAsync(e => e.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(CommissionEntry), id);

        if (entry.Status is CommissionEntryStatus.Paid or CommissionEntryStatus.Cancelled)
            throw new ConflictAppException($"This commission entry is {entry.Status} and cannot receive a payment.");

        var pending = entry.Amount - entry.PaidAmount;
        if (request.Amount > pending)
            throw new ValidationAppException($"Payment amount ({request.Amount}) exceeds pending amount ({pending}).");

        entry.PaidAmount += request.Amount;
        entry.Status = entry.PaidAmount >= entry.Amount ? CommissionEntryStatus.Paid : CommissionEntryStatus.PartiallyPaid;

        await db.SaveChangesAsync(ct);
        return Ok(ToDto(entry));
    }

    [HttpPost("entries/{id:guid}/cancel")]
    [RequirePermission(PermissionKeys.CommissionManage)]
    public async Task<IActionResult> Cancel(Guid id, CancellationToken ct)
    {
        var entry = await db.CommissionEntries.FirstOrDefaultAsync(e => e.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(CommissionEntry), id);

        if (entry.Status == CommissionEntryStatus.Paid)
            throw new ConflictAppException("A fully paid commission entry cannot be cancelled.");

        entry.Status = CommissionEntryStatus.Cancelled;
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    private static CustomerProductRateDto ToDto(CustomerProductRate r) => new(
        r.Id, r.CustomerId, r.Customer.Name, r.ItemId, r.Item.Name, r.SpecialRate, r.CommissionRate, r.EffectiveFrom, r.IsActive);

    private static CommissionEntryDto ToDto(CommissionEntry e) => new(
        e.Id, e.CustomerId, e.Customer.Name, e.SalesInvoiceId, e.SalesInvoice.InvoiceNumber, e.ItemId, e.Item.Name,
        e.Amount, e.Status, e.PaidAmount, e.CreatedAt);
}
