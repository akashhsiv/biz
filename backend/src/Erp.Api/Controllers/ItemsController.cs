using Erp.Api.Auth;
using Erp.Application.Common;
using Erp.Application.Security;
using Erp.Domain.Common;
using Erp.Domain.Items;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record ItemDto(
    Guid Id, string Sku, string Name, Guid? CategoryId, Guid? BrandId, string Unit, ItemKind ItemKind,
    decimal PurchasePrice, decimal SellingPrice, decimal TaxRatePercent, string? HsnCode, bool IsBatchTracked, bool IsSerialTracked, bool IsActive, decimal StockOnHand, decimal? MinimumStock, bool HasImage,
    string? BrandName, string? CategoryName);

public record UpsertItemRequest(
    string Sku, string Name, Guid? CategoryId, string Unit, ItemKind ItemKind,
    decimal PurchasePrice, decimal SellingPrice, decimal TaxRatePercent, string? HsnCode, bool IsBatchTracked, bool IsSerialTracked, decimal? MinimumStock = null, Guid? BrandId = null);

public record UpdateItemImageRequest(string ImageBase64);

public record AvailableSerialDto(Guid Id, string SerialNumber, DateTime ReceivedDate);

[ApiController]
[Route("api/items")]
public class ItemsController(ErpDbContext db, IAuditService audit) : ControllerBase
{
    [HttpGet]
    [RequirePermission(PermissionKeys.ItemsView)]
    public async Task<ActionResult<List<ItemDto>>> List([FromQuery] bool includeInactive, [FromQuery] Guid? categoryId, [FromQuery] Guid? brandId, CancellationToken ct)
    {
        var query = db.Items.Include(i => i.StockBalance).Include(i => i.Brand).Include(i => i.Category).AsQueryable();
        if (!includeInactive) query = query.Where(i => i.IsActive);
        if (categoryId is { } catId) query = query.Where(i => i.CategoryId == catId);
        if (brandId is { } bId) query = query.Where(i => i.BrandId == bId);

        var items = await query.OrderBy(i => i.Name).Select(i => ToDto(i)).ToListAsync(ct);
        return Ok(items);
    }

    [HttpGet("{id:guid}")]
    [RequirePermission(PermissionKeys.ItemsView)]
    public async Task<ActionResult<ItemDto>> Get(Guid id, CancellationToken ct)
    {
        var item = await db.Items.Include(i => i.StockBalance).Include(i => i.Brand).Include(i => i.Category).FirstOrDefaultAsync(i => i.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Item), id);

        return Ok(ToDto(item));
    }

    /// <summary>In-stock, unsold serials for a serial-tracked item, oldest first (the FIFO order they'd
    /// be auto-assigned in if the user doesn't manually pick one) — feeds the optional serial picker on
    /// Quotation lines.</summary>
    [HttpGet("{id:guid}/available-serials")]
    [RequirePermission(PermissionKeys.ItemsView)]
    public async Task<ActionResult<List<AvailableSerialDto>>> AvailableSerials(Guid id, CancellationToken ct)
    {
        var serials = await db.ItemSerials
            .Where(s => s.ItemId == id && !s.IsSold)
            .OrderBy(s => s.ReceivedDate)
            .Select(s => new AvailableSerialDto(s.Id, s.SerialNumber, s.ReceivedDate))
            .ToListAsync(ct);

        return Ok(serials);
    }

    [HttpGet("{id:guid}/image")]
    [RequirePermission(PermissionKeys.ItemsView)]
    public async Task<IActionResult> GetImage(Guid id, CancellationToken ct)
    {
        var item = await db.Items.AsNoTracking().FirstOrDefaultAsync(i => i.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Item), id);
        if (item.Image is null) return NotFound();

        return File(item.Image, "image/png");
    }

    [HttpPut("{id:guid}/image")]
    [RequirePermission(PermissionKeys.ItemsManage)]
    public async Task<IActionResult> UpdateImage(Guid id, UpdateItemImageRequest request, CancellationToken ct)
    {
        var item = await db.Items.FirstOrDefaultAsync(i => i.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Item), id);

        try
        {
            item.Image = Convert.FromBase64String(request.ImageBase64);
        }
        catch (FormatException)
        {
            throw new ValidationAppException("ImageBase64 is not valid base64 image data.");
        }

        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    [HttpPost]
    [RequirePermission(PermissionKeys.ItemsManage)]
    public async Task<ActionResult<ItemDto>> Create(UpsertItemRequest request, CancellationToken ct)
    {
        if (await db.Items.AnyAsync(i => i.Sku == request.Sku, ct))
            throw new ValidationAppException($"SKU '{request.Sku}' already exists.");
        if (request.IsBatchTracked && request.IsSerialTracked)
            throw new ValidationAppException("An item cannot be both batch-tracked and serial-tracked.");

        var categoryId = await ResolveCategoryIdAsync(request.BrandId, request.CategoryId, ct);

        var item = new Item
        {
            Sku = request.Sku,
            Name = request.Name,
            CategoryId = categoryId,
            BrandId = request.BrandId,
            Unit = request.Unit,
            ItemKind = request.ItemKind,
            PurchasePrice = request.PurchasePrice,
            SellingPrice = request.SellingPrice,
            TaxRatePercent = request.TaxRatePercent,
            HsnCode = request.HsnCode,
            IsBatchTracked = request.IsBatchTracked,
            IsSerialTracked = request.IsSerialTracked,
            IsActive = true,
            MinimumStock = request.MinimumStock,
        };

        db.Items.Add(item);

        if (request.ItemKind == ItemKind.Stock)
        {
            db.StockBalances.Add(new StockBalance { ItemId = item.Id, QuantityOnHand = 0, UpdatedAt = DateTime.UtcNow });
        }

        await audit.LogAsync("item.created", nameof(Item), item.Id, newValue: request, ct: ct);
        await db.SaveChangesAsync(ct);

        await db.Entry(item).Reference(i => i.Brand).LoadAsync(ct);
        await db.Entry(item).Reference(i => i.Category).LoadAsync(ct);

        return Ok(ToDto(item));
    }

    [HttpPut("{id:guid}")]
    [RequirePermission(PermissionKeys.ItemsManage)]
    public async Task<ActionResult<ItemDto>> Update(Guid id, UpsertItemRequest request, CancellationToken ct)
    {
        var item = await db.Items.Include(i => i.StockBalance).Include(i => i.Brand).Include(i => i.Category).FirstOrDefaultAsync(i => i.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Item), id);

        if (item.ItemKind != request.ItemKind)
            throw new ValidationAppException("An item's Stock/Non-Stock kind cannot be changed after creation.");
        if (request.IsBatchTracked && request.IsSerialTracked)
            throw new ValidationAppException("An item cannot be both batch-tracked and serial-tracked.");

        var categoryId = await ResolveCategoryIdAsync(request.BrandId, request.CategoryId, ct);

        var oldValue = ToDto(item);

        item.Name = request.Name;
        item.CategoryId = categoryId;
        item.BrandId = request.BrandId;
        item.Unit = request.Unit;
        item.PurchasePrice = request.PurchasePrice;
        item.SellingPrice = request.SellingPrice;
        item.TaxRatePercent = request.TaxRatePercent;
        item.HsnCode = request.HsnCode;
        item.IsBatchTracked = request.IsBatchTracked;
        item.IsSerialTracked = request.IsSerialTracked;
        item.MinimumStock = request.MinimumStock;

        await db.SaveChangesAsync(ct);

        await db.Entry(item).Reference(i => i.Brand).LoadAsync(ct);
        await db.Entry(item).Reference(i => i.Category).LoadAsync(ct);
        var newValue = ToDto(item);

        await audit.LogAsync("item.updated", nameof(Item), item.Id, oldValue, newValue, ct: ct);

        return Ok(newValue);
    }

    [HttpPost("{id:guid}/deactivate")]
    [RequirePermission(PermissionKeys.ItemsManage)]
    public async Task<IActionResult> Deactivate(Guid id, CancellationToken ct)
    {
        var item = await db.Items.FirstOrDefaultAsync(i => i.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Item), id);

        item.IsActive = false;
        await audit.LogAsync("item.deactivated", nameof(Item), item.Id, ct: ct);
        await db.SaveChangesAsync(ct);

        return NoContent();
    }

    /// <summary>When a Brand is given: looks it up (404 if missing), and if the request's CategoryId is
    /// null, defaults it to the Brand's Category — a Brand always belongs to exactly one Category, so an
    /// Item picking a Brand doesn't have to separately re-specify its category. If both are given and
    /// disagree, that's a client error (ValidationAppException), not silently resolved one way.</summary>
    private async Task<Guid?> ResolveCategoryIdAsync(Guid? brandId, Guid? requestCategoryId, CancellationToken ct)
    {
        if (brandId is null) return requestCategoryId;

        var brand = await db.Brands.FirstOrDefaultAsync(b => b.Id == brandId.Value, ct)
            ?? throw new NotFoundAppException(nameof(Brand), brandId.Value);

        if (requestCategoryId is { } requested && requested != brand.CategoryId)
            throw new ValidationAppException("The item's CategoryId does not match the selected Brand's category.");

        return brand.CategoryId;
    }

    private static ItemDto ToDto(Item i) => new(
        i.Id, i.Sku, i.Name, i.CategoryId, i.BrandId, i.Unit, i.ItemKind, i.PurchasePrice, i.SellingPrice,
        i.TaxRatePercent, i.HsnCode, i.IsBatchTracked, i.IsSerialTracked, i.IsActive, i.StockBalance?.QuantityOnHand ?? 0, i.MinimumStock, i.Image is not null,
        i.Brand?.Name, i.Category?.Name);
}
