using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;
using Erp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace Erp.Infrastructure.Discovery;

/// <summary>
/// Lets a Slave PC's Connection screen find the Host automatically instead of the admin having to
/// type its IP address by hand. Broadcasts a small UDP announcement on the LAN every few seconds;
/// any Slave listening on the same port picks it up and learns the Host's address from the packet's
/// sender IP, with no reply/handshake needed. Manual entry always remains available as a fallback
/// (e.g. Wi-Fi networks/routers that block broadcast traffic between clients - "AP isolation").
/// </summary>
public class HostDiscoveryBroadcastService(IServiceScopeFactory scopeFactory, ILogger<HostDiscoveryBroadcastService> logger) : BackgroundService
{
    public const int DiscoveryPort = 45678;
    private static readonly TimeSpan BroadcastInterval = TimeSpan.FromSeconds(2);

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // The shop name barely ever changes and this only needs to be "good enough" for a Slave's
        // connection screen - fetch it once at startup rather than hitting the DB every 2 seconds.
        var shopName = await GetShopNameAsync(stoppingToken);

        using var socket = new Socket(AddressFamily.InterNetwork, SocketType.Dgram, ProtocolType.Udp);
        socket.EnableBroadcast = true;

        var payload = JsonSerializer.SerializeToUtf8Bytes(new { type = "ERP_HOST", port = 5000, shopName });
        var endpoint = new IPEndPoint(IPAddress.Broadcast, DiscoveryPort);

        using var timer = new PeriodicTimer(BroadcastInterval);
        do
        {
            try
            {
                await socket.SendToAsync(payload, SocketFlags.None, endpoint, stoppingToken);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                // Non-fatal by design (ARCHITECTURE.md §36 pattern, same as the WhatsApp bridge) -
                // a broadcast failing (e.g. no network adapter up yet) must never affect the Host
                // itself; Slaves just fall back to manual entry until this starts working again.
                logger.LogDebug(ex, "Host discovery broadcast failed - Slaves will need to connect manually until this recovers.");
            }
        } while (await timer.WaitForNextTickAsync(stoppingToken));
    }

    private async Task<string> GetShopNameAsync(CancellationToken ct)
    {
        try
        {
            using var scope = scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<ErpDbContext>();
            var settings = await db.CompanySettings.AsNoTracking().FirstOrDefaultAsync(ct);
            return settings?.ShopName ?? "ERP Host";
        }
        catch
        {
            return "ERP Host";
        }
    }
}
