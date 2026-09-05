using Erp.Api.Auth;
using Erp.Application.Common;
using Erp.Application.Security;
using Erp.Domain.Notifications;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record NotificationSettingsDto(
    bool LowStockWhatsapp, bool LowStockMobile,
    bool PurchaseDueWhatsapp, bool PurchaseDueMobile,
    bool PurchaseOverdueWhatsapp, bool PurchaseOverdueMobile,
    bool CustomerOutstandingWhatsapp, bool CustomerOutstandingMobile);

public record UpdateNotificationSettingsRequest(
    bool LowStockWhatsapp, bool LowStockMobile,
    bool PurchaseDueWhatsapp, bool PurchaseDueMobile,
    bool PurchaseOverdueWhatsapp, bool PurchaseOverdueMobile,
    bool CustomerOutstandingWhatsapp, bool CustomerOutstandingMobile);

/// <summary>Per-shop notification channel matrix (Biz_Product_Requirements.md §23) — mirrors
/// CompanySettingsController's get-or-create-singleton pattern, except this singleton is per-shop
/// (ShopId is stamped/filtered automatically like every other IShopScoped entity) rather than global.</summary>
[ApiController]
[Route("api/notification-settings")]
public class NotificationSettingsController(ErpDbContext db, ICurrentUserService currentUser) : ControllerBase
{
    [HttpGet]
    [RequirePermission(PermissionKeys.NotificationSettingsView)]
    public async Task<ActionResult<NotificationSettingsDto>> Get(CancellationToken ct)
    {
        var settings = await GetOrCreateAsync(ct);
        return Ok(ToDto(settings));
    }

    [HttpPut]
    [RequirePermission(PermissionKeys.NotificationSettingsManage)]
    public async Task<ActionResult<NotificationSettingsDto>> Update(UpdateNotificationSettingsRequest request, CancellationToken ct)
    {
        var settings = await GetOrCreateAsync(ct);

        settings.LowStockWhatsapp = request.LowStockWhatsapp;
        settings.LowStockMobile = request.LowStockMobile;
        settings.PurchaseDueWhatsapp = request.PurchaseDueWhatsapp;
        settings.PurchaseDueMobile = request.PurchaseDueMobile;
        settings.PurchaseOverdueWhatsapp = request.PurchaseOverdueWhatsapp;
        settings.PurchaseOverdueMobile = request.PurchaseOverdueMobile;
        settings.CustomerOutstandingWhatsapp = request.CustomerOutstandingWhatsapp;
        settings.CustomerOutstandingMobile = request.CustomerOutstandingMobile;

        await db.SaveChangesAsync(ct);
        return Ok(ToDto(settings));
    }

    private async Task<ShopNotificationSettings> GetOrCreateAsync(CancellationToken ct)
    {
        var shopId = currentUser.CurrentShopId
            ?? throw new ConflictAppException("Select a shop before viewing notification settings.");

        var settings = await db.ShopNotificationSettings.FirstOrDefaultAsync(s => s.ShopId == shopId, ct);
        if (settings is not null) return settings;

        settings = new ShopNotificationSettings { ShopId = shopId };
        db.ShopNotificationSettings.Add(settings);
        await db.SaveChangesAsync(ct);
        return settings;
    }

    private static NotificationSettingsDto ToDto(ShopNotificationSettings s) => new(
        s.LowStockWhatsapp, s.LowStockMobile,
        s.PurchaseDueWhatsapp, s.PurchaseDueMobile,
        s.PurchaseOverdueWhatsapp, s.PurchaseOverdueMobile,
        s.CustomerOutstandingWhatsapp, s.CustomerOutstandingMobile);
}
