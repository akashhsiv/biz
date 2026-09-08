using Erp.Api.Auth;
using Erp.Application.Common;
using Erp.Application.Security;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record CompanySettingsDto(
    string ShopName, string Gstin, string State, string? Address, string? ContactNumber,
    string? BankName, string? BankAccountNumber, string? BankIfscCode, string? BankBranch, string? UpiId,
    bool HasLogo, bool HasSignature,
    bool ShowLogoOnDocuments, bool ShowSignatureBlock,
    string? SalesInvoiceTermsAndConditions, string? SalesInvoiceFooterNote,
    string? PurchaseOrderTermsAndConditions, string? PurchaseOrderFooterNote,
    string? WhatsappSalesInvoiceMessageTemplate, string? WhatsappDepositReceiptMessageTemplate);

public record UpdateCompanySettingsRequest(
    string ShopName, string Gstin, string State, string? Address, string? ContactNumber,
    string? BankName, string? BankAccountNumber, string? BankIfscCode, string? BankBranch, string? UpiId,
    bool ShowLogoOnDocuments, bool ShowSignatureBlock,
    string? SalesInvoiceTermsAndConditions, string? SalesInvoiceFooterNote,
    string? PurchaseOrderTermsAndConditions, string? PurchaseOrderFooterNote,
    string? WhatsappSalesInvoiceMessageTemplate, string? WhatsappDepositReceiptMessageTemplate);

public record UpdateLogoRequest(string LogoBase64);
public record UpdateSignatureRequest(string SignatureBase64);

/// <summary>Single shop/GST profile (confirmed decision) — every authenticated user can view this
/// (it's just branding, shown in the app's nav header), only Admin can edit it.</summary>
[ApiController]
[Route("api/company-settings")]
public class CompanySettingsController(ErpDbContext db) : ControllerBase
{
    [HttpGet]
    [Authorize]
    public async Task<ActionResult<CompanySettingsDto>> Get(CancellationToken ct)
    {
        var settings = await db.CompanySettings.AsNoTracking().FirstOrDefaultAsync(ct)
            ?? throw new ConflictAppException("Company settings have not been configured.");

        return Ok(ToDto(settings));
    }

    [HttpGet("logo")]
    [Authorize]
    public async Task<IActionResult> GetLogo(CancellationToken ct)
    {
        var settings = await db.CompanySettings.AsNoTracking().FirstOrDefaultAsync(ct);
        if (settings?.Logo is null) return NotFound();

        return File(settings.Logo, "image/png");
    }

    [HttpGet("signature")]
    [Authorize]
    public async Task<IActionResult> GetSignature(CancellationToken ct)
    {
        var settings = await db.CompanySettings.AsNoTracking().FirstOrDefaultAsync(ct);
        if (settings?.Signature is null) return NotFound();

        return File(settings.Signature, "image/png");
    }

    [HttpPut]
    [RequirePermission(PermissionKeys.CompanySettingsManage)]
    public async Task<ActionResult<CompanySettingsDto>> Update(UpdateCompanySettingsRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.ShopName) || string.IsNullOrWhiteSpace(request.Gstin) || string.IsNullOrWhiteSpace(request.State))
            throw new ValidationAppException("Shop name, GSTIN, and state are required.");

        var settings = await db.CompanySettings.FirstOrDefaultAsync(ct)
            ?? throw new ConflictAppException("Company settings have not been configured.");

        settings.ShopName = request.ShopName;
        settings.Gstin = request.Gstin;
        settings.State = request.State;
        settings.Address = request.Address;
        settings.ContactNumber = request.ContactNumber;
        settings.BankName = request.BankName;
        settings.BankAccountNumber = request.BankAccountNumber;
        settings.BankIfscCode = request.BankIfscCode;
        settings.BankBranch = request.BankBranch;
        settings.UpiId = request.UpiId;
        settings.ShowLogoOnDocuments = request.ShowLogoOnDocuments;
        settings.ShowSignatureBlock = request.ShowSignatureBlock;
        settings.SalesInvoiceTermsAndConditions = request.SalesInvoiceTermsAndConditions;
        settings.SalesInvoiceFooterNote = request.SalesInvoiceFooterNote;
        settings.PurchaseOrderTermsAndConditions = request.PurchaseOrderTermsAndConditions;
        settings.PurchaseOrderFooterNote = request.PurchaseOrderFooterNote;
        settings.WhatsappSalesInvoiceMessageTemplate = request.WhatsappSalesInvoiceMessageTemplate;
        settings.WhatsappDepositReceiptMessageTemplate = request.WhatsappDepositReceiptMessageTemplate;

        await db.SaveChangesAsync(ct);

        return Ok(ToDto(settings));
    }

    [HttpPut("logo")]
    [RequirePermission(PermissionKeys.CompanySettingsManage)]
    public async Task<IActionResult> UpdateLogo(UpdateLogoRequest request, CancellationToken ct)
    {
        var settings = await db.CompanySettings.FirstOrDefaultAsync(ct)
            ?? throw new ConflictAppException("Company settings have not been configured.");

        try
        {
            settings.Logo = Convert.FromBase64String(request.LogoBase64);
        }
        catch (FormatException)
        {
            throw new ValidationAppException("LogoBase64 is not valid base64 image data.");
        }

        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    [HttpPut("signature")]
    [RequirePermission(PermissionKeys.CompanySettingsManage)]
    public async Task<IActionResult> UpdateSignature(UpdateSignatureRequest request, CancellationToken ct)
    {
        var settings = await db.CompanySettings.FirstOrDefaultAsync(ct)
            ?? throw new ConflictAppException("Company settings have not been configured.");

        try
        {
            settings.Signature = Convert.FromBase64String(request.SignatureBase64);
        }
        catch (FormatException)
        {
            throw new ValidationAppException("SignatureBase64 is not valid base64 image data.");
        }

        await db.SaveChangesAsync(ct);
        return NoContent();
    }

    private static CompanySettingsDto ToDto(Erp.Domain.System.CompanySettings s) => new(
        s.ShopName, s.Gstin, s.State, s.Address, s.ContactNumber,
        s.BankName, s.BankAccountNumber, s.BankIfscCode, s.BankBranch, s.UpiId,
        s.Logo is not null, s.Signature is not null,
        s.ShowLogoOnDocuments, s.ShowSignatureBlock,
        s.SalesInvoiceTermsAndConditions, s.SalesInvoiceFooterNote,
        s.PurchaseOrderTermsAndConditions, s.PurchaseOrderFooterNote,
        s.WhatsappSalesInvoiceMessageTemplate, s.WhatsappDepositReceiptMessageTemplate);
}
