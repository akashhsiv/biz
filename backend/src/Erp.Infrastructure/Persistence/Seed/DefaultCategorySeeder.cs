using Erp.Domain.Items;
using Erp.Domain.Shops;
using Microsoft.EntityFrameworkCore;

namespace Erp.Infrastructure.Persistence.Seed;

/// <summary>Ensures every shop has a default "Cash Bill" ItemCategory — used for walk-in/cash sales
/// that don't fit any of the shop's real business categories (Paint, Iron, Plumbing, etc.). Called from
/// both DbSeeder (for the default shop created on first run) and AdminController.CreateShop (for a new
/// shop, same transaction/SaveChanges as the rest of shop provisioning — no extra round trip).
///
/// Judgment call: identified purely by Name == "Cash Bill" per shop, with no IsDefault/protected flag —
/// simplest thing that works for now. If a user renames or deletes this category later there is nothing
/// stopping a duplicate "Cash Bill" category being created on the next call; that is an accepted
/// simplification for this iteration, not an oversight.</summary>
public static class DefaultCategorySeeder
{
    public const string CashBillCategoryName = "Cash Bill";

    public static async Task EnsureCashBillCategoryAsync(ErpDbContext db, Shop shop, CancellationToken ct = default)
    {
        var exists = await db.ItemCategories.IgnoreQueryFilters()
            .AnyAsync(c => c.ShopId == shop.Id && c.Name == CashBillCategoryName, ct);
        if (exists) return;

        db.ItemCategories.Add(new ItemCategory
        {
            ShopId = shop.Id,
            Name = CashBillCategoryName,
            IsActive = true,
        });
    }
}
