using Erp.Application.Security;
using Erp.Domain.Identity;
using Erp.Domain.System;
using Microsoft.EntityFrameworkCore;

namespace Erp.Infrastructure.Persistence.Seed;

/// <summary>Idempotent seed data: roles, the permission catalog, role grants per ARCHITECTURE.md §5, a default company profile, and one initial Shop Admin login. Safe to run on every startup.</summary>
public static class DbSeeder
{
    private static readonly string[] SalesTeamGrants =
    [
        PermissionKeys.CustomersView, PermissionKeys.CustomersManage,
        PermissionKeys.ItemsView,
        PermissionKeys.QuotationsManage, PermissionKeys.ProformasManage, PermissionKeys.SalesInvoicesManage,
        PermissionKeys.SalesReturnsRequest,
        PermissionKeys.CustomerDepositsRecord,
        PermissionKeys.StockView,
        PermissionKeys.ReportsSalesView,
    ];

    private static readonly string[] PurchaseTeamGrants =
    [
        PermissionKeys.CustomersView,
        PermissionKeys.ItemsView,
        PermissionKeys.PurchaseOrdersManage, PermissionKeys.PurchaseReceiptsManage, PermissionKeys.PurchasePaymentsInitiate,
        PermissionKeys.StockView,
        PermissionKeys.ReportsPurchaseView,
    ];

    public static async Task SeedAsync(ErpDbContext db, CancellationToken ct = default)
    {
        var permissionsByKey = await SeedPermissionsAsync(db, ct);
        var (shopAdmin, salesTeam, purchaseTeam) = await SeedRolesAsync(db, ct);

        await GrantAllAsync(db, shopAdmin, permissionsByKey.Values, ct);
        await GrantAsync(db, salesTeam, permissionsByKey, SalesTeamGrants, ct);
        await GrantAsync(db, purchaseTeam, permissionsByKey, PurchaseTeamGrants, ct);

        await SeedCompanySettingsAsync(db, ct);
        await SeedAdminUserAsync(db, shopAdmin, ct);

        await db.SaveChangesAsync(ct);
    }

    private static async Task<Dictionary<string, Permission>> SeedPermissionsAsync(ErpDbContext db, CancellationToken ct)
    {
        var existing = await db.Permissions.ToDictionaryAsync(p => p.Key, ct);

        foreach (var (key, module, description) in PermissionKeys.Catalog)
        {
            if (existing.ContainsKey(key)) continue;

            var permission = new Permission { Key = key, Module = module, Description = description };
            db.Permissions.Add(permission);
            existing[key] = permission;
        }

        return existing;
    }

    private static async Task<(Role ShopAdmin, Role SalesTeam, Role PurchaseTeam)> SeedRolesAsync(ErpDbContext db, CancellationToken ct)
    {
        var roles = await db.Roles.ToDictionaryAsync(r => r.Name, ct);

        Role GetOrAdd(string name)
        {
            if (roles.TryGetValue(name, out var role)) return role;
            role = new Role { Name = name, IsSystemRole = true };
            db.Roles.Add(role);
            roles[name] = role;
            return role;
        }

        return (GetOrAdd("Shop Admin"), GetOrAdd("Sales Team"), GetOrAdd("Purchase Team"));
    }

    private static async Task GrantAllAsync(ErpDbContext db, Role role, IEnumerable<Permission> permissions, CancellationToken ct)
        => await GrantAsync(db, role, permissions.ToDictionary(p => p.Key), permissions.Select(p => p.Key), ct);

    private static async Task GrantAsync(ErpDbContext db, Role role, Dictionary<string, Permission> permissionsByKey, IEnumerable<string> keys, CancellationToken ct)
    {
        // Existing grants for this role — avoid re-inserting on every startup.
        var existingGrants = (await db.RolePermissions
            .Where(rp => rp.RoleId == role.Id)
            .Select(rp => rp.PermissionId)
            .ToListAsync(ct)).ToHashSet();

        foreach (var key in keys)
        {
            var permission = permissionsByKey[key];
            if (existingGrants.Contains(permission.Id)) continue;

            db.RolePermissions.Add(new RolePermission { Role = role, Permission = permission });
        }
    }

    private static async Task SeedCompanySettingsAsync(ErpDbContext db, CancellationToken ct)
    {
        if (await db.CompanySettings.AnyAsync(ct)) return;

        db.CompanySettings.Add(new CompanySettings
        {
            ShopName = "My Shop",
            Gstin = "00AAAAA0000A1Z5",
            State = "Karnataka",
        });
    }

    private static async Task SeedAdminUserAsync(ErpDbContext db, Role shopAdmin, CancellationToken ct)
    {
        if (await db.Users.AnyAsync(ct)) return;

        db.Users.Add(new User
        {
            Username = "admin",
            FullName = "Shop Administrator",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("ChangeMe123!"),
            IsActive = true,
            Role = shopAdmin,
        });
    }
}
