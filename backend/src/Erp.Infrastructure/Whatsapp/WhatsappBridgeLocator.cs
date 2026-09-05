using Microsoft.Extensions.Configuration;

namespace Erp.Infrastructure.Whatsapp;

/// <summary>
/// Resolves the WhatsApp bridge's base URL without depending on an install-time config-patch step
/// having succeeded, or on an admin hand-editing appsettings.json. Whatsapp:BaileysBaseUrl in config
/// still wins if explicitly set (manual override), but otherwise this reads the port the bridge
/// actually bound to straight from resolved-port.txt - the same file win-service.cjs writes next to
/// itself during install, after walking forward from 3001 if that port was already taken.
/// </summary>
public class WhatsappBridgeLocator(IConfiguration configuration)
{
    private string? _cachedFromFile;
    private bool _fileChecked;

    public string? BaseUrl
    {
        get
        {
            var configured = configuration["Whatsapp:BaileysBaseUrl"];
            if (!string.IsNullOrWhiteSpace(configured)) return configured;

            // Cached after the first lookup - the bridge's port is fixed for the lifetime of this
            // process (it's only re-resolved by the installer, which requires a Host restart anyway).
            if (!_fileChecked)
            {
                _fileChecked = true;
                _cachedFromFile = ReadFromResolvedPortFile();
            }
            return _cachedFromFile;
        }
    }

    private static string? ReadFromResolvedPortFile()
    {
        try
        {
            // Erp.Api.exe runs from <install>\backend; the bridge is staged as a sibling at
            // <install>\whatsapp (see deploy\host\install.bat).
            var candidate = Path.Combine(AppContext.BaseDirectory, "..", "whatsapp", "resolved-port.txt");
            if (!File.Exists(candidate)) return null;

            var port = File.ReadAllText(candidate).Trim();
            return string.IsNullOrEmpty(port) ? null : $"http://localhost:{port}";
        }
        catch
        {
            return null;
        }
    }
}
