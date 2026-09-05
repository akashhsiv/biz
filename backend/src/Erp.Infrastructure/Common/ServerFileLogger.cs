namespace Erp.Infrastructure.Common;

/// <summary>
/// Plain-file server-side log, mirroring the Flutter client's own FileLogger for the same reason:
/// ErpHost normally runs as a Windows Service (LocalSystem, no console attached), so the default
/// console logger's output goes nowhere retrievable. Any component that fails silently from the
/// user's point of view (PDF rendering, WhatsApp delivery, unhandled request exceptions) should
/// append here so a Shop Admin can find real diagnostics via the Error Log screen's "Host Server"
/// tab (backed by GET /api/diagnostics/server-log) without needing remote/physical access to the
/// Host PC.
/// </summary>
public static class ServerFileLogger
{
    private static readonly SemaphoreSlim FileLock = new(1, 1);

    private static string LogPath => Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "ErpHost", "logs", "error.log");

    public static async Task LogAsync(string source, string message)
    {
        try
        {
            var dir = Path.GetDirectoryName(LogPath)!;
            Directory.CreateDirectory(dir);

            var entry = $"""
                ---- {DateTime.UtcNow:O} ----
                [{source}]
                {message}

                """;

            await FileLock.WaitAsync();
            try
            {
                await File.AppendAllTextAsync(LogPath, entry);

                var info = new FileInfo(LogPath);
                if (info.Length > 5 * 1024 * 1024)
                {
                    var lines = await File.ReadAllLinesAsync(LogPath);
                    await File.WriteAllLinesAsync(LogPath, lines.Skip(lines.Length / 2));
                }
            }
            finally
            {
                FileLock.Release();
            }
        }
        catch
        {
            // Logging must never itself crash the caller.
        }
    }
}
