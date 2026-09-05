using System.Security.Cryptography;
using System.Text;

namespace Erp.Application.Security;

/// <summary>The session table stores only the SHA-256 hash of a token, never the raw value — so a database leak alone can't be used to impersonate a session.</summary>
public static class TokenHasher
{
    public static string GenerateRawToken()
    {
        Span<byte> bytes = stackalloc byte[32];
        RandomNumberGenerator.Fill(bytes);
        return Convert.ToBase64String(bytes).Replace('+', '-').Replace('/', '_').TrimEnd('=');
    }

    public static string Hash(string rawToken)
    {
        var bytes = Encoding.UTF8.GetBytes(rawToken);
        var hash = SHA256.HashData(bytes);
        return Convert.ToHexString(hash);
    }
}
