using Erp.Api.Auth;
using Erp.Api.Common;
using Erp.Application.Auth;
using Erp.Application.Common;
using Erp.Application.Security;
using Erp.Infrastructure.Persistence;
using Erp.Infrastructure.Persistence.Seed;
using Erp.Infrastructure.Services;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;

var builder = WebApplication.CreateBuilder(args);

// A no-op when run interactively; makes `sc create`/service-manager hosting work for Phase 5
// deployment without a separate entry point — ARCHITECTURE.md §4/§8.
builder.Host.UseWindowsService(options => options.ServiceName = "ErpHost");

// Host must be LAN-reachable, not just localhost, so Slave PCs on the same network can connect.
builder.WebHost.UseUrls("http://0.0.0.0:5000");

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddOpenApi();
builder.Services.AddHttpContextAccessor();

builder.Services.AddDbContext<ErpDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("ErpDatabase")));

builder.Services.AddScoped<ICurrentUserService, HttpCurrentUserService>();
builder.Services.AddScoped<IAuditService, AuditService>();
builder.Services.AddScoped<IIdempotencyService, IdempotencyService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IDocumentNumberService, DocumentNumberService>();
builder.Services.AddScoped<Erp.Application.Stock.IStockService, StockService>();
builder.Services.AddScoped<Erp.Application.Finance.IFinanceLedgerService, FinanceLedgerService>();
builder.Services.AddSingleton<Erp.Application.Documents.IPdfRenderer, Erp.Infrastructure.Documents.PuppeteerPdfRenderer>();
builder.Services.AddScoped<Erp.Application.Documents.IDocumentPdfService, Erp.Infrastructure.Documents.DocumentPdfService>();
builder.Services.AddScoped<Erp.Application.Backup.IBackupService, Erp.Infrastructure.Backup.PgDumpBackupService>();
builder.Services.AddHostedService<Erp.Infrastructure.Backup.DailyBackupWorker>();

builder.Services.AddHttpClient();
builder.Services.AddSingleton<Erp.Infrastructure.Whatsapp.WhatsappBridgeLocator>();
// Singleton, not Scoped: it's injected directly into WhatsappOutboxWorker (a singleton hosted
// service) and only depends on other singleton-safe services (IHttpClientFactory, WhatsappBridgeLocator).
builder.Services.AddSingleton<Erp.Infrastructure.Whatsapp.WhatsappSenderService>();
builder.Services.AddHostedService<Erp.Infrastructure.Whatsapp.WhatsappOutboxWorker>();
builder.Services.AddHostedService<Erp.Infrastructure.Discovery.HostDiscoveryBroadcastService>();

builder.Services
    .AddAuthentication(SessionAuthDefaults.Scheme)
    .AddScheme<AuthenticationSchemeOptions, SessionAuthenticationHandler>(SessionAuthDefaults.Scheme, _ => { });

builder.Services.AddAuthorizationBuilder();
builder.Services.PostConfigure<AuthorizationOptions>(options =>
{
    // Any endpoint without an explicit [Authorize]/[AllowAnonymous] still requires a valid session.
    options.FallbackPolicy = new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build();

    // One policy per permission key — [RequirePermission("x")] just references the matching policy name.
    foreach (var (key, _, _) in PermissionKeys.Catalog)
    {
        options.AddPolicy(key, policy => policy.RequireClaim(SessionAuthDefaults.PermissionClaimType, key));
    }
});

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<ErpDbContext>();
    // A packaged install has no dotnet SDK/dotnet-ef tool available to run `database update`
    // by hand, so the published exe applies its own migrations on startup — idempotent via
    // EF's __EFMigrationsHistory table, safe to run on every boot including dev.
    await db.Database.MigrateAsync();
    await DbSeeder.SeedAsync(db);
}

app.UseMiddleware<ExceptionHandlingMiddleware>();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// Deliberately minimal: no connection strings, versions, or other internals — see ARCHITECTURE.md §8.
app.MapGet("/api/health", async (ErpDbContext db, HttpContext ctx) =>
{
    // A Slave/Host client's very first request always lands here (see connection_screen.dart's
    // auto-connect) - logging it to the console makes "is anything even reaching the backend at
    // all" visible immediately during a live debug session, instead of only inferring it from the
    // client-side timeout.
    Console.WriteLine($"[health] request from {ctx.Connection.RemoteIpAddress}:{ctx.Connection.RemotePort} -> {ctx.Request.Host}");

    bool databaseReachable;
    try
    {
        databaseReachable = await db.Database.CanConnectAsync();
    }
    catch (Exception ex)
    {
        databaseReachable = false;
        Console.WriteLine($"[health] database check failed: {ex.Message}");
    }

    Console.WriteLine($"[health] responding: databaseReachable={databaseReachable}");

    return Results.Ok(new
    {
        status = databaseReachable ? "healthy" : "degraded",
        databaseReachable
    });
}).AllowAnonymous();

app.Lifetime.ApplicationStarted.Register(() => Console.WriteLine("[startup] ErpHost is listening on http://0.0.0.0:5000"));

// Pre-warms the PDF renderer's Chromium instance in the background so the multi-second cold launch
// happens once at startup instead of stalling whichever user's click on "View PDF" happens to be
// first — and so a broken install (missing/corrupt Chromium, launch failure) shows up in the startup
// log immediately instead of only surfacing as a confusing failure the first time someone tries to
// print. Fire-and-forget: must not block the Host from coming up and starting to listen.
app.Lifetime.ApplicationStarted.Register(() =>
{
    _ = Task.Run(async () =>
    {
        try
        {
            var renderer = app.Services.GetRequiredService<Erp.Application.Documents.IPdfRenderer>();
            if (renderer is Erp.Infrastructure.Documents.PuppeteerPdfRenderer puppeteerRenderer)
            {
                await puppeteerRenderer.WarmUpAsync();
                Console.WriteLine("[startup] PDF renderer (Chromium) warmed up successfully.");
            }
        }
        catch (Exception ex)
        {
            Console.WriteLine($"[startup] PDF renderer warm-up failed - PDF generation may not work until this is resolved: {ex.Message}");
        }
    });
});

app.Run();
