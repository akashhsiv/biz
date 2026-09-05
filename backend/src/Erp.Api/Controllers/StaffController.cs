using Erp.Api.Auth;
using Erp.Application.Common;
using Erp.Application.Security;
using Erp.Domain.Common;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record StaffDto(
    Guid Id, string Name, string EmployeeCode, string? Mobile, string? Address, DateTime JoiningDate,
    string? Designation, Guid? CategoryId, StaffEmploymentStatus EmploymentStatus, StaffSalaryType SalaryType,
    decimal BasicSalary, decimal Allowances, decimal Deductions, string? Notes, bool IsActive);

public record UpsertStaffRequest(
    string Name, string EmployeeCode, string? Mobile, string? Address, DateTime JoiningDate,
    string? Designation, Guid? CategoryId, StaffEmploymentStatus EmploymentStatus, StaffSalaryType SalaryType,
    decimal BasicSalary, decimal Allowances, decimal Deductions, string? Notes);

[ApiController]
[Route("api/staff")]
public class StaffController(ErpDbContext db) : ControllerBase
{
    [HttpGet]
    [RequirePermission(PermissionKeys.StaffView)]
    public async Task<ActionResult<List<StaffDto>>> List(
        [FromQuery] string? search, [FromQuery] Guid? categoryId,
        [FromQuery] StaffEmploymentStatus? status, [FromQuery] bool includeInactive, CancellationToken ct)
    {
        var query = db.Staff.AsQueryable();
        if (!includeInactive) query = query.Where(s => s.IsActive);
        if (categoryId is { } cid) query = query.Where(s => s.CategoryId == cid);
        if (status is { } st) query = query.Where(s => s.EmploymentStatus == st);
        if (!string.IsNullOrWhiteSpace(search))
            query = query.Where(s => s.Name.Contains(search) || s.EmployeeCode.Contains(search) || (s.Mobile != null && s.Mobile.Contains(search)));

        return Ok(await query.OrderBy(s => s.Name).Select(s => ToDto(s)).ToListAsync(ct));
    }

    [HttpGet("{id:guid}")]
    [RequirePermission(PermissionKeys.StaffView)]
    public async Task<ActionResult<StaffDto>> Get(Guid id, CancellationToken ct)
    {
        var staff = await db.Staff.FirstOrDefaultAsync(s => s.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Erp.Domain.Staff.Staff), id);

        return Ok(ToDto(staff));
    }

    [HttpPost]
    [RequirePermission(PermissionKeys.StaffManage)]
    public async Task<ActionResult<StaffDto>> Create(UpsertStaffRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Name)) throw new ValidationAppException("Staff name is required.");
        if (string.IsNullOrWhiteSpace(request.EmployeeCode)) throw new ValidationAppException("Employee code is required.");

        var staff = new Erp.Domain.Staff.Staff
        {
            Name = request.Name,
            EmployeeCode = request.EmployeeCode,
            Mobile = request.Mobile,
            Address = request.Address,
            JoiningDate = request.JoiningDate,
            Designation = request.Designation,
            CategoryId = request.CategoryId,
            EmploymentStatus = request.EmploymentStatus,
            SalaryType = request.SalaryType,
            BasicSalary = request.BasicSalary,
            Allowances = request.Allowances,
            Deductions = request.Deductions,
            Notes = request.Notes,
            IsActive = true,
        };

        db.Staff.Add(staff);
        await db.SaveChangesAsync(ct);

        return Ok(ToDto(staff));
    }

    /// <summary>Updates the staff master record, including current salary rates. This intentionally
    /// does NOT touch any existing SalaryPayment row — those keep the Basic/Allowance/Deduction values
    /// snapshotted at generation time (see SalaryPayment doc comment), so edits here only affect the
    /// NEXT salary record generated for this staff member.</summary>
    [HttpPut("{id:guid}")]
    [RequirePermission(PermissionKeys.StaffManage)]
    public async Task<ActionResult<StaffDto>> Update(Guid id, UpsertStaffRequest request, CancellationToken ct)
    {
        var staff = await db.Staff.FirstOrDefaultAsync(s => s.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Erp.Domain.Staff.Staff), id);

        staff.Name = request.Name;
        staff.EmployeeCode = request.EmployeeCode;
        staff.Mobile = request.Mobile;
        staff.Address = request.Address;
        staff.JoiningDate = request.JoiningDate;
        staff.Designation = request.Designation;
        staff.CategoryId = request.CategoryId;
        staff.EmploymentStatus = request.EmploymentStatus;
        staff.SalaryType = request.SalaryType;
        staff.BasicSalary = request.BasicSalary;
        staff.Allowances = request.Allowances;
        staff.Deductions = request.Deductions;
        staff.Notes = request.Notes;

        await db.SaveChangesAsync(ct);
        return Ok(ToDto(staff));
    }

    [HttpPost("{id:guid}/deactivate")]
    [RequirePermission(PermissionKeys.StaffManage)]
    public async Task<IActionResult> Deactivate(Guid id, CancellationToken ct)
    {
        var staff = await db.Staff.FirstOrDefaultAsync(s => s.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Erp.Domain.Staff.Staff), id);

        staff.IsActive = false;
        staff.EmploymentStatus = StaffEmploymentStatus.Inactive;
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    private static StaffDto ToDto(Erp.Domain.Staff.Staff s) => new(
        s.Id, s.Name, s.EmployeeCode, s.Mobile, s.Address, s.JoiningDate, s.Designation, s.CategoryId,
        s.EmploymentStatus, s.SalaryType, s.BasicSalary, s.Allowances, s.Deductions, s.Notes, s.IsActive);
}
