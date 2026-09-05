using System.Security.Cryptography;
using System.Text.Json;
using Erp.Application.Common;

namespace Erp.Api.Common;

/// <summary>Explicit, opt-in idempotency check for the handful of critical POST endpoints that need it (conversions, payments, deposits) — see ARCHITECTURE.md §9/§34.</summary>
public static class IdempotencyGuard
{
    // Matches ASP.NET Core's default output-formatter naming policy, so a stored replay body
    // is byte-for-byte the same shape a live response would have produced.
    private static readonly JsonSerializerOptions ResponseJsonOptions = new(JsonSerializerDefaults.Web);

    public static Guid RequireKey(HttpRequest request)
    {
        if (!request.Headers.TryGetValue("Idempotency-Key", out var value) || !Guid.TryParse(value, out var key))
            throw new ValidationAppException("An 'Idempotency-Key' header (a UUID) is required for this operation.");

        return key;
    }

    public static string HashRequest(object body) =>
        Convert.ToHexString(SHA256.HashData(JsonSerializer.SerializeToUtf8Bytes(body)));

    /// <summary>Use this (not a bare JsonSerializer.Serialize call) whenever storing a response body for later replay.</summary>
    public static string SerializeResponse(object body) => JsonSerializer.Serialize(body, ResponseJsonOptions);
}
