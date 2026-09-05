using System.Net.Http.Json;
using Erp.Api.Auth;
using Erp.Application.Common;
using Erp.Application.Documents;
using Erp.Application.Security;
using Erp.Domain.Common;
using Erp.Domain.Whatsapp;
using Erp.Infrastructure.Persistence;
using Erp.Infrastructure.Whatsapp;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record SendWhatsappRequest(WhatsappMessageType MessageType, DocumentReferenceType ReferenceType, Guid ReferenceId, string RecipientNumber, string? CustomMessage);
public record WhatsappOutboxDto(Guid Id, WhatsappMessageType MessageType, string RecipientNumber, WhatsappOutboxStatus Status, int Attempts, string? LastError, DateTime? SentAt, DateTime CreatedAt);
public record WhatsappStatusDto(bool BaileysReachable, bool Connected, string? Qr, int QueuedCount, int SentCount, int FailedCount, string? ConfiguredUrl);
public record TestSendRequest(string RecipientNumber, string Message);
public record TestSendResultDto(bool Success, string? Error);

/// <summary>
/// Admin explicitly triggers every send (manual, confirmed decision — no auto-send on document
/// creation). Queuing here never touches the transaction that created the referenced document —
/// ARCHITECTURE.md §36/§37.
/// </summary>
[ApiController]
[Route("api/whatsapp")]
public class WhatsappController(ErpDbContext db, ICurrentUserService currentUser, IHttpClientFactory httpClientFactory, WhatsappBridgeLocator bridgeLocator, WhatsappSenderService sender, IDocumentPdfService pdfService) : ControllerBase
{
    /// <summary>Attempts delivery immediately (confirmed decision 2026-08-28) instead of always
    /// waiting for WhatsappOutboxWorker's up-to-30s poll — the outbox row is still created either
    /// way, so a failed immediate attempt just falls back to the existing queue/retry behavior.</summary>
    [HttpPost("send")]
    [RequirePermission(PermissionKeys.WhatsappManage)]
    public async Task<ActionResult<WhatsappOutboxDto>> Send(SendWhatsappRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.RecipientNumber))
            throw new ValidationAppException("A recipient number is required.");

        var recipientNumber = ToInternationalNumber(request.RecipientNumber);
        var (message, pdf) = await BuildMessageAsync(request, ct);
        var payloadJson = pdf is null
            ? System.Text.Json.JsonSerializer.Serialize(new { to = recipientNumber, message })
            : System.Text.Json.JsonSerializer.Serialize(new { to = recipientNumber, message, documentBase64 = Convert.ToBase64String(pdf.Bytes), fileName = pdf.FileName });

        var item = new WhatsappOutboxItem
        {
            MessageType = request.MessageType,
            ReferenceType = request.ReferenceType,
            ReferenceId = request.ReferenceId,
            RecipientNumber = recipientNumber,
            PayloadJson = payloadJson,
            Status = WhatsappOutboxStatus.Queued,
            CreatedBy = currentUser.UserId,
            CreatedAt = DateTime.UtcNow,
        };

        var (success, error) = await sender.TrySendAsync(payloadJson, ct);
        if (success)
        {
            item.Status = WhatsappOutboxStatus.Sent;
            item.SentAt = DateTime.UtcNow;
            item.Attempts = 1;
        }
        else
        {
            item.LastError = error;
        }

        db.WhatsappOutboxItems.Add(item);
        await db.SaveChangesAsync(ct);

        return Ok(ToDto(item));
    }

    /// <summary>Connectivity check only - no outbox row, not tied to any document. Lets an admin
    /// confirm the bridge actually delivers before relying on it for real documents.</summary>
    [HttpPost("test-send")]
    [RequirePermission(PermissionKeys.WhatsappManage)]
    public async Task<ActionResult<TestSendResultDto>> TestSend(TestSendRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.RecipientNumber) || string.IsNullOrWhiteSpace(request.Message))
            throw new ValidationAppException("A recipient number and message are required.");

        var payloadJson = System.Text.Json.JsonSerializer.Serialize(new { to = ToInternationalNumber(request.RecipientNumber), message = request.Message });
        var (success, error) = await sender.TrySendAsync(payloadJson, ct);

        return Ok(new TestSendResultDto(success, error));
    }

    [HttpGet("outbox")]
    [RequirePermission(PermissionKeys.WhatsappManage)]
    public async Task<ActionResult<List<WhatsappOutboxDto>>> Outbox(CancellationToken ct)
    {
        var items = await db.WhatsappOutboxItems.OrderByDescending(w => w.CreatedAt).Take(200).ToListAsync(ct);
        return Ok(items.Select(ToDto));
    }

    /// <summary>No permission requirement beyond being logged in (global FallbackPolicy already
    /// requires that) - every Slave user should be able to see at a glance whether WhatsApp is
    /// connected, even a role that can't manage sending. Deliberately minimal: just the two booleans,
    /// not the outbox counts or QR code the full /status endpoint exposes to admins.</summary>
    [HttpGet("connection-status")]
    public async Task<ActionResult<object>> ConnectionStatus(CancellationToken ct)
    {
        var (reachable, connected, _) = await GetBaileysStatusAsync(ct);
        return Ok(new { reachable, connected });
    }

    [HttpGet("status")]
    [RequirePermission(PermissionKeys.WhatsappManage)]
    public async Task<ActionResult<WhatsappStatusDto>> Status(CancellationToken ct)
    {
        var (reachable, connected, qr) = await GetBaileysStatusAsync(ct);

        var queued = await db.WhatsappOutboxItems.CountAsync(w => w.Status == WhatsappOutboxStatus.Queued, ct);
        var sent = await db.WhatsappOutboxItems.CountAsync(w => w.Status == WhatsappOutboxStatus.Sent, ct);
        var failed = await db.WhatsappOutboxItems.CountAsync(w => w.Status == WhatsappOutboxStatus.Failed, ct);

        var configuredUrl = bridgeLocator.BaseUrl;
        return Ok(new WhatsappStatusDto(reachable, connected, qr, queued, sent, failed, string.IsNullOrWhiteSpace(configuredUrl) ? null : configuredUrl));
    }

    /// <summary>Deletes the linked session on the Baileys bridge so it re-emits a fresh pairing
    /// QR - used when a shop switches phones or the device gets unlinked from WhatsApp itself.</summary>
    [HttpPost("logout")]
    [RequirePermission(PermissionKeys.WhatsappManage)]
    public async Task<IActionResult> Logout(CancellationToken ct)
    {
        var baseUrl = bridgeLocator.BaseUrl;
        if (string.IsNullOrWhiteSpace(baseUrl))
            throw new ConflictAppException("The WhatsApp bridge URL is not configured.");

        try
        {
            var client = httpClientFactory.CreateClient();
            client.Timeout = TimeSpan.FromSeconds(5);
            await client.PostAsync($"{baseUrl.TrimEnd('/')}/logout", null, ct);
        }
        catch (Exception ex)
        {
            throw new ConflictAppException($"Could not reach the WhatsApp bridge: {ex.Message}");
        }

        return NoContent();
    }

    private async Task<(bool Reachable, bool Connected, string? Qr)> GetBaileysStatusAsync(CancellationToken ct)
    {
        var baseUrl = bridgeLocator.BaseUrl;
        if (string.IsNullOrWhiteSpace(baseUrl)) return (false, false, null);

        try
        {
            var client = httpClientFactory.CreateClient();
            client.Timeout = TimeSpan.FromSeconds(3);
            var response = await client.GetAsync($"{baseUrl.TrimEnd('/')}/status", ct);
            if (!response.IsSuccessStatusCode) return (false, false, null);

            var payload = await response.Content.ReadFromJsonAsync<BaileysStatusPayload>(cancellationToken: ct);
            return (true, payload?.Connected ?? false, payload?.Qr);
        }
        catch
        {
            return (false, false, null);
        }
    }

    private record BaileysStatusPayload(bool Connected, string? Qr);

    /// <summary>Returns the message text and, for a document-backed type (Quotation/Proforma/
    /// Sales Invoice), the rendered PDF to attach — the same PDF the "Export PDF" button on that
    /// document produces, reused via IDocumentPdfService rather than re-implemented here.</summary>
    private async Task<(string Message, PdfResult? Pdf)> BuildMessageAsync(SendWhatsappRequest request, CancellationToken ct)
    {
        if (request.MessageType == WhatsappMessageType.Custom)
        {
            if (string.IsNullOrWhiteSpace(request.CustomMessage))
                throw new ValidationAppException("CustomMessage is required for a Custom message type.");
            return (request.CustomMessage, null);
        }

        var settings = await db.CompanySettings.AsNoTracking().FirstOrDefaultAsync(ct);

        switch (request.ReferenceType)
        {
            case DocumentReferenceType.Quotation:
                var quotation = await db.Quotations.Include(q => q.Customer).FirstOrDefaultAsync(q => q.Id == request.ReferenceId, ct)
                    ?? throw new NotFoundAppException("Quotation", request.ReferenceId);
                var quotationMessage = ApplyTemplate(settings?.WhatsappQuotationMessageTemplate,
                    $"Your quotation {quotation.QuotationNumber} for ₹{quotation.GrandTotal:0.00} is ready.",
                    new()
                    {
                        ["customerName"] = quotation.Customer.Name,
                        ["quotationNumber"] = quotation.QuotationNumber,
                        ["grandTotal"] = quotation.GrandTotal.ToString("0.00"),
                        ["shopName"] = settings?.ShopName ?? "",
                    });
                return (quotationMessage, await pdfService.RenderQuotationAsync(request.ReferenceId, ct));

            case DocumentReferenceType.ProformaInvoice:
                var proforma = await db.ProformaInvoices.Include(p => p.Customer).FirstOrDefaultAsync(p => p.Id == request.ReferenceId, ct)
                    ?? throw new NotFoundAppException("ProformaInvoice", request.ReferenceId);
                var proformaMessage = ApplyTemplate(settings?.WhatsappProformaMessageTemplate,
                    $"Your proforma invoice {proforma.ProformaNumber} for ₹{proforma.GrandTotal:0.00} (outstanding ₹{proforma.OutstandingTotal:0.00}) is ready.",
                    new()
                    {
                        ["customerName"] = proforma.Customer.Name,
                        ["proformaNumber"] = proforma.ProformaNumber,
                        ["grandTotal"] = proforma.GrandTotal.ToString("0.00"),
                        ["outstandingTotal"] = proforma.OutstandingTotal.ToString("0.00"),
                        ["shopName"] = settings?.ShopName ?? "",
                    });
                return (proformaMessage, await pdfService.RenderProformaAsync(request.ReferenceId, ct));

            case DocumentReferenceType.SalesInvoice:
                var invoice = await db.SalesInvoices.Include(i => i.Customer).FirstOrDefaultAsync(i => i.Id == request.ReferenceId, ct)
                    ?? throw new NotFoundAppException("SalesInvoice", request.ReferenceId);
                var invoiceMessage = ApplyTemplate(settings?.WhatsappSalesInvoiceMessageTemplate,
                    $"Your invoice {invoice.InvoiceNumber} for ₹{invoice.GrandTotal:0.00} is ready.",
                    new()
                    {
                        ["customerName"] = invoice.Customer.Name,
                        ["invoiceNumber"] = invoice.InvoiceNumber,
                        ["grandTotal"] = invoice.GrandTotal.ToString("0.00"),
                        ["shopName"] = settings?.ShopName ?? "",
                    });
                return (invoiceMessage, await pdfService.RenderSalesInvoiceAsync(request.ReferenceId, ct));

            default:
                throw new ValidationAppException("Unsupported reference type for a WhatsApp message.");
        }
    }

    /// <summary>Simple {variable} substitution over an admin-provided template; falls back to the
    /// hardcoded default wording when no template has been set (null/blank), so this stays fully
    /// backward compatible.</summary>
    private static string ApplyTemplate(string? template, string fallback, Dictionary<string, string> variables)
    {
        if (string.IsNullOrWhiteSpace(template)) return fallback;

        var result = template;
        foreach (var (key, value) in variables)
        {
            result = result.Replace("{" + key + "}", value);
        }
        return result;
    }

    /// <summary>The UI only ever collects a plain 10-digit local number (confirmed decision
    /// 2026-08-28 - the field itself is capped at 10 digits client-side); the country code is
    /// added here, centrally, rather than asking the admin to type it. Assumes India (+91) - the
    /// only market this deployment targets. A number that's already longer than 10 digits (e.g.
    /// one saved before this change, or with a code already present) is left alone.</summary>
    private static string ToInternationalNumber(string number)
    {
        var digits = new string(number.Where(char.IsDigit).ToArray());
        return digits.Length == 10 ? $"91{digits}" : digits;
    }

    private static WhatsappOutboxDto ToDto(WhatsappOutboxItem w) =>
        new(w.Id, w.MessageType, w.RecipientNumber, w.Status, w.Attempts, w.LastError, w.SentAt, w.CreatedAt);
}
