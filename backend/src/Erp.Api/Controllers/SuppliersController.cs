using Erp.Api.Auth;
using Erp.Application.Common;
using Erp.Application.Security;
using Erp.Domain.Items;
using Erp.Domain.Purchases;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record SupplierDto(Guid Id, string Name, string? GstNumber, string? State, string? ContactNumber, string? Address, bool IsActive);
public record UpsertSupplierRequest(string Name, string? GstNumber, string? State, string? ContactNumber, string? Address);
public record VendorBrandDto(Guid Id, Guid SupplierId, Guid BrandId, string BrandName, Guid CategoryId);
public record LinkVendorBrandRequest(Guid BrandId);

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

    /// <summary>Brands this vendor (supplier) is linked to supply — the set a Purchase Order line's
    /// Item.Brand must be a member of when its Supplier is this one (see PurchaseOrdersController.Create).</summary>
    [HttpGet("{supplierId:guid}/brands")]
    [RequirePermission(PermissionKeys.PurchaseOrdersManage)]
    public async Task<ActionResult<List<VendorBrandDto>>> ListBrands(Guid supplierId, CancellationToken ct)
    {
        await EnsureSupplierExistsAsync(supplierId, ct);

        var links = await db.VendorBrands.Include(vb => vb.Brand)
            .Where(vb => vb.SupplierId == supplierId)
            .OrderBy(vb => vb.Brand.Name)
            .Select(vb => new VendorBrandDto(vb.Id, vb.SupplierId, vb.BrandId, vb.Brand.Name, vb.Brand.CategoryId))
            .ToListAsync(ct);

        return Ok(links);
    }

    [HttpPost("{supplierId:guid}/brands")]
    [RequirePermission(PermissionKeys.PurchaseOrdersManage)]
    public async Task<ActionResult<VendorBrandDto>> LinkBrand(Guid supplierId, LinkVendorBrandRequest request, CancellationToken ct)
    {
        await EnsureSupplierExistsAsync(supplierId, ct);

        var brand = await db.Brands.FirstOrDefaultAsync(b => b.Id == request.BrandId, ct)
            ?? throw new NotFoundAppException(nameof(Brand), request.BrandId);

        var alreadyLinked = await db.VendorBrands.AnyAsync(vb => vb.SupplierId == supplierId && vb.BrandId == brand.Id, ct);
        if (alreadyLinked)
            throw new ValidationAppException($"Brand '{brand.Name}' is already linked to this supplier.");

        var link = new VendorBrand { SupplierId = supplierId, BrandId = brand.Id };
        db.VendorBrands.Add(link);
        await db.SaveChangesAsync(ct);

        return Ok(new VendorBrandDto(link.Id, supplierId, brand.Id, brand.Name, brand.CategoryId));
    }

    [HttpDelete("{supplierId:guid}/brands/{brandId:guid}")]
    [RequirePermission(PermissionKeys.PurchaseOrdersManage)]
    public async Task<IActionResult> UnlinkBrand(Guid supplierId, Guid brandId, CancellationToken ct)
    {
        var link = await db.VendorBrands.FirstOrDefaultAsync(vb => vb.SupplierId == supplierId && vb.BrandId == brandId, ct)
            ?? throw new NotFoundAppException(nameof(VendorBrand), brandId);

        db.VendorBrands.Remove(link);
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    private async Task EnsureSupplierExistsAsync(Guid supplierId, CancellationToken ct)
    {
        var exists = await db.Suppliers.AnyAsync(s => s.Id == supplierId, ct);
        if (!exists) throw new NotFoundAppException(nameof(Supplier), supplierId);
    }

    private static SupplierDto ToDto(Supplier s) => new(s.Id, s.Name, s.GstNumber, s.State, s.ContactNumber, s.Address, s.IsActive);
}
