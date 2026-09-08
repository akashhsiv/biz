using System.Security.Cryptography;
using Erp.Application.Security;
using Erp.Domain.Identity;
using Erp.Domain.Shops;
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
        PermissionKeys.SalesInvoicesManage,
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
        var superAdminRole = await SeedSuperAdminRoleAsync(db, ct);

        await GrantAllAsync(db, shopAdmin, permissionsByKey.Values, ct);
        await GrantAsync(db, salesTeam, permissionsByKey, SalesTeamGrants, ct);
        await GrantAsync(db, purchaseTeam, permissionsByKey, PurchaseTeamGrants, ct);
        // Deliberately no grants for Super Admin's legacy Role — a super admin is authorized via
        // User.IsSuperAdmin / [RequireSuperAdmin], not the shop permission-claim system, and normally
        // has no UserShopRole at all. The Role row exists only to satisfy User.RoleId's FK.

        var defaultShop = await SeedDefaultCompanyAndShopAsync(db, ct);
        await SeedCompanySettingsAsync(db, defaultShop, ct);
        var admin = await SeedAdminUserAsync(db, shopAdmin, ct);
        await SeedAdminUserShopRoleAsync(db, admin, defaultShop, shopAdmin, ct);
        await SeedSuperAdminUserAsync(db, superAdminRole, ct);

        await db.SaveChangesAsync(ct);
    }

    /// <summary>Multi-shop rework: a fresh database gets one Company and one Shop so existing
    /// single-shop behaviour keeps working with no manual setup step. IShopScoped's query filter is a
    /// no-op until a session selects a shop, so this seed alone doesn't force anyone through
    /// select-shop — it just gives them exactly one shop to pick.</summary>
    private static async Task<Shop> SeedDefaultCompanyAndShopAsync(ErpDbContext db, CancellationToken ct)
    {
        var existingShop = await db.Shops.IgnoreQueryFilters().FirstOrDefaultAsync(ct);
        if (existingShop is not null) return existingShop;

        var company = new Company { Name = "My Company" };
        db.Companies.Add(company);

        var shop = new Shop
        {
            Company = company,
            Name = "My Shop",
            Gstin = "00AAAAA0000A1Z5",
            IsActive = true,
        };
        db.Shops.Add(shop);

        return shop;
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

    /// <summary>Roles are global (shared across shops, per SeedRolesAsync above) — this adds one more
    /// global role purely to satisfy User.RoleId's required FK for super admin users, who are
    /// authorized via User.IsSuperAdmin instead of any permission this role might carry.</summary>
    private static async Task<Role> SeedSuperAdminRoleAsync(ErpDbContext db, CancellationToken ct)
    {
        var existing = await db.Roles.FirstOrDefaultAsync(r => r.Name == "Super Admin", ct);
        if (existing is not null) return existing;

        var role = new Role { Name = "Super Admin", IsSystemRole = true, Description = "Provisions shops and Shop Admins; carries no shop permissions." };
        db.Roles.Add(role);
        return role;
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

    private static async Task SeedCompanySettingsAsync(ErpDbContext db, Shop shop, CancellationToken ct)
    {
        if (await db.CompanySettings.IgnoreQueryFilters().AnyAsync(x => x.ShopId == shop.Id, ct)) return;

        db.CompanySettings.Add(new CompanySettings
        {
            Shop = shop,
            ShopName = shop.Name,
            Gstin = shop.Gstin,
            State = "Karnataka",
        });
    }

    /// <returns>The admin user — newly created, or the existing one if seeding already ran.</returns>
    private static async Task<User> SeedAdminUserAsync(ErpDbContext db, Role shopAdmin, CancellationToken ct)
    {
        var existing = await db.Users.IgnoreQueryFilters().FirstOrDefaultAsync(u => u.Username == "admin", ct);
        if (existing is not null) return existing;

        var admin = new User
        {
            Username = "admin",
            FullName = "Shop Administrator",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("ChangeMe123!"),
            IsActive = true,
            Role = shopAdmin,
        };
        db.Users.Add(admin);
        return admin;
    }

    /// <summary>Grants the seeded admin Shop Admin access to the default shop via UserShopRole — the
    /// mechanism that replaces User.RoleId for authorization going forward (see UserShopRole.cs).</summary>
    private static async Task SeedAdminUserShopRoleAsync(ErpDbContext db, User admin, Shop shop, Role shopAdmin, CancellationToken ct)
    {
        var alreadyGranted = await db.Set<UserShopRole>().IgnoreQueryFilters().AnyAsync(x => x.UserId == admin.Id && x.ShopId == shop.Id, ct);
        if (alreadyGranted) return;

        db.Set<UserShopRole>().Add(new UserShopRole
        {
            User = admin,
            Shop = shop,
            Role = shopAdmin,
        });
    }

    /// <summary>Seeds the one super admin login used to bootstrap shop provisioning (api/admin). Unlike
    /// the Shop Admin seed above, this account has no fixed default password — it has no shop scoping
    /// so a well-known credential here would be a much bigger blast radius than "admin"/ChangeMe123!.
    /// A fresh random password is generated and printed to the console on first run only; it is never
    /// stored or logged anywhere else, so whoever runs the backend for the first time must note it down
    /// then (it can always be reset by an operator with direct DB access afterwards).</summary>
    private static async Task SeedSuperAdminUserAsync(ErpDbContext db, Role superAdminRole, CancellationToken ct)
    {
        var existing = await db.Users.IgnoreQueryFilters().FirstOrDefaultAsync(u => u.Username == "superadmin", ct);
        if (existing is not null) return;

        var password = GenerateRandomPassword();

        var superAdmin = new User
        {
            Username = "superadmin",
            FullName = "Super Administrator",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(password),
            IsActive = true,
            IsSuperAdmin = true,
            Role = superAdminRole,
        };
        db.Users.Add(superAdmin);

        Console.WriteLine("========================================================================");
        Console.WriteLine("[seed] Created super admin login (first run only — save this password now):");
        Console.WriteLine($"[seed]   username: superadmin");
        Console.WriteLine($"[seed]   password: {password}");
        Console.WriteLine("[seed] This password will not be shown again. Reset it via the database if lost.");
        Console.WriteLine("========================================================================");
    }

    /// <summary>32 bytes (256 bits) of CSPRNG entropy, URL-safe base64 encoded — well above the 16
    /// bytes the caller asked for as a minimum, and generated the same way TokenHasher.GenerateRawToken
    /// generates session tokens.</summary>
    private static string GenerateRandomPassword()
    {
        Span<byte> bytes = stackalloc byte[32];
        RandomNumberGenerator.Fill(bytes);
        return Convert.ToBase64String(bytes).Replace('+', '-').Replace('/', '_').TrimEnd('=');
    }
}
