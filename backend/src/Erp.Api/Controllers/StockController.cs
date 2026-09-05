using Erp.Api.Auth;
using Erp.Application.Common;
using Erp.Application.Security;
using Erp.Application.Stock;
using Erp.Domain.Common;
using Erp.Domain.Items;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record StockLevelDto(Guid ItemId, string Sku, string Name, decimal QuantityOnHand, bool IsBatchTracked, bool IsSerialTracked);
public record StockMovementDto(Guid Id, Guid ItemId, Guid? BatchId, StockMovementType MovementType, decimal QuantityDelta, decimal QuantityBefore, decimal QuantityAfter, DocumentReferenceType ReferenceType, Guid ReferenceId, string? Reason, DateTime CreatedAt);
public record StockAdjustmentRequest(Guid ItemId, decimal QuantityDelta, string Reason, List<string>? SerialNumbers = null, string? BatchNumber = null, DateTime? ExpiryDate = null);

[ApiController]
[Route("api/stock")]
public class StockController(ErpDbContext db, IStockService stock, IAuditService audit) : ControllerBase
{
    [HttpGet]
    [RequirePermission(PermissionKeys.StockView)]
    public async Task<ActionResult<List<StockLevelDto>>> Levels(CancellationToken ct)
    {
        var levels = await db.Items.Where(i => i.ItemKind == ItemKind.Stock)
            .OrderBy(i => i.Name)
            .Select(i => new StockLevelDto(i.Id, i.Sku, i.Name, i.StockBalance!.QuantityOnHand, i.IsBatchTracked, i.IsSerialTracked))
            .ToListAsync(ct);

        return Ok(levels);
    }

    [HttpGet("movements")]
    [RequirePermission(PermissionKeys.StockView)]
    public async Task<ActionResult<List<StockMovementDto>>> Movements([FromQuery] Guid? itemId, [FromQuery] int take = 200, CancellationToken ct = default)
    {
        var query = db.StockMovements.AsQueryable();
        if (itemId is { } id) query = query.Where(m => m.ItemId == id);

        var movements = await query.OrderByDescending(m => m.CreatedAt).Take(Math.Clamp(take, 1, 1000))
            .Select(m => new StockMovementDto(m.Id, m.ItemId, m.BatchId, m.MovementType, m.QuantityDelta, m.QuantityBefore, m.QuantityAfter, m.ReferenceType, m.ReferenceId, m.Reason, m.CreatedAt))
            .ToListAsync(ct);

        return Ok(movements);
    }

    /// <summary>Manual correction — always requires a reason, always creates a movement of type Adjustment. Negative stock is still never allowed (ARCHITECTURE.md §13 item 7).</summary>
    [HttpPost("adjustments")]
    [RequirePermission(PermissionKeys.StockAdjust)]
    public async Task<IActionResult> Adjust(StockAdjustmentRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Reason))
            throw new ValidationAppException("A reason is required for a stock adjustment.");
        if (request.QuantityDelta == 0)
            throw new ValidationAppException("Adjustment quantity cannot be zero.");

        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var refId = Guid.NewGuid();

        if (request.QuantityDelta > 0)
        {
            await stock.IncrementAsync(request.ItemId, request.QuantityDelta, DocumentReferenceType.ManualAdjustment, refId, request.Reason,
                newBatchNumber: request.BatchNumber, expiryDate: request.ExpiryDate, newSerialNumbers: request.SerialNumbers, ct: ct);
        }
        else
        {
            List<Guid>? serialIds = null;
            if (request.SerialNumbers is { Count: > 0 })
            {
                serialIds = await db.ItemSerials
                    .Where(s => s.ItemId == request.ItemId && !s.IsSold && request.SerialNumbers.Contains(s.SerialNumber))
                    .Select(s => s.Id)
                    .ToListAsync(ct);

                if (serialIds.Count != request.SerialNumbers.Count)
                    throw new ValidationAppException("One or more entered serial numbers were not found in stock.");
            }

            await stock.DecrementAsync(request.ItemId, -request.QuantityDelta, DocumentReferenceType.ManualAdjustment, refId, request.Reason, serialIds: serialIds, ct: ct);
        }

        // The service tags new rows with Sale/Purchase by default — re-tag as Adjustment for a manual correction.
        foreach (var movement in db.ChangeTracker.Entries<Erp.Domain.Items.StockMovement>().Where(e => e.State == EntityState.Added))
        {
            movement.Entity.MovementType = StockMovementType.Adjustment;
        }

        await audit.LogAsync("stock.adjustment", nameof(Item), request.ItemId, reason: request.Reason, newValue: request.QuantityDelta, ct: ct);

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        return NoContent();
    }
}
