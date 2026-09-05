namespace Erp.Application.Common;

public record IdempotentReplay(int StatusCode, string ResponseBodyJson);

/// <summary>Guards critical POST endpoints against duplicate execution from network retries — see ARCHITECTURE.md §9/§34. Caller supplies the client's Idempotency-Key header and a hash of the request body.</summary>
public interface IIdempotencyService
{
    Task<IdempotentReplay?> FindReplayAsync(Guid idempotencyKey, string endpoint, string requestHash, CancellationToken ct = default);

    Task StoreAsync(Guid idempotencyKey, string endpoint, string requestHash, int statusCode, string responseBodyJson, CancellationToken ct = default);
}
