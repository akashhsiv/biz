using Erp.Api.Auth;
using Erp.Application.Security;
using Erp.Domain.Items;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record ItemCategoryDto(Guid Id, string Name, bool IsActive);
public record TaxGroupDto(Guid Id, string Name, decimal RatePercent, bool IsActive);
public record CreateItemCategoryRequest(string Name);
public record CreateTaxGroupRequest(string Name, decimal RatePercent);

[ApiController]
[Route("api")]
public class LookupsController(ErpDbContext db) : ControllerBase
{
    [HttpGet("item-categories")]
    [RequirePermission(PermissionKeys.ItemsView)]
    public async Task<ActionResult<List<ItemCategoryDto>>> ListCategories(CancellationToken ct) =>
        Ok(await db.ItemCategories.Where(c => c.IsActive).OrderBy(c => c.Name)
            .Select(c => new ItemCategoryDto(c.Id, c.Name, c.IsActive)).ToListAsync(ct));

    [HttpPost("item-categories")]
    [RequirePermission(PermissionKeys.ItemsManage)]
    public async Task<ActionResult<ItemCategoryDto>> CreateCategory(CreateItemCategoryRequest request, CancellationToken ct)
    {
        var category = new ItemCategory { Name = request.Name, IsActive = true };
        db.ItemCategories.Add(category);
        await db.SaveChangesAsync(ct);
        return Ok(new ItemCategoryDto(category.Id, category.Name, category.IsActive));
    }

    [HttpGet("tax-groups")]
    [RequirePermission(PermissionKeys.ItemsView)]
    public async Task<ActionResult<List<TaxGroupDto>>> ListTaxGroups(CancellationToken ct) =>
        Ok(await db.TaxGroups.Where(t => t.IsActive).OrderBy(t => t.RatePercent)
            .Select(t => new TaxGroupDto(t.Id, t.Name, t.RatePercent, t.IsActive)).ToListAsync(ct));

    [HttpPost("tax-groups")]
    [RequirePermission(PermissionKeys.ItemsManage)]
    public async Task<ActionResult<TaxGroupDto>> CreateTaxGroup(CreateTaxGroupRequest request, CancellationToken ct)
    {
        var taxGroup = new TaxGroup { Name = request.Name, RatePercent = request.RatePercent, IsActive = true };
        db.TaxGroups.Add(taxGroup);
        await db.SaveChangesAsync(ct);
        return Ok(new TaxGroupDto(taxGroup.Id, taxGroup.Name, taxGroup.RatePercent, taxGroup.IsActive));
    }
}
