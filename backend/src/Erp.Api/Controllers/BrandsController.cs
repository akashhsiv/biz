using Erp.Api.Auth;
using Erp.Application.Common;
using Erp.Application.Security;
using Erp.Domain.Items;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record BrandDto(Guid Id, string Name, Guid CategoryId, bool IsActive);
public record UpsertBrandRequest(string Name, Guid CategoryId);

[ApiController]
[Route("api/brands")]
public class BrandsController(ErpDbContext db) : ControllerBase
{
    [HttpGet]
    [RequirePermission(PermissionKeys.ItemsView)]
    public async Task<ActionResult<List<BrandDto>>> List([FromQuery] Guid? categoryId, [FromQuery] bool includeInactive, CancellationToken ct)
    {
        var query = db.Brands.AsQueryable();
        if (!includeInactive) query = query.Where(b => b.IsActive);
        if (categoryId is { } cid) query = query.Where(b => b.CategoryId == cid);

        return Ok(await query.OrderBy(b => b.Name).Select(b => ToDto(b)).ToListAsync(ct));
    }

    [HttpGet("{id:guid}")]
    [RequirePermission(PermissionKeys.ItemsView)]
    public async Task<ActionResult<BrandDto>> Get(Guid id, CancellationToken ct)
    {
        var brand = await db.Brands.FirstOrDefaultAsync(b => b.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Brand), id);

        return Ok(ToDto(brand));
    }

    [HttpPost]
    [RequirePermission(PermissionKeys.ItemsManage)]
    public async Task<ActionResult<BrandDto>> Create(UpsertBrandRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
            throw new ValidationAppException("Brand name is required.");

        var category = await db.ItemCategories.FirstOrDefaultAsync(c => c.Id == request.CategoryId, ct)
            ?? throw new NotFoundAppException(nameof(ItemCategory), request.CategoryId);

        var brand = new Brand { Name = request.Name, CategoryId = category.Id, IsActive = true };
        db.Brands.Add(brand);
        await db.SaveChangesAsync(ct);

        return Ok(ToDto(brand));
    }

    [HttpPut("{id:guid}")]
    [RequirePermission(PermissionKeys.ItemsManage)]
    public async Task<ActionResult<BrandDto>> Update(Guid id, UpsertBrandRequest request, CancellationToken ct)
    {
        var brand = await db.Brands.FirstOrDefaultAsync(b => b.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Brand), id);

        if (string.IsNullOrWhiteSpace(request.Name))
            throw new ValidationAppException("Brand name is required.");

        var category = await db.ItemCategories.FirstOrDefaultAsync(c => c.Id == request.CategoryId, ct)
            ?? throw new NotFoundAppException(nameof(ItemCategory), request.CategoryId);

        brand.Name = request.Name;
        brand.CategoryId = category.Id;

        await db.SaveChangesAsync(ct);
        return Ok(ToDto(brand));
    }

    [HttpPost("{id:guid}/deactivate")]
    [RequirePermission(PermissionKeys.ItemsManage)]
    public async Task<IActionResult> Deactivate(Guid id, CancellationToken ct)
    {
        var brand = await db.Brands.FirstOrDefaultAsync(b => b.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Brand), id);

        brand.IsActive = false;
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    private static BrandDto ToDto(Brand b) => new(b.Id, b.Name, b.CategoryId, b.IsActive);
}
