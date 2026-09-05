using System.Net;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using Erp.Api.Auth;
using Erp.Application.Security;
using Erp.Domain.Common;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record HostStatusDto(
    bool ServerRunning, bool DatabaseConnected, string? LanIp, int Port, string? ConnectionUrl,
    DateTime? LastBackupAt, BackupStatus? LastBackupStatus, int WhatsappQueuedCount, int WhatsappFailedCount,
    int ConnectedSlaveCount);

[ApiController]
[Route("api/host")]
public class HostController(ErpDbContext db) : ControllerBase
{
    private const int Port = 5000;

    // A session counts as "connected" if it's been seen recently — there's no persistent socket to
    // know a Slave is still open, just a heartbeat from every authenticated request it makes.
    private static readonly TimeSpan ConnectedWindow = TimeSpan.FromMinutes(2);

    /// <summary>Deliberately minimal beyond this — no credentials, no internal versions — same rule as /api/health (ARCHITECTURE.md §8).</summary>
    [HttpGet("status")]
    [RequirePermission(PermissionKeys.HostStatusView)]
    public async Task<ActionResult<HostStatusDto>> Status(CancellationToken ct)
    {
        bool dbConnected;
        try { dbConnected = await db.Database.CanConnectAsync(ct); }
        catch { dbConnected = false; }

        var lanIp = GetLanIpAddress();
        var connectionUrl = lanIp is null ? null : $"http://{lanIp}:{Port}";

        var lastBackup = await db.BackupHistories.OrderByDescending(b => b.CreatedAt).FirstOrDefaultAsync(ct);

        var whatsappQueued = await db.WhatsappOutboxItems.CountAsync(w => w.Status == WhatsappOutboxStatus.Queued, ct);
        var whatsappFailed = await db.WhatsappOutboxItems.CountAsync(w => w.Status == WhatsappOutboxStatus.Failed, ct);

        var cutoff = DateTime.UtcNow - ConnectedWindow;
        var connectedSlaveCount = await db.Sessions.CountAsync(
            s => s.RevokedAt == null && s.ExpiresAt > DateTime.UtcNow && s.LastSeenAt != null && s.LastSeenAt > cutoff, ct);

        return Ok(new HostStatusDto(
            true, dbConnected, lanIp, Port, connectionUrl,
            lastBackup?.CreatedAt, lastBackup?.Status, whatsappQueued, whatsappFailed, connectedSlaveCount));
    }

    private static string? GetLanIpAddress()
    {
        foreach (var nic in NetworkInterface.GetAllNetworkInterfaces())
        {
            if (nic.OperationalStatus != OperationalStatus.Up) continue;
            if (nic.NetworkInterfaceType is NetworkInterfaceType.Loopback or NetworkInterfaceType.Tunnel) continue;

            foreach (var addr in nic.GetIPProperties().UnicastAddresses)
            {
                if (addr.Address.AddressFamily != AddressFamily.InterNetwork) continue;
                if (IPAddress.IsLoopback(addr.Address)) continue;
                if (addr.Address.ToString().StartsWith("169.254.")) continue; // link-local/APIPA, not a real LAN address

                return addr.Address.ToString();
            }
        }

        return null;
    }
}
