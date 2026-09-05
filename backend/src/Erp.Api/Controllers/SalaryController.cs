using Erp.Api.Auth;
using Erp.Application.Common;
using Erp.Application.Security;
using Erp.Domain.Common;
using Erp.Domain.Staff;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record GenerateSalaryRequest(Guid StaffId, int PeriodMonth, int PeriodYear);

public record SalaryPaymentEntryDto(Guid Id, decimal Amount, string? PaymentMethod, Guid PaidBy, DateTime PaidAt, string? Notes);

public record SalaryPaymentDto(
    Guid Id, Guid StaffId, string StaffName, int PeriodMonth, int PeriodYear,
    decimal BasicSalary, decimal Allowance, decimal Deduction, decimal NetSalary,
    decimal PaidAmount, decimal PendingAmount, SalaryPaymentStatus Status,
    List<SalaryPaymentEntryDto> Entries);

public record RecordSalaryPaymentRequest(decimal Amount, string? PaymentMethod, string? Notes);

/// <summary>Route nested under api/staff/{staffId}/salary, mirroring how PurchaseOrdersController
/// nests its /payments sub-route under a parent aggregate (api/purchase-orders/{id}/payments).</summary>
[ApiController]
[Route("api/staff/{staffId:guid}/salary")]
public class SalaryController(ErpDbContext db, ICurrentUserService currentUser) : ControllerBase
{
    [HttpGet]
    [RequirePermission(PermissionKeys.StaffSalaryView)]
    public async Task<ActionResult<List<SalaryPaymentDto>>> List(
        Guid staffId, [FromQuery] int? month, [FromQuery] int? year, [FromQuery] SalaryPaymentStatus? status, CancellationToken ct)
    {
        var query = db.SalaryPayments.Include(p => p.Staff).Include(p => p.Entries).Where(p => p.StaffId == staffId);
        if (month is { } m) query = query.Where(p => p.PeriodMonth == m);
        if (year is { } y) query = query.Where(p => p.PeriodYear == y);
        if (status is { } s) query = query.Where(p => p.Status == s);

        var records = await query.OrderByDescending(p => p.PeriodYear).ThenByDescending(p => p.PeriodMonth).ToListAsync(ct);
        return Ok(records.Select(ToDto));
    }

    [HttpGet("{id:guid}")]
    [RequirePermission(PermissionKeys.StaffSalaryView)]
    public async Task<ActionResult<SalaryPaymentDto>> Get(Guid staffId, Guid id, CancellationToken ct)
    {
        var record = await db.SalaryPayments.Include(p => p.Staff).Include(p => p.Entries)
            .FirstOrDefaultAsync(p => p.Id == id && p.StaffId == staffId, ct)
            ?? throw new NotFoundAppException(nameof(SalaryPayment), id);

        return Ok(ToDto(record));
    }

    /// <summary>Generates the salary record for staffId+month+year, SNAPSHOTTING Staff's current
    /// Basic/Allowances/Deductions into the new row. Once created, editing Staff's rates never
    /// changes this record — see the doc comment on SalaryPayment and on StaffController.Update.</summary>
    [HttpPost]
    [RequirePermission(PermissionKeys.StaffSalaryPay)]
    public async Task<ActionResult<SalaryPaymentDto>> Generate(Guid staffId, GenerateSalaryRequest request, CancellationToken ct)
    {
        if (request.PeriodMonth is < 1 or > 12) throw new ValidationAppException("PeriodMonth must be between 1 and 12.");

        var staff = await db.Staff.FirstOrDefaultAsync(s => s.Id == staffId, ct)
            ?? throw new NotFoundAppException(nameof(Staff), staffId);

        var exists = await db.SalaryPayments.AnyAsync(
            p => p.StaffId == staffId && p.PeriodMonth == request.PeriodMonth && p.PeriodYear == request.PeriodYear, ct);
        if (exists) throw new ConflictAppException("A salary record already exists for this staff member for the given month/year.");

        var basic = staff.BasicSalary;
        var allowance = staff.Allowances;
        var deduction = staff.Deductions;
        var net = basic + allowance - deduction;

        var record = new SalaryPayment
        {
            StaffId = staff.Id,
            PeriodMonth = request.PeriodMonth,
            PeriodYear = request.PeriodYear,
            BasicSalary = basic,
            Allowance = allowance,
            Deduction = deduction,
            NetSalary = net,
            PaidAmount = 0,
            PendingAmount = net,
            Status = SalaryPaymentStatus.Pending,
        };

        db.SalaryPayments.Add(record);
        await db.SaveChangesAsync(ct);

        record.Staff = staff;
        return Ok(ToDto(record));
    }

    /// <summary>Records a (partial or full) salary payment. Unlike PurchasePayment, there is no
    /// separate /complete step here: a purchase payment is held Processing until a Finance ledger
    /// entry (Amount Out) is separately approved/completed, but a salary payout in this codebase has
    /// no such downstream approval workflow to wait on, so the entry is applied immediately and
    /// PaidAmount/PendingAmount/Status are updated in the same request.</summary>
    [HttpPost("{id:guid}/payments")]
    [RequirePermission(PermissionKeys.StaffSalaryPay)]
    public async Task<ActionResult<SalaryPaymentDto>> RecordPayment(Guid staffId, Guid id, RecordSalaryPaymentRequest request, CancellationToken ct)
    {
        if (request.Amount <= 0) throw new ValidationAppException("Payment amount must be positive.");

        var record = await db.SalaryPayments.Include(p => p.Staff).Include(p => p.Entries)
            .FirstOrDefaultAsync(p => p.Id == id && p.StaffId == staffId, ct)
            ?? throw new NotFoundAppException(nameof(SalaryPayment), id);

        if (record.Status == SalaryPaymentStatus.Paid)
            throw new ConflictAppException("This salary record is already fully paid.");

        if (request.Amount > record.PendingAmount)
            throw new ValidationAppException($"Payment amount ({request.Amount}) exceeds pending amount ({record.PendingAmount}).");

        var entry = new SalaryPaymentEntry
        {
            SalaryPaymentId = record.Id,
            Amount = request.Amount,
            PaymentMethod = request.PaymentMethod,
            PaidBy = currentUser.UserId,
            PaidAt = DateTime.UtcNow,
            Notes = request.Notes,
        };
        db.SalaryPaymentEntries.Add(entry);

        record.PaidAmount += request.Amount;
        record.PendingAmount = record.NetSalary - record.PaidAmount;
        record.Status = record.PendingAmount <= 0
            ? SalaryPaymentStatus.Paid
            : SalaryPaymentStatus.PartiallyPaid;

        await db.SaveChangesAsync(ct);

        record.Entries.Add(entry);
        return Ok(ToDto(record));
    }

    private static SalaryPaymentDto ToDto(SalaryPayment p) => new(
        p.Id, p.StaffId, p.Staff.Name, p.PeriodMonth, p.PeriodYear,
        p.BasicSalary, p.Allowance, p.Deduction, p.NetSalary,
        p.PaidAmount, p.PendingAmount, p.Status,
        p.Entries.Select(e => new SalaryPaymentEntryDto(e.Id, e.Amount, e.PaymentMethod, e.PaidBy, e.PaidAt, e.Notes)).ToList());
}
