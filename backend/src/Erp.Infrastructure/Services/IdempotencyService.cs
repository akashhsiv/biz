using Erp.Application.Common;
using Erp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Erp.Infrastructure.Services;

public class IdempotencyService(ErpDbContext db) : IIdempotencyService
{
    public async Task<IdempotentReplay?> FindReplayAsync(Guid idempotencyKey, string endpoint, string requestHash, CancellationToken ct = default)
    {
        var existing = await db.IdempotencyKeys.AsNoTracking().FirstOrDefaultAsync(k => k.Id == idempotencyKey, ct);
        if (existing is null) return null;

        if (existing.Endpoint != endpoint || existing.RequestHash != requestHash)
        {
            throw new ConflictAppException("This Idempotency-Key was already used for a different request.");
        }

        return new IdempotentReplay(existing.ResponseStatus, existing.ResponseBodyJson);
    }

    public async Task StoreAsync(Guid idempotencyKey, string endpoint, string requestHash, int statusCode, string responseBodyJson, CancellationToken ct = default)
    {
        db.IdempotencyKeys.Add(new Erp.Domain.System.IdempotencyKey
        {
            Id = idempotencyKey,
            Endpoint = endpoint,
            RequestHash = requestHash,
            ResponseStatus = statusCode,
            ResponseBodyJson = responseBodyJson,
            CreatedAt = DateTime.UtcNow,
        });

        await db.SaveChangesAsync(ct);
    }
}
