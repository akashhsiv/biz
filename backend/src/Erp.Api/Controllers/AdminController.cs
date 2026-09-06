using Erp.Api.Auth;
using Erp.Application.Common;
using Erp.Application.Security;
using Erp.Domain.Identity;
using Erp.Domain.Shops;
using Erp.Domain.System;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record CreateShopRequest(string Name, string? Gstin, string? Address, string? ContactNumber);

public record ShopAdminSummaryDto(Guid Id, string Name, string Gstin, string? Address, string? ContactNumber, bool IsActive);

public record CreateShopAdminRequest(string Username, string FullName, string? Password);

public record CreateShopAdminResult(Guid UserId, string Username, string FullName, string Password);

/// <summary>Super-admin-only shop provisioning. Everything here sits above the shop-scoped permission
/// system entirely — gated by [RequireSuperAdmin] (User.IsSuperAdmin), not any PermissionKeys grant —
/// since creating a shop or its first admin has to be possible before any UserShopRole exists for it.</summary>
[ApiController]
[Route("api/admin")]
[RequireSuperAdmin]
public class AdminController(ErpDbContext db) : ControllerBase
{
    /// <summary>Lists every shop regardless of caller's active shop context. Shop itself doesn't
    /// implement IShopScoped (it's the tenant boundary, not a scoped entity) so the global query filter
    /// never touched it anyway — IgnoreQueryFilters() here is just belt-and-braces documentation of
    /// intent, matching the pattern DbSeeder uses elsewhere.</summary>
    [HttpGet("shops")]
    public async Task<ActionResult<IReadOnlyList<ShopAdminSummaryDto>>> GetShops(CancellationToken ct)
    {
        var shops = await db.Shops.IgnoreQueryFilters()
            .OrderBy(s => s.Name)
            .Select(s => new ShopAdminSummaryDto(s.Id, s.Name, s.Gstin, s.Address, s.ContactNumber, s.IsActive))
            .ToListAsync(ct);

        return Ok(shops);
    }

    /// <summary>Creates a new Shop under the single Company row (Company is a one-row tenant table for
    /// the foreseeable future — see Company.cs). Also creates the CompanySettings row every shop needs
    /// (CompanySettingsController/DbSeeder both assume exactly one CompanySettings per shop). Roles
    /// ("Shop Admin"/"Sales Team"/"Purchase Team") are NOT created here — DbSeeder.SeedRolesAsync shows
    /// Role rows are global/shared across shops (looked up by name, with no ShopId), so a new shop reuses
    /// the existing global roles rather than getting its own copies.</summary>
    [HttpPost("shops")]
    public async Task<ActionResult<ShopAdminSummaryDto>> CreateShop(CreateShopRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Name))
            throw new ValidationAppException("Shop name is required.");

        var company = await db.Companies.FirstOrDefaultAsync(ct)
            ?? throw new ConflictAppException("No Company row exists — run the app once so DbSeeder can create it.");

        var shop = new Shop
        {
            Company = company,
            Name = request.Name.Trim(),
            // Gstin is NOT NULL at the DB level (ShopConfiguration); left blank here is a deliberate
            // allowance for provisioning a shop before its GST details are known, to be filled in later
            // via CompanySettingsController rather than blocking creation on it.
            Gstin = request.Gstin?.Trim() ?? string.Empty,
            Address = request.Address?.Trim(),
            ContactNumber = request.ContactNumber?.Trim(),
            IsActive = true,
        };
        db.Shops.Add(shop);

        db.CompanySettings.Add(new CompanySettings
        {
            Shop = shop,
            ShopName = shop.Name,
            Gstin = shop.Gstin,
            Address = shop.Address,
            ContactNumber = shop.ContactNumber,
            State = string.Empty,
        });

        await db.SaveChangesAsync(ct);

        return Ok(new ShopAdminSummaryDto(shop.Id, shop.Name, shop.Gstin, shop.Address, shop.ContactNumber, shop.IsActive));
    }

    /// <summary>Creates a new User (IsSuperAdmin=false) and grants it "Shop Admin" access to the given
    /// shop via UserShopRole. If no password is supplied, a securely random one is generated and
    /// returned in the response — the only place it is ever available in plaintext; only its BCrypt
    /// hash (same mechanism DbSeeder.SeedAdminUserAsync already uses) is persisted.</summary>
    [HttpPost("shops/{shopId:guid}/admins")]
    public async Task<ActionResult<CreateShopAdminResult>> CreateShopAdmin(Guid shopId, CreateShopAdminRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Username))
            throw new ValidationAppException("Username is required.");
        if (string.IsNullOrWhiteSpace(request.FullName))
            throw new ValidationAppException("Full name is required.");

        var shop = await db.Shops.IgnoreQueryFilters().FirstOrDefaultAsync(s => s.Id == shopId, ct)
            ?? throw new ValidationAppException("Shop not found.");

        var usernameTaken = await db.Users.IgnoreQueryFilters().AnyAsync(u => u.Username == request.Username, ct);
        if (usernameTaken)
            throw new ConflictAppException("Username is already taken.");

        var shopAdminRole = await db.Roles.FirstOrDefaultAsync(r => r.Name == "Shop Admin", ct)
            ?? throw new ConflictAppException("\"Shop Admin\" role does not exist — run the app once so DbSeeder can create it.");

        var password = request.Password;
        if (string.IsNullOrWhiteSpace(password))
        {
            password = GenerateRandomPassword();
        }

        var user = new User
        {
            Username = request.Username.Trim(),
            FullName = request.FullName.Trim(),
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(password),
            IsActive = true,
            IsSuperAdmin = false,
            Role = shopAdminRole,
        };
        db.Users.Add(user);

        db.Set<UserShopRole>().Add(new UserShopRole
        {
            User = user,
            Shop = shop,
            Role = shopAdminRole,
        });

        await db.SaveChangesAsync(ct);

        return Ok(new CreateShopAdminResult(user.Id, user.Username, user.FullName, password));
    }

    /// <summary>32 bytes of CSPRNG entropy, URL-safe base64 — same generator shape as
    /// TokenHasher.GenerateRawToken and DbSeeder's super admin seed password.</summary>
    private static string GenerateRandomPassword()
    {
        Span<byte> bytes = stackalloc byte[32];
        System.Security.Cryptography.RandomNumberGenerator.Fill(bytes);
        return Convert.ToBase64String(bytes).Replace('+', '-').Replace('/', '_').TrimEnd('=');
    }
}
