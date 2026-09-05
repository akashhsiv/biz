namespace Erp.Domain.System;

/// <summary>Guards critical POST endpoints (conversions, payments, deposits) against duplicate execution from network retries. A repeated key with a matching request hash replays the stored response instead of re-running the operation.</summary>
public class IdempotencyKey
{
    /// <summary>Client-supplied UUID, sent as the Idempotency-Key header.</summary>
    public Guid Id { get; set; }

    public string Endpoint { get; set; } = default!;
    public string RequestHash { get; set; } = default!;
    public int ResponseStatus { get; set; }
    public string ResponseBodyJson { get; set; } = default!;

    public DateTime CreatedAt { get; set; }
}
