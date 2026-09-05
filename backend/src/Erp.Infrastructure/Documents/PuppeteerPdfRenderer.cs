using Erp.Application.Documents;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using PuppeteerSharp;

namespace Erp.Infrastructure.Documents;

/// <summary>
/// Launches a single headless Chromium instance shared across the process. Chromium is downloaded once
/// (to the configured cache path) and reused fully offline afterward — see ARCHITECTURE.md §35.
/// </summary>
public sealed class PuppeteerPdfRenderer(IConfiguration configuration, ILogger<PuppeteerPdfRenderer> logger) : IPdfRenderer, IAsyncDisposable
{
    private readonly SemaphoreSlim _lock = new(1, 1);
    private IBrowser? _browser;
    private string? _userDataDir;

    /// Render has no natural timeout of its own (PdfDataAsync isn't a navigation call, so Puppeteer's
    /// default 30s navigation timeout doesn't cover it) - a wedged Chromium would otherwise hang the
    /// request until the caller's own timeout (the frontend's 60s) gives up with no clue why. Failing
    /// fast here, with a clear log line, makes that diagnosable instead of just "it was slow."
    private static readonly TimeSpan RenderTimeout = TimeSpan.FromSeconds(30);

    public async Task<byte[]> RenderAsync(string html, CancellationToken ct = default)
    {
        var browser = await GetBrowserAsync(ct);

        await using var page = await browser.NewPageAsync();
        try
        {
            return await RenderOnPageAsync(page, html).WaitAsync(RenderTimeout, ct);
        }
        catch (TimeoutException)
        {
            logger.LogError("PDF render timed out after {Timeout}s - Chromium may be wedged.", RenderTimeout.TotalSeconds);
            throw;
        }
    }

    private static async Task<byte[]> RenderOnPageAsync(IPage page, string html)
    {
        await page.SetContentAsync(html);
        return await page.PdfDataAsync(new PdfOptions
        {
            Format = PuppeteerSharp.Media.PaperFormat.A4,
            PrintBackground = true,
            MarginOptions = new PuppeteerSharp.Media.MarginOptions { Top = "12mm", Bottom = "12mm", Left = "10mm", Right = "10mm" },
        });
    }

    /// Launches (or confirms) the shared browser instance ahead of the first real PDF request — call
    /// this once at Host startup so the multi-second cold Chromium launch happens in the background
    /// instead of stalling whichever user happens to click "View PDF" first, and so a broken install
    /// (missing/corrupt Chromium, launch failure) shows up in the startup log immediately rather than
    /// only when someone tries to print.
    public Task WarmUpAsync(CancellationToken ct = default) => GetBrowserAsync(ct);

    private async Task<IBrowser> GetBrowserAsync(CancellationToken ct)
    {
        if (_browser is { IsConnected: true }) return _browser;

        await _lock.WaitAsync(ct);
        try
        {
            if (_browser is { IsConnected: true }) return _browser;

            // A non-null _browser here means the previous instance disconnected/crashed since it was
            // last launched successfully - worth a loud log line, since PDF generation would otherwise
            // have started silently failing with no obvious cause until this relaunch happened.
            if (_browser is not null)
                logger.LogWarning("PDF renderer's Chromium instance was disconnected - relaunching.");

            // Full desktop browsers (system Edge/Chrome) fail silently ("Failed to launch browser!",
            // no stderr) when launched from ErpHost's Windows Service process - LocalSystem runs in
            // Session 0, which has no interactive window station, and the full browser's GPU/crash
            // reporter subprocesses depend on one even in headless mode. chrome-headless-shell is a
            // separate binary built specifically for headless/server automation and has no such
            // dependency, so it is used whenever running as a service; the system browser is only used
            // for the interactive (dev, `dotnet run`) case where it launches fine and saves a download.
            var isService = !Environment.UserInteractive;
            var systemBrowserPath = isService ? null : FindSystemBrowser();
            string executablePath;
            var browserKind = SupportedBrowser.Chrome;

            if (systemBrowserPath is not null)
            {
                logger.LogInformation("Using system browser for PDF rendering: {Path}", systemBrowserPath);
                executablePath = systemBrowserPath;
            }
            else
            {
                var configuredPath = configuration["Pdf:ChromiumCachePath"];
                var cachePath = string.IsNullOrWhiteSpace(configuredPath)
                    ? Path.Combine(AppContext.BaseDirectory, "chromium-cache")
                    : configuredPath;

                logger.LogInformation("Using chrome-headless-shell for PDF rendering (service={IsService}): {Path}", isService, cachePath);

                var fetcher = new BrowserFetcher(new BrowserFetcherOptions { Path = cachePath, Browser = SupportedBrowser.ChromeHeadlessShell });
                var revision = await fetcher.DownloadAsync();
                executablePath = revision.GetExecutablePath();
                browserKind = SupportedBrowser.ChromeHeadlessShell;
            }

            // ErpHost normally runs as the LocalSystem Windows service account, which has no real user
            // profile - Chromium/Edge's default user-data-dir resolution fails under that account (no
            // writable %LOCALAPPDATA%), so the browser never launches. Point it at an explicit, always-
            // writable profile under ProgramData instead of relying on the account's own profile.
            //
            // Unique per process (not a fixed shared path) - a shared directory meant that if a
            // previous ErpHost process's Chromium child survived a forceful restart (e.g. the debugger
            // killing the .NET process without giving IAsyncDisposable a chance to run), this process's
            // launch would collide with it and crash with "browser is already running for <dir>". A
            // fresh directory per process removes that whole class of collision; stale sibling
            // directories from earlier runs are best-effort cleaned up below (skipped if still locked).
            var chromiumRoot = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData), "ErpHost");
            CleanUpStaleProfileDirs(chromiumRoot);
            var userDataDir = Path.Combine(chromiumRoot, $"chromium-profile-{Environment.ProcessId}");
            Directory.CreateDirectory(userDataDir);
            _userDataDir = userDataDir;

            _browser = await Puppeteer.LaunchAsync(new LaunchOptions
            {
                Headless = true,
                Browser = browserKind,
                ExecutablePath = executablePath,
                Args = ["--no-sandbox", "--disable-gpu", "--disable-dev-shm-usage", "--disable-crash-reporter", "--no-first-run"],
                UserDataDir = userDataDir,
            });

            return _browser;
        }
        finally
        {
            _lock.Release();
        }
    }

    /// <summary>Best-effort removal of profile directories left behind by earlier process instances
    /// (crashed, force-killed, or an older version's now-unused shared directory) — never throws, since
    /// a directory still in use by a genuinely-orphaned live Chromium process will simply fail to
    /// delete and is left for next time.</summary>
    private void CleanUpStaleProfileDirs(string chromiumRoot)
    {
        if (!Directory.Exists(chromiumRoot)) return;

        foreach (var dir in Directory.EnumerateDirectories(chromiumRoot, "chromium-profile*"))
        {
            if (Path.GetFileName(dir) == $"chromium-profile-{Environment.ProcessId}") continue;

            try
            {
                Directory.Delete(dir, recursive: true);
            }
            catch (Exception ex)
            {
                logger.LogDebug("Could not remove stale Chromium profile dir {Dir} (likely still in use): {Message}", dir, ex.Message);
            }
        }
    }

    /// <summary>
    /// Almost every Windows PC already has Microsoft Edge (Chromium-based, ships with the OS) or Chrome
    /// installed. Using it directly means the Host install never needs the ~450MB bundled Chromium
    /// cache at all - that's only a fallback for the rare PC with neither.
    /// </summary>
    private static string? FindSystemBrowser()
    {
        string[] candidates =
        [
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Microsoft", "Edge", "Application", "msedge.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Microsoft", "Edge", "Application", "msedge.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "Google", "Chrome", "Application", "chrome.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "Google", "Chrome", "Application", "chrome.exe"),
        ];

        return candidates.FirstOrDefault(File.Exists);
    }

    public async ValueTask DisposeAsync()
    {
        if (_browser is not null)
        {
            await _browser.CloseAsync();
            _browser.Dispose();
        }

        // Only reached on a graceful shutdown - a forceful kill (debugger stop, `taskkill /F`) skips
        // this entirely, which is exactly the case CleanUpStaleProfileDirs exists to mop up next launch.
        if (_userDataDir is not null)
        {
            try
            {
                Directory.Delete(_userDataDir, recursive: true);
            }
            catch (Exception ex)
            {
                logger.LogDebug("Could not remove this process's Chromium profile dir {Dir} on shutdown: {Message}", _userDataDir, ex.Message);
            }
        }
    }
}
