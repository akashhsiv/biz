using Erp.Application.Common;
using Erp.Application.Stock;
using Erp.Domain.Common;
using Erp.Domain.Items;
using Erp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Erp.Infrastructure.Services;

public class StockService(ErpDbContext db, ICurrentUserService currentUser) : IStockService
{
    public async Task DecrementAsync(Guid itemId, decimal quantity, DocumentReferenceType referenceType, Guid referenceId, string? reason = null, List<Guid>? serialIds = null, CancellationToken ct = default)
    {
        var item = await db.Items.FirstOrDefaultAsync(i => i.Id == itemId, ct)
            ?? throw new NotFoundAppException(nameof(Item), itemId);

        if (item.ItemKind != ItemKind.Stock) return; // non-stock items never move stock.

        if (item.IsBatchTracked)
        {
            await DecrementBatchTrackedAsync(itemId, quantity, referenceType, referenceId, reason, ct);
        }
        else if (item.IsSerialTracked)
        {
            await DecrementSerialTrackedAsync(itemId, quantity, referenceType, referenceId, reason, serialIds, ct);
        }
        else
        {
            await DecrementBalanceOnlyAsync(itemId, quantity, referenceType, referenceId, StockMovementType.Sale, reason, ct);
        }
    }

    private async Task DecrementSerialTrackedAsync(Guid itemId, decimal quantity, DocumentReferenceType referenceType, Guid referenceId, string? reason, List<Guid>? serialIds, CancellationToken ct)
    {
        if (quantity != Math.Floor(quantity))
            throw new ValidationAppException("Quantity must be a whole number for a serial-tracked item.");
        var count = (int)quantity;

        List<ItemSerial> serials;
        if (serialIds is { Count: > 0 })
        {
            if (serialIds.Count != count)
                throw new ValidationAppException("The number of picked serial numbers must match the quantity.");

            // FOR UPDATE locks these specific rows for the duration of the caller's transaction, same
            // as the FIFO path below, so a concurrent Slave can't also grab one of these exact units.
            serials = await db.ItemSerials
                .FromSqlInterpolated($"""SELECT * FROM item_serials WHERE "Id" = ANY({serialIds.ToArray()}) AND "IsSold" = false FOR UPDATE""")
                .ToListAsync(ct);

            if (serials.Count != count)
                throw new ConflictAppException("One or more picked serial numbers are no longer available.");
        }
        else
        {
            // FOR UPDATE locks these rows for the duration of the caller's transaction, serializing
            // concurrent decrements of the same item's serials across Slaves — same pattern as batches.
            serials = await db.ItemSerials
                .FromSqlInterpolated($"""SELECT * FROM item_serials WHERE "ItemId" = {itemId} AND "IsSold" = false ORDER BY "ReceivedDate" LIMIT {count} FOR UPDATE""")
                .ToListAsync(ct);

            if (serials.Count < count)
                throw new ConflictAppException("Insufficient stock for this item.");
        }

        foreach (var serial in serials)
        {
            serial.IsSold = true;

            db.StockMovements.Add(new StockMovement
            {
                ItemId = itemId,
                SerialId = serial.Id,
                MovementType = StockMovementType.Sale,
                QuantityDelta = -1,
                QuantityBefore = 1,
                QuantityAfter = 0,
                ReferenceType = referenceType,
                ReferenceId = referenceId,
                Reason = reason,
                CreatedBy = currentUser.UserId,
                CreatedAt = DateTime.UtcNow,
            });
        }

        var balance = await db.StockBalances.FirstAsync(b => b.ItemId == itemId, ct);
        balance.QuantityOnHand -= quantity;
        balance.UpdatedAt = DateTime.UtcNow;
    }

    private async Task DecrementBalanceOnlyAsync(Guid itemId, decimal quantity, DocumentReferenceType referenceType, Guid referenceId, StockMovementType movementType, string? reason, CancellationToken ct)
    {
        var rowsAffected = await db.Database.ExecuteSqlInterpolatedAsync($"""
            UPDATE stock_balances SET "QuantityOnHand" = "QuantityOnHand" - {quantity}, "UpdatedAt" = {DateTime.UtcNow}
            WHERE "ItemId" = {itemId} AND "QuantityOnHand" >= {quantity}
            """, ct);

        if (rowsAffected == 0)
            throw new ConflictAppException("Insufficient stock for this item.");

        var after = (await db.StockBalances.AsNoTracking().FirstAsync(b => b.ItemId == itemId, ct)).QuantityOnHand;

        db.StockMovements.Add(new StockMovement
        {
            ItemId = itemId,
            BatchId = null,
            MovementType = movementType,
            QuantityDelta = -quantity,
            QuantityBefore = after + quantity,
            QuantityAfter = after,
            ReferenceType = referenceType,
            ReferenceId = referenceId,
            Reason = reason,
            CreatedBy = currentUser.UserId,
            CreatedAt = DateTime.UtcNow,
        });
    }

    private async Task DecrementBatchTrackedAsync(Guid itemId, decimal quantity, DocumentReferenceType referenceType, Guid referenceId, string? reason, CancellationToken ct)
    {
        // FOR UPDATE locks these rows for the duration of the caller's transaction, serializing
        // concurrent decrements of the same item's batches across Slaves.
        var batches = await db.ItemBatches
            .FromSqlInterpolated($"""SELECT * FROM item_batches WHERE "ItemId" = {itemId} AND "QuantityOnHand" > 0 ORDER BY "ReceivedDate" FOR UPDATE""")
            .ToListAsync(ct);

        if (batches.Sum(b => b.QuantityOnHand) < quantity)
            throw new ConflictAppException("Insufficient stock for this item.");

        var remaining = quantity;
        foreach (var batch in batches)
        {
            if (remaining <= 0) break;

            var take = Math.Min(remaining, batch.QuantityOnHand);
            var before = batch.QuantityOnHand;
            batch.QuantityOnHand -= take;
            remaining -= take;

            db.StockMovements.Add(new StockMovement
            {
                ItemId = itemId,
                BatchId = batch.Id,
                MovementType = StockMovementType.Sale,
                QuantityDelta = -take,
                QuantityBefore = before,
                QuantityAfter = batch.QuantityOnHand,
                ReferenceType = referenceType,
                ReferenceId = referenceId,
                Reason = reason,
                CreatedBy = currentUser.UserId,
                CreatedAt = DateTime.UtcNow,
            });
        }

        var balance = await db.StockBalances.FirstAsync(b => b.ItemId == itemId, ct);
        balance.QuantityOnHand -= quantity;
        balance.UpdatedAt = DateTime.UtcNow;
    }

    private async Task IncrementSerialTrackedAsync(Guid itemId, decimal quantity, DocumentReferenceType referenceType, Guid referenceId,
        string? reason, List<string>? newSerialNumbers, List<Guid>? existingSerialIds, CancellationToken ct)
    {
        if (quantity != Math.Floor(quantity))
            throw new ValidationAppException("Quantity must be a whole number for a serial-tracked item.");
        var count = (int)quantity;

        if (existingSerialIds is { Count: > 0 })
        {
            // Reversal of a prior sale: restore the exact same units rather than minting new serials.
            var serials = await db.ItemSerials.Where(s => existingSerialIds.Contains(s.Id)).ToListAsync(ct);
            foreach (var serial in serials)
            {
                serial.IsSold = false;
                db.StockMovements.Add(new StockMovement
                {
                    ItemId = itemId,
                    SerialId = serial.Id,
                    MovementType = StockMovementType.Reversal,
                    QuantityDelta = 1,
                    QuantityBefore = 0,
                    QuantityAfter = 1,
                    ReferenceType = referenceType,
                    ReferenceId = referenceId,
                    Reason = reason,
                    CreatedBy = currentUser.UserId,
                    CreatedAt = DateTime.UtcNow,
                });
            }
            return;
        }

        var numbers = newSerialNumbers ?? [];
        if (numbers.Count != count)
            throw new ValidationAppException($"Enter exactly {count} serial number(s) for this line.");

        foreach (var number in numbers)
        {
            var serial = new ItemSerial
            {
                ItemId = itemId,
                SerialNumber = number,
                ReceivedDate = DateTime.UtcNow,
            };
            db.ItemSerials.Add(serial);

            db.StockMovements.Add(new StockMovement
            {
                ItemId = itemId,
                SerialId = serial.Id,
                MovementType = StockMovementType.Purchase,
                QuantityDelta = 1,
                QuantityBefore = 0,
                QuantityAfter = 1,
                ReferenceType = referenceType,
                ReferenceId = referenceId,
                Reason = reason,
                CreatedBy = currentUser.UserId,
                CreatedAt = DateTime.UtcNow,
            });
        }
    }

    public async Task<Guid?> IncrementAsync(Guid itemId, decimal quantity, DocumentReferenceType referenceType, Guid referenceId,
        string? reason = null, string? newBatchNumber = null, DateTime? expiryDate = null, Guid? existingBatchId = null,
        List<string>? newSerialNumbers = null, List<Guid>? existingSerialIds = null, CancellationToken ct = default)
    {
        var item = await db.Items.FirstOrDefaultAsync(i => i.Id == itemId, ct)
            ?? throw new NotFoundAppException(nameof(Item), itemId);

        if (item.ItemKind != ItemKind.Stock) return null;

        if (item.IsSerialTracked)
        {
            await IncrementSerialTrackedAsync(itemId, quantity, referenceType, referenceId, reason, newSerialNumbers, existingSerialIds, ct);

            var rows = await db.Database.ExecuteSqlInterpolatedAsync($"""
                UPDATE stock_balances SET "QuantityOnHand" = "QuantityOnHand" + {quantity}, "UpdatedAt" = {DateTime.UtcNow}
                WHERE "ItemId" = {itemId}
                """, ct);
            if (rows == 0) throw new NotFoundAppException("StockBalance", itemId);

            return null;
        }

        Guid? batchId = null;

        if (item.IsBatchTracked)
        {
            if (existingBatchId is { } existing)
            {
                var batch = await db.ItemBatches.FirstOrDefaultAsync(b => b.Id == existing, ct)
                    ?? throw new NotFoundAppException(nameof(ItemBatch), existing);

                var before = batch.QuantityOnHand;
                batch.QuantityOnHand += quantity;
                batchId = batch.Id;

                db.StockMovements.Add(NewMovement(itemId, batch.Id, quantity, before, batch.QuantityOnHand, referenceType, referenceId, reason));
            }
            else
            {
                var batch = new ItemBatch
                {
                    ItemId = itemId,
                    BatchNumber = newBatchNumber ?? $"AUTO-{DateTime.UtcNow:yyyyMMddHHmmss}",
                    QuantityOnHand = quantity,
                    ReceivedDate = DateTime.UtcNow,
                    ExpiryDate = expiryDate,
                };
                db.ItemBatches.Add(batch);
                batchId = batch.Id;

                db.StockMovements.Add(NewMovement(itemId, batch.Id, quantity, 0, quantity, referenceType, referenceId, reason));
            }
        }

        var rowsAffected = await db.Database.ExecuteSqlInterpolatedAsync($"""
            UPDATE stock_balances SET "QuantityOnHand" = "QuantityOnHand" + {quantity}, "UpdatedAt" = {DateTime.UtcNow}
            WHERE "ItemId" = {itemId}
            """, ct);

        if (rowsAffected == 0)
            throw new NotFoundAppException("StockBalance", itemId);

        if (!item.IsBatchTracked)
        {
            var after = (await db.StockBalances.AsNoTracking().FirstAsync(b => b.ItemId == itemId, ct)).QuantityOnHand;
            db.StockMovements.Add(NewMovement(itemId, null, quantity, after - quantity, after, referenceType, referenceId, reason));
        }

        return batchId;
    }

    public async Task ReverseAsync(Guid originalMovementId, string reason, CancellationToken ct = default)
    {
        var original = await db.StockMovements.AsNoTracking().FirstOrDefaultAsync(m => m.Id == originalMovementId, ct)
            ?? throw new NotFoundAppException(nameof(StockMovement), originalMovementId);

        var reversalQuantity = Math.Abs(original.QuantityDelta);

        if (original.QuantityDelta < 0)
        {
            // Original decremented stock (e.g. a Sale) — reversal restores it into the same batch/serial, if any.
            await IncrementAsync(original.ItemId, reversalQuantity, original.ReferenceType, original.ReferenceId, reason,
                existingBatchId: original.BatchId, existingSerialIds: original.SerialId is { } sid ? [sid] : null, ct: ct);
        }
        else
        {
            await DecrementAsync(original.ItemId, reversalQuantity, original.ReferenceType, original.ReferenceId, reason, ct: ct);
        }

        // Re-tag the movement(s) just written as Reversal type instead of the default inferred type.
        var justWritten = db.ChangeTracker.Entries<StockMovement>()
            .Where(e => e.State == EntityState.Added && e.Entity.ItemId == original.ItemId)
            .Select(e => e.Entity);

        foreach (var movement in justWritten)
        {
            movement.MovementType = StockMovementType.Reversal;
        }
    }

    private StockMovement NewMovement(Guid itemId, Guid? batchId, decimal quantity, decimal before, decimal after, DocumentReferenceType referenceType, Guid referenceId, string? reason) => new()
    {
        ItemId = itemId,
        BatchId = batchId,
        MovementType = StockMovementType.Purchase,
        QuantityDelta = quantity,
        QuantityBefore = before,
        QuantityAfter = after,
        ReferenceType = referenceType,
        ReferenceId = referenceId,
        Reason = reason,
        CreatedBy = currentUser.UserId,
        CreatedAt = DateTime.UtcNow,
    };
}
