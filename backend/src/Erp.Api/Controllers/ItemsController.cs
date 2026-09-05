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
    Guid Id, string Sku, string Name, Guid? CategoryId, string Unit, ItemKind ItemKind,
    decimal PurchasePrice, decimal SellingPrice, decimal TaxRatePercent, string? HsnCode, bool IsBatchTracked, bool IsSerialTracked, bool IsActive, decimal StockOnHand);

public record UpsertItemRequest(
    string Sku, string Name, Guid? CategoryId, string Unit, ItemKind ItemKind,
    decimal PurchasePrice, decimal SellingPrice, decimal TaxRatePercent, string? HsnCode, bool IsBatchTracked, bool IsSerialTracked);

public record AvailableSerialDto(Guid Id, string SerialNumber, DateTime ReceivedDate);

[ApiController]
[Route("api/items")]
public class ItemsController(ErpDbContext db, IAuditService audit) : ControllerBase
{
    [HttpGet]
    [RequirePermission(PermissionKeys.ItemsView)]
    public async Task<ActionResult<List<ItemDto>>> List([FromQuery] bool includeInactive, CancellationToken ct)
    {
        var query = db.Items.Include(i => i.StockBalance).AsQueryable();
        if (!includeInactive) query = query.Where(i => i.IsActive);

        var items = await query.OrderBy(i => i.Name).Select(i => ToDto(i)).ToListAsync(ct);
        return Ok(items);
    }

    [HttpGet("{id:guid}")]
    [RequirePermission(PermissionKeys.ItemsView)]
    public async Task<ActionResult<ItemDto>> Get(Guid id, CancellationToken ct)
    {
        var item = await db.Items.Include(i => i.StockBalance).FirstOrDefaultAsync(i => i.Id == id, ct)
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

    [HttpPost]
    [RequirePermission(PermissionKeys.ItemsManage)]
    public async Task<ActionResult<ItemDto>> Create(UpsertItemRequest request, CancellationToken ct)
    {
        if (await db.Items.AnyAsync(i => i.Sku == request.Sku, ct))
            throw new ValidationAppException($"SKU '{request.Sku}' already exists.");
        if (request.IsBatchTracked && request.IsSerialTracked)
            throw new ValidationAppException("An item cannot be both batch-tracked and serial-tracked.");

        var item = new Item
        {
            Sku = request.Sku,
            Name = request.Name,
            CategoryId = request.CategoryId,
            Unit = request.Unit,
            ItemKind = request.ItemKind,
            PurchasePrice = request.PurchasePrice,
            SellingPrice = request.SellingPrice,
            TaxRatePercent = request.TaxRatePercent,
            HsnCode = request.HsnCode,
            IsBatchTracked = request.IsBatchTracked,
            IsSerialTracked = request.IsSerialTracked,
            IsActive = true,
        };

        db.Items.Add(item);

        if (request.ItemKind == ItemKind.Stock)
        {
            db.StockBalances.Add(new StockBalance { ItemId = item.Id, QuantityOnHand = 0, UpdatedAt = DateTime.UtcNow });
        }

        await audit.LogAsync("item.created", nameof(Item), item.Id, newValue: request, ct: ct);
        await db.SaveChangesAsync(ct);

        return Ok(ToDto(item));
    }

    [HttpPut("{id:guid}")]
    [RequirePermission(PermissionKeys.ItemsManage)]
    public async Task<ActionResult<ItemDto>> Update(Guid id, UpsertItemRequest request, CancellationToken ct)
    {
        var item = await db.Items.Include(i => i.StockBalance).FirstOrDefaultAsync(i => i.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Item), id);

        if (item.ItemKind != request.ItemKind)
            throw new ValidationAppException("An item's Stock/Non-Stock kind cannot be changed after creation.");
        if (request.IsBatchTracked && request.IsSerialTracked)
            throw new ValidationAppException("An item cannot be both batch-tracked and serial-tracked.");

        var oldValue = ToDto(item);

        item.Name = request.Name;
        item.CategoryId = request.CategoryId;
        item.Unit = request.Unit;
        item.PurchasePrice = request.PurchasePrice;
        item.SellingPrice = request.SellingPrice;
        item.TaxRatePercent = request.TaxRatePercent;
        item.HsnCode = request.HsnCode;
        item.IsBatchTracked = request.IsBatchTracked;
        item.IsSerialTracked = request.IsSerialTracked;

        await audit.LogAsync("item.updated", nameof(Item), item.Id, oldValue, ToDto(item), ct: ct);
        await db.SaveChangesAsync(ct);

        return Ok(ToDto(item));
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

    private static ItemDto ToDto(Item i) => new(
        i.Id, i.Sku, i.Name, i.CategoryId, i.Unit, i.ItemKind, i.PurchasePrice, i.SellingPrice,
        i.TaxRatePercent, i.HsnCode, i.IsBatchTracked, i.IsSerialTracked, i.IsActive, i.StockBalance?.QuantityOnHand ?? 0);
}
