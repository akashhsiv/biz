using Erp.Api.Auth;
using Erp.Application.Common;
using Erp.Application.Documents;
using Erp.Application.Finance;
using Erp.Application.Security;
using Erp.Application.Stock;
using Erp.Domain.Common;
using Erp.Domain.Items;
using Erp.Domain.Sales;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record SalesInvoiceDto(
    Guid Id, string InvoiceNumber, Guid CustomerId, SalesInvoiceSourceType SourceType, SalesInvoiceStatus Status,
    decimal Subtotal, decimal OverallDiscountAmount, decimal TaxTotal, decimal GrandTotal, decimal DepositAllocatedTotal,
    List<DocumentLineDto> Lines, string? CancellationReason, string? PlaceOfSupply, DateTime CreatedAt, Guid CreatedBy);

public record CancelSalesInvoiceRequest(string Reason);

[ApiController]
[Route("api/sales-invoices")]
public class SalesInvoicesController(ErpDbContext db, IAuditService audit, IFinanceLedgerService ledger, IStockService stock, IDocumentPdfService pdfService) : ControllerBase
{
    [HttpGet("{id:guid}/pdf")]
    [RequirePermission(PermissionKeys.SalesInvoicesManage)]
    public async Task<IActionResult> Pdf(Guid id, CancellationToken ct)
    {
        var pdf = await pdfService.RenderSalesInvoiceAsync(id, ct);
        return File(pdf.Bytes, "application/pdf", pdf.FileName);
    }

    [HttpGet]
    [RequirePermission(PermissionKeys.SalesInvoicesManage)]
    public async Task<ActionResult<List<SalesInvoiceDto>>> List([FromQuery] Guid? customerId, CancellationToken ct)
    {
        var query = db.SalesInvoices.Include(i => i.Lines).AsQueryable();
        if (customerId is { } id) query = query.Where(i => i.CustomerId == id);

        var invoices = await query.OrderByDescending(i => i.CreatedAt).ToListAsync(ct);
        return Ok(invoices.Select(ToDto));
    }

    [HttpGet("{id:guid}")]
    [RequirePermission(PermissionKeys.SalesInvoicesManage)]
    public async Task<ActionResult<SalesInvoiceDto>> Get(Guid id, CancellationToken ct)
    {
        var invoice = await db.SalesInvoices.Include(i => i.Lines).FirstOrDefaultAsync(i => i.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(SalesInvoice), id);

        return Ok(ToDto(invoice));
    }

    /// <summary>Admin-only, atomically reverses stock and any deposit allocation — confirmed decision in ARCHITECTURE.md §13.5. The original invoice row is never edited, only its status flips.</summary>
    [HttpPost("{id:guid}/cancel")]
    [RequirePermission(PermissionKeys.SalesInvoicesCancel)]
    public async Task<IActionResult> Cancel(Guid id, CancelSalesInvoiceRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Reason))
            throw new ValidationAppException("A reason is required to cancel a sales invoice.");

        var invoice = await db.SalesInvoices.Include(i => i.Lines).FirstOrDefaultAsync(i => i.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(SalesInvoice), id);

        if (invoice.Status == SalesInvoiceStatus.Cancelled)
            throw new ConflictAppException("This sales invoice is already cancelled.");

        await using var tx = await db.Database.BeginTransactionAsync(ct);

        // Stock for a quotation-direct invoice moved when the invoice itself was created; for a
        // proforma-conversion invoice, stock moved earlier, at proforma creation — reverse whichever moved it.
        var (stockRefType, stockRefId) = invoice.SourceType == SalesInvoiceSourceType.ProformaConversion
            ? (DocumentReferenceType.ProformaInvoice, invoice.SourceId)
            : (DocumentReferenceType.SalesInvoice, invoice.Id);

        foreach (var line in invoice.Lines.Where(l => l.ItemId is not null))
        {
            var item = await db.Items.AsNoTracking().FirstAsync(i => i.Id == line.ItemId!.Value, ct);
            if (item.ItemKind != ItemKind.Stock) continue;

            var movement = await db.StockMovements.AsNoTracking().FirstOrDefaultAsync(
                m => m.ReferenceType == stockRefType && m.ReferenceId == stockRefId && m.ItemId == item.Id, ct);

            if (movement is not null)
            {
                await stock.ReverseAsync(movement.Id, $"Sales invoice {invoice.InvoiceNumber} cancelled: {request.Reason}", ct);
            }
        }

        var allocations = await db.DepositAllocations
            .Where(a => a.DocumentType == DepositAllocationDocumentType.SalesInvoice && a.DocumentId == invoice.Id && a.Status == DepositAllocationStatus.Active)
            .ToListAsync(ct);
        foreach (var allocation in allocations)
        {
            await ledger.ReverseAllocationAsync(allocation.Id, $"Sales invoice {invoice.InvoiceNumber} cancelled: {request.Reason}", ct);
        }

        invoice.Status = SalesInvoiceStatus.Cancelled;
        invoice.CancellationReason = request.Reason;

        await audit.LogAsync("sales_invoice.cancelled", nameof(SalesInvoice), invoice.Id, reason: request.Reason, ct: ct);

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        return NoContent();
    }

    private static SalesInvoiceDto ToDto(SalesInvoice i) => new(
        i.Id, i.InvoiceNumber, i.CustomerId, i.SourceType, i.Status, i.Subtotal, i.OverallDiscountAmount, i.TaxTotal, i.GrandTotal, i.DepositAllocatedTotal,
        i.Lines.Select(l => new DocumentLineDto(l.Id, l.ItemId, l.Description, l.Quantity, l.Rate, l.Discount, l.TaxRatePercent, l.CgstAmount, l.SgstAmount, l.IgstAmount, l.LineTotal, Erp.Api.Common.SerialNumbersCsv.Parse(l.SerialNumbersCsv), l.HsnCode)).ToList(),
        i.CancellationReason, i.PlaceOfSupply, i.CreatedAt, i.CreatedBy);
}
