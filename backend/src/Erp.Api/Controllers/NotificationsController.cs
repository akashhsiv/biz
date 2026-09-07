using Erp.Application.Common;
using Erp.Domain.Notifications;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record NotificationEventDto(
    Guid Id,
    string EventType,
    string PayloadJson,
    string Status,
    DateTime CreatedAt,
    DateTime? ReadAt);

public record UnreadCountDto(int Count);

public record RegisterDeviceTokenRequest(string Token, string Platform);

/// <summary>In-app notification inbox — the read-side of the generic notification engine (see
/// Erp.Domain.Notifications, NotificationDispatcher). Every signed-in user in a shop sees that shop's
/// feed; there's no per-user read state (see NotificationEvent.ReadAt's doc comment), so this only
/// requires an authenticated session, not a specific permission — reading your own shop's
/// notifications isn't a privileged action the way editing settings is.</summary>
[ApiController]
[Route("api/notifications")]
[Authorize]
public class NotificationsController(ErpDbContext db, ICurrentUserService currentUser) : ControllerBase
{
    [HttpGet]
    public async Task<ActionResult<IReadOnlyList<NotificationEventDto>>> List(
        [FromQuery] int page = 1, [FromQuery] int pageSize = 50, [FromQuery] bool unreadOnly = false, CancellationToken ct = default)
    {
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 200);

        var query = db.NotificationEvents.AsNoTracking().AsQueryable();
        if (unreadOnly) query = query.Where(e => e.ReadAt == null);

        var items = await query
            .OrderByDescending(e => e.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(e => new NotificationEventDto(
                e.Id, e.EventType.ToString(), e.PayloadJson, e.Status.ToString(), e.CreatedAt, e.ReadAt))
            .ToListAsync(ct);

        return Ok(items);
    }

    [HttpGet("unread-count")]
    public async Task<ActionResult<UnreadCountDto>> UnreadCount(CancellationToken ct)
    {
        var count = await db.NotificationEvents.AsNoTracking().CountAsync(e => e.ReadAt == null, ct);
        return Ok(new UnreadCountDto(count));
    }

    [HttpPost("{id:guid}/read")]
    public async Task<IActionResult> MarkRead(Guid id, CancellationToken ct)
    {
        var evt = await db.NotificationEvents.FirstOrDefaultAsync(e => e.Id == id, ct);
        if (evt is null) return NotFound();

        evt.ReadAt ??= DateTime.UtcNow; // idempotent — a second call doesn't move the timestamp.
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    [HttpPost("read-all")]
    public async Task<IActionResult> MarkAllRead(CancellationToken ct)
    {
        var unread = await db.NotificationEvents.Where(e => e.ReadAt == null).ToListAsync(ct);
        var now = DateTime.UtcNow;
        foreach (var evt in unread) evt.ReadAt = now;
        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    [HttpPost("device-tokens")]
    public async Task<IActionResult> RegisterDeviceToken(RegisterDeviceTokenRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Token))
            throw new ValidationAppException("Token is required.");
        if (string.IsNullOrWhiteSpace(request.Platform))
            throw new ValidationAppException("Platform is required.");

        var shopId = currentUser.CurrentShopId
            ?? throw new ConflictAppException("Select a shop before registering a device token.");

        // IgnoreQueryFilters: Token is globally unique regardless of shop (see DeviceTokenConfiguration),
        // so a device re-registering after switching shops must still be found here rather than
        // silently attempting a duplicate insert that then fails the unique index.
        var existing = await db.DeviceTokens.IgnoreQueryFilters().FirstOrDefaultAsync(t => t.Token == request.Token, ct);
        if (existing is not null)
        {
            // Upsert on Token: the device (not the row) is the identity — re-registering the same
            // token under a different user/shop just repoints it rather than creating a duplicate.
            existing.UserId = currentUser.UserId;
            existing.ShopId = shopId;
            existing.Platform = request.Platform;
            existing.LastSeenAt = DateTime.UtcNow;
        }
        else
        {
            db.DeviceTokens.Add(new DeviceToken
            {
                ShopId = shopId,
                UserId = currentUser.UserId,
                Token = request.Token,
                Platform = request.Platform,
                LastSeenAt = DateTime.UtcNow,
                CreatedBy = currentUser.UserId,
                CreatedAt = DateTime.UtcNow,
            });
        }

        await db.SaveChangesAsync(ct);
        return NoContent();
    }
}
