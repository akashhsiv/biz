using Erp.Api.Auth;
using Erp.Application.Common;
using Erp.Application.Security;
using Erp.Domain.Purchases;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record SupplierDto(Guid Id, string Name, string? GstNumber, string? State, string? ContactNumber, string? Address, bool IsActive);
public record UpsertSupplierRequest(string Name, string? GstNumber, string? State, string? ContactNumber, string? Address);

[ApiController]
[Route("api/suppliers")]
public class SuppliersController(ErpDbContext db) : ControllerBase
{
    [HttpGet]
    [RequirePermission(PermissionKeys.PurchaseOrdersManage)]
    public async Task<ActionResult<List<SupplierDto>>> List([FromQuery] bool includeInactive, CancellationToken ct)
    {
        var query = db.Suppliers.AsQueryable();
        if (!includeInactive) query = query.Where(s => s.IsActive);

        return Ok(await query.OrderBy(s => s.Name).Select(s => ToDto(s)).ToListAsync(ct));
    }

    [HttpPost]
    [RequirePermission(PermissionKeys.PurchaseOrdersManage)]
    public async Task<ActionResult<SupplierDto>> Create(UpsertSupplierRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
            throw new ValidationAppException("Supplier name is required.");

        var supplier = new Supplier { Name = request.Name, GstNumber = request.GstNumber, State = request.State, ContactNumber = request.ContactNumber, Address = request.Address, IsActive = true };
        db.Suppliers.Add(supplier);
        await db.SaveChangesAsync(ct);

        return Ok(ToDto(supplier));
    }

    [HttpPut("{id:guid}")]
    [RequirePermission(PermissionKeys.PurchaseOrdersManage)]
    public async Task<ActionResult<SupplierDto>> Update(Guid id, UpsertSupplierRequest request, CancellationToken ct)
    {
        var supplier = await db.Suppliers.FirstOrDefaultAsync(s => s.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Supplier), id);

        supplier.Name = request.Name;
        supplier.GstNumber = request.GstNumber;
        supplier.State = request.State;
        supplier.ContactNumber = request.ContactNumber;
        supplier.Address = request.Address;

        await db.SaveChangesAsync(ct);
        return Ok(ToDto(supplier));
    }

    [HttpPost("{id:guid}/deactivate")]
    [RequirePermission(PermissionKeys.PurchaseOrdersManage)]
    public async Task<IActionResult> Deactivate(Guid id, CancellationToken ct)
    {
        var supplier = await db.Suppliers.FirstOrDefaultAsync(s => s.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Supplier), id);

        supplier.IsActive = false;
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    private static SupplierDto ToDto(Supplier s) => new(s.Id, s.Name, s.GstNumber, s.State, s.ContactNumber, s.Address, s.IsActive);
}
