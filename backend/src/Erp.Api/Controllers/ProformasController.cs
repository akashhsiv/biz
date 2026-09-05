using System.Text.Json;
using Erp.Api.Auth;
using Erp.Api.Common;
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

public record ProformaDto(
    Guid Id, string ProformaNumber, Guid CustomerId, Guid QuotationId, ProformaStatus Status,
    decimal Subtotal, decimal OverallDiscountAmount, decimal TaxTotal,
    decimal GrandTotal, decimal AllocatedTotal, decimal OutstandingTotal, List<DocumentLineDto> Lines, string? PlaceOfSupply, DateTime CreatedAt);

public record AllocateDepositRequest(decimal? Amount);
public record AllocateDepositResultDto(decimal Allocated, decimal AllocatedTotal, decimal OutstandingTotal, ProformaStatus Status);
public record CancelProformaRequest(string Reason);

[ApiController]
[Route("api/proformas")]
public class ProformasController(
    ErpDbContext db,
    IAuditService audit,
    IFinanceLedgerService ledger,
    IStockService stock,
    IDocumentNumberService documentNumbers,
    IIdempotencyService idempotency,
    IDocumentPdfService pdfService,
    Erp.Application.Commission.ICommissionCalculationService commission) : ControllerBase
{
    [HttpGet("{id:guid}/pdf")]
    [RequirePermission(PermissionKeys.ProformasManage)]
    public async Task<IActionResult> Pdf(Guid id, CancellationToken ct)
    {
        var pdf = await pdfService.RenderProformaAsync(id, ct);
        return File(pdf.Bytes, "application/pdf", pdf.FileName);
    }

    [HttpGet]
    [RequirePermission(PermissionKeys.ProformasManage)]
    public async Task<ActionResult<List<ProformaDto>>> List([FromQuery] Guid? customerId, CancellationToken ct)
    {
        var query = db.ProformaInvoices.Include(p => p.Lines).AsQueryable();
        if (customerId is { } id) query = query.Where(p => p.CustomerId == id);

        var proformas = await query.OrderByDescending(p => p.CreatedAt).ToListAsync(ct);
        return Ok(proformas.Select(ToDto));
    }

    [HttpGet("{id:guid}")]
    [RequirePermission(PermissionKeys.ProformasManage)]
    public async Task<ActionResult<ProformaDto>> Get(Guid id, CancellationToken ct)
    {
        var proforma = await db.ProformaInvoices.Include(p => p.Lines).FirstOrDefaultAsync(p => p.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(ProformaInvoice), id);

        return Ok(ToDto(proforma));
    }

    /// <summary>Applies newly available customer deposit to this proforma's outstanding balance — ARCHITECTURE.md §21.</summary>
    [HttpPost("{id:guid}/allocate-deposit")]
    [RequirePermission(PermissionKeys.ProformasManage)]
    public async Task<ActionResult<AllocateDepositResultDto>> AllocateDeposit(Guid id, AllocateDepositRequest request, CancellationToken ct)
    {
        const string endpoint = "POST /api/proformas/{id}/allocate-deposit";
        var key = IdempotencyGuard.RequireKey(Request);
        var hash = IdempotencyGuard.HashRequest(new { id, request.Amount });

        var replay = await idempotency.FindReplayAsync(key, endpoint, hash, ct);
        if (replay is not null)
            return new ContentResult { StatusCode = replay.StatusCode, Content = replay.ResponseBodyJson, ContentType = "application/json" };

        var proforma = await db.ProformaInvoices.FirstOrDefaultAsync(p => p.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(ProformaInvoice), id);

        if (proforma.Status != ProformaStatus.Open)
            throw new ConflictAppException($"Only an Open proforma can receive a deposit allocation (current status: {proforma.Status}).");

        await using var tx = await db.Database.BeginTransactionAsync(ct);

        var available = await ledger.GetAvailableDepositAsync(proforma.CustomerId, ct);
        var toAllocate = Math.Min(request.Amount ?? proforma.OutstandingTotal, Math.Min(available, proforma.OutstandingTotal));

        if (toAllocate <= 0)
            throw new ValidationAppException("No deposit is available to allocate, or the proforma has no outstanding balance.");

        await ledger.AllocateDepositAsync(proforma.CustomerId, DepositAllocationDocumentType.Proforma, proforma.Id, toAllocate, ct);

        proforma.AllocatedTotal += toAllocate;
        proforma.OutstandingTotal -= toAllocate;
        if (proforma.OutstandingTotal == 0) proforma.Status = ProformaStatus.FullyFunded;

        await audit.LogAsync("proforma.updated", nameof(ProformaInvoice), proforma.Id, newValue: new { Allocated = toAllocate, proforma.OutstandingTotal }, ct: ct);

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        var result = new AllocateDepositResultDto(toAllocate, proforma.AllocatedTotal, proforma.OutstandingTotal, proforma.Status);
        await idempotency.StoreAsync(key, endpoint, hash, StatusCodes.Status200OK, IdempotencyGuard.SerializeResponse(result), ct);

        return Ok(result);
    }

    /// <summary>"Clear Dues" — once outstanding is zero, the proforma becomes a Sales Invoice. Stock already moved at proforma creation, so it is not moved again — ARCHITECTURE.md §21/§23.</summary>
    [HttpPost("{id:guid}/convert")]
    [RequirePermission(PermissionKeys.ProformasManage)]
    public async Task<ActionResult<ConvertQuotationResultDto>> Convert(Guid id, CancellationToken ct)
    {
        const string endpoint = "POST /api/proformas/{id}/convert";
        var key = IdempotencyGuard.RequireKey(Request);
        var hash = IdempotencyGuard.HashRequest(new { id });

        var replay = await idempotency.FindReplayAsync(key, endpoint, hash, ct);
        if (replay is not null)
            return new ContentResult { StatusCode = replay.StatusCode, Content = replay.ResponseBodyJson, ContentType = "application/json" };

        var proforma = await db.ProformaInvoices.Include(p => p.Lines).FirstOrDefaultAsync(p => p.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(ProformaInvoice), id);

        if (proforma.Status != ProformaStatus.FullyFunded && !(proforma.Status == ProformaStatus.Open && proforma.OutstandingTotal == 0))
            throw new ConflictAppException($"Proforma cannot be converted while outstanding balance is {proforma.OutstandingTotal:0.00}.");

        await using var tx = await db.Database.BeginTransactionAsync(ct);

        var invoiceNumber = await documentNumbers.NextNumberAsync("sales_invoice", "INV", ct);
        var invoice = new SalesInvoice
        {
            InvoiceNumber = invoiceNumber,
            FinancialYear = documentNumbers.CurrentFinancialYear(),
            SourceType = SalesInvoiceSourceType.ProformaConversion,
            SourceId = proforma.Id,
            CustomerId = proforma.CustomerId,
            Status = SalesInvoiceStatus.Active,
            Subtotal = proforma.Subtotal,
            OverallDiscountType = proforma.OverallDiscountType,
            OverallDiscountValue = proforma.OverallDiscountValue,
            OverallDiscountAmount = proforma.OverallDiscountAmount,
            TaxTotal = proforma.TaxTotal,
            GrandTotal = proforma.GrandTotal,
            DepositAllocatedTotal = proforma.AllocatedTotal,
            PlaceOfSupply = proforma.PlaceOfSupply,
            Lines = proforma.Lines.Select(l => new SalesInvoiceLine
            {
                ItemId = l.ItemId,
                Description = l.Description,
                Quantity = l.Quantity,
                Rate = l.Rate,
                Discount = l.Discount,
                TaxRatePercent = l.TaxRatePercent,
                CgstAmount = l.CgstAmount,
                SgstAmount = l.SgstAmount,
                IgstAmount = l.IgstAmount,
                LineTotal = l.LineTotal,
                HsnCode = l.HsnCode,
            }).ToList(),
        };

        db.SalesInvoices.Add(invoice);
        proforma.Status = ProformaStatus.Converted;

        // Provisional commission trigger — isolated from invoice logic, see CommissionCalculationService.
        await commission.CalculateForInvoiceAsync(invoice, ct);

        // Re-point the now-Converted proforma's active deposit allocations at the new invoice so the
        // audit trail follows the money to its final document without creating a second allocation.
        var allocations = await db.DepositAllocations
            .Where(a => a.DocumentType == DepositAllocationDocumentType.Proforma && a.DocumentId == proforma.Id && a.Status == DepositAllocationStatus.Active)
            .ToListAsync(ct);
        foreach (var allocation in allocations)
        {
            allocation.DocumentType = DepositAllocationDocumentType.SalesInvoice;
            allocation.DocumentId = invoice.Id;
        }

        await audit.LogAsync("proforma.converted", nameof(ProformaInvoice), proforma.Id, newValue: new { invoice.InvoiceNumber }, ct: ct);
        await audit.LogAsync("sales_invoice.created", nameof(SalesInvoice), invoice.Id, newValue: new { invoice.InvoiceNumber, invoice.GrandTotal }, ct: ct);

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        var result = new ConvertQuotationResultDto("SalesInvoice", invoice.Id, invoice.InvoiceNumber, invoice.GrandTotal, invoice.DepositAllocatedTotal, 0);
        await idempotency.StoreAsync(key, endpoint, hash, StatusCodes.Status200OK, IdempotencyGuard.SerializeResponse(result), ct);

        return Ok(result);
    }

    /// <summary>Deposit auto-returns to available and stock auto-restores, atomically — confirmed decision in ARCHITECTURE.md §13.4.</summary>
    [HttpPost("{id:guid}/cancel")]
    [RequirePermission(PermissionKeys.ProformasManage)]
    public async Task<IActionResult> Cancel(Guid id, CancelProformaRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Reason))
            throw new ValidationAppException("A reason is required to cancel a proforma.");

        var proforma = await db.ProformaInvoices.Include(p => p.Lines).FirstOrDefaultAsync(p => p.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(ProformaInvoice), id);

        if (proforma.Status is ProformaStatus.Converted or ProformaStatus.Cancelled)
            throw new ConflictAppException($"Proforma cannot be cancelled from status {proforma.Status}.");

        await using var tx = await db.Database.BeginTransactionAsync(ct);

        foreach (var line in proforma.Lines.Where(l => l.ItemId is not null))
        {
            var item = await db.Items.AsNoTracking().FirstAsync(i => i.Id == line.ItemId!.Value, ct);
            if (item.ItemKind != ItemKind.Stock) continue;

            var movement = await db.StockMovements.AsNoTracking().FirstOrDefaultAsync(
                m => m.ReferenceType == DocumentReferenceType.ProformaInvoice && m.ReferenceId == proforma.Id && m.ItemId == item.Id, ct);

            if (movement is not null)
            {
                await stock.ReverseAsync(movement.Id, $"Proforma {proforma.ProformaNumber} cancelled: {request.Reason}", ct);
            }
        }

        var allocations = await db.DepositAllocations
            .Where(a => a.DocumentType == DepositAllocationDocumentType.Proforma && a.DocumentId == proforma.Id && a.Status == DepositAllocationStatus.Active)
            .ToListAsync(ct);
        foreach (var allocation in allocations)
        {
            await ledger.ReverseAllocationAsync(allocation.Id, $"Proforma {proforma.ProformaNumber} cancelled: {request.Reason}", ct);
        }

        proforma.Status = ProformaStatus.Cancelled;
        await audit.LogAsync("proforma.cancelled", nameof(ProformaInvoice), proforma.Id, reason: request.Reason, ct: ct);

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        return NoContent();
    }

    private static ProformaDto ToDto(ProformaInvoice p) => new(
        p.Id, p.ProformaNumber, p.CustomerId, p.QuotationId, p.Status, p.Subtotal, p.OverallDiscountAmount, p.TaxTotal, p.GrandTotal, p.AllocatedTotal, p.OutstandingTotal,
        p.Lines.Select(l => new DocumentLineDto(l.Id, l.ItemId, l.Description, l.Quantity, l.Rate, l.Discount, l.TaxRatePercent, l.CgstAmount, l.SgstAmount, l.IgstAmount, l.LineTotal, Erp.Api.Common.SerialNumbersCsv.Parse(l.SerialNumbersCsv), l.HsnCode)).ToList(), p.PlaceOfSupply,
        p.CreatedAt);
}
