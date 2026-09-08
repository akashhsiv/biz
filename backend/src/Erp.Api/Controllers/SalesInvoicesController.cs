using Erp.Api.Auth;
using Erp.Api.Common;
using Erp.Application.Common;
using Erp.Application.Documents;
using Erp.Application.Finance;
using Erp.Application.Sales;
using Erp.Application.Security;
using Erp.Application.Stock;
using Erp.Domain.Common;
using Erp.Domain.Customers;
using Erp.Domain.Items;
using Erp.Domain.Sales;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record DocumentLineRequest(Guid? ItemId, string Description, decimal Quantity, decimal Rate, decimal Discount, decimal? TaxRatePercent, List<string>? SerialNumbers = null, string? HsnCode = null);

public record DocumentLineDto(Guid Id, Guid? ItemId, string Description, decimal Quantity, decimal Rate, decimal Discount, decimal TaxRatePercent, decimal Cgst, decimal Sgst, decimal Igst, decimal LineTotal, List<string>? SerialNumbers = null, string? HsnCode = null);

public record SalesInvoiceDto(
    Guid Id, string InvoiceNumber, Guid CustomerId, Guid CategoryId, SalesInvoiceSourceType SourceType, SalesInvoiceStatus Status,
    decimal Subtotal, decimal OverallDiscountAmount, decimal TaxTotal, decimal GrandTotal, decimal DepositAllocatedTotal,
    DateTime? DueDate, decimal OutstandingTotal, DocumentPaymentStatus PaymentStatus,
    List<DocumentLineDto> Lines, string? CancellationReason, string? PlaceOfSupply, DateTime CreatedAt, Guid CreatedBy);

public record CancelSalesInvoiceRequest(string Reason);

public record CreateSalesInvoiceRequest(Guid CustomerId, Guid CategoryId, List<DocumentLineRequest> Lines, DiscountType? OverallDiscountType, decimal OverallDiscountValue, DateTime? DueDate, string? Notes = null, string? PlaceOfSupply = null, decimal PaidAmount = 0m);

[ApiController]
[Route("api/sales-invoices")]
public class SalesInvoicesController(
    ErpDbContext db,
    IAuditService audit,
    IFinanceLedgerService ledger,
    IStockService stock,
    IDocumentPdfService pdfService,
    IDocumentNumberService documentNumbers,
    IIdempotencyService idempotency,
    Erp.Application.Commission.ICommissionCalculationService commission) : ControllerBase
{
    /// <summary>Direct sales-invoice creation — the product no longer routes sales through a
    /// quotation/proforma pipeline, so this replicates the business logic that used to live in
    /// QuotationsController.ConvertToSalesInvoiceAsync (totals, numbering, stock deduction, commission).
    /// This endpoint does not use the customer-deposit pool: the caller supplies PaidAmount directly,
    /// and OutstandingTotal/PaymentStatus are derived from that.</summary>
    [HttpPost]
    [RequirePermission(PermissionKeys.SalesInvoicesManage)]
    public async Task<ActionResult<SalesInvoiceDto>> Create(CreateSalesInvoiceRequest request, CancellationToken ct)
    {
        const string endpoint = "POST /api/sales-invoices";
        var key = IdempotencyGuard.RequireKey(Request);
        var hash = IdempotencyGuard.HashRequest(request);

        var replay = await idempotency.FindReplayAsync(key, endpoint, hash, ct);
        if (replay is not null)
            return new ContentResult { StatusCode = replay.StatusCode, Content = replay.ResponseBodyJson, ContentType = "application/json" };

        var customer = await db.Customers.FirstOrDefaultAsync(c => c.Id == request.CustomerId && c.IsActive, ct)
            ?? throw new NotFoundAppException(nameof(Customer), request.CustomerId);

        // Explicit clear error rather than a generic 404 for a cross-shop id — db.ItemCategories is
        // already shop-filtered by ErpDbContext's global query filter, so an id from another shop
        // simply won't be found here.
        var category = await db.ItemCategories.FirstOrDefaultAsync(c => c.Id == request.CategoryId && c.IsActive, ct)
            ?? throw new NotFoundAppException(nameof(ItemCategory), request.CategoryId);

        await ValidateLineCategoriesAsync(request.Lines, category, ct);

        var shopState = await GetShopStateAsync(ct);
        var totals = await CalculateAsync(request.Lines, shopState, customer.GstState, request.OverallDiscountType, request.OverallDiscountValue, ct);

        await using var tx = await db.Database.BeginTransactionAsync(ct);

        var invoiceNumber = await documentNumbers.NextNumberAsync("sales_invoice", "INV", ct);

        var invoice = new SalesInvoice
        {
            InvoiceNumber = invoiceNumber,
            FinancialYear = documentNumbers.CurrentFinancialYear(),
            SourceType = SalesInvoiceSourceType.Direct,
            SourceId = Guid.Empty,
            CustomerId = customer.Id,
            CategoryId = category.Id,
            Status = SalesInvoiceStatus.Active,
            Subtotal = totals.Subtotal,
            OverallDiscountType = request.OverallDiscountType,
            OverallDiscountValue = request.OverallDiscountValue,
            OverallDiscountAmount = totals.OverallDiscountAmount,
            TaxTotal = totals.TaxTotal,
            GrandTotal = totals.GrandTotal,
            DueDate = request.DueDate,
            PlaceOfSupply = string.IsNullOrWhiteSpace(request.PlaceOfSupply) ? null : request.PlaceOfSupply.Trim(),
            Lines = totals.Lines.Zip(request.Lines, ToSalesInvoiceLine).ToList(),
        };

        db.SalesInvoices.Add(invoice);

        await DeductStockForLinesAsync(invoice.Lines, DocumentReferenceType.SalesInvoice, invoice.Id, ct);

        invoice.DepositAllocatedTotal = 0;
        invoice.OutstandingTotal = Math.Max(0, invoice.GrandTotal - request.PaidAmount);
        invoice.PaymentStatus = Erp.Application.Common.DocumentPaymentStatusCalculator.Calculate(invoice.GrandTotal, invoice.OutstandingTotal, invoice.DueDate, DateTime.UtcNow);

        // Provisional commission trigger — isolated from invoice logic, see CommissionCalculationService.
        await commission.CalculateForInvoiceAsync(invoice, ct);

        await audit.LogAsync("sales_invoice.created", nameof(SalesInvoice), invoice.Id, newValue: new { invoice.InvoiceNumber, invoice.GrandTotal }, ct: ct);

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        var dto = ToDto(invoice);
        var responseJson = IdempotencyGuard.SerializeResponse(dto);
        await idempotency.StoreAsync(key, endpoint, hash, StatusCodes.Status200OK, responseJson, ct);

        return Ok(dto);
    }

    /// <summary>Every line with an Item must belong to the invoice's chosen category and to this shop —
    /// db.Items is already shop-filtered by ErpDbContext's global query filter, so an item id from
    /// another shop simply isn't found, which we surface with an explicit message rather than letting a
    /// later AsNoTracking().FirstAsync elsewhere throw an opaque InvalidOperationException.</summary>
    private async Task ValidateLineCategoriesAsync(List<DocumentLineRequest> lines, ItemCategory category, CancellationToken ct)
    {
        var itemIds = lines.Where(l => l.ItemId is not null).Select(l => l.ItemId!.Value).Distinct().ToList();
        if (itemIds.Count == 0) return;

        var items = await db.Items.Where(i => itemIds.Contains(i.Id)).ToDictionaryAsync(i => i.Id, ct);

        foreach (var itemId in itemIds)
        {
            if (!items.TryGetValue(itemId, out var item))
                throw new NotFoundAppException(nameof(Item), itemId);

            if (item.CategoryId != category.Id)
                throw new ValidationAppException($"Item '{item.Name}' does not belong to the selected category '{category.Name}'.");
        }
    }

    private async Task DeductStockForLinesAsync(IEnumerable<Erp.Domain.Sales.DocumentLineBase> lines, DocumentReferenceType refType, Guid refId, CancellationToken ct)
    {
        foreach (var line in lines.Where(l => l.ItemId is not null))
        {
            var item = await db.Items.AsNoTracking().FirstAsync(i => i.Id == line.ItemId!.Value, ct);
            if (item.ItemKind != ItemKind.Stock) continue;

            // A manually-picked serial always wins over the FIFO default - but it must still be
            // unsold at creation time.
            List<Guid>? serialIds = null;
            var pickedNumbers = SerialNumbersCsv.Parse(line.SerialNumbersCsv);
            if (pickedNumbers is not null && item.IsSerialTracked)
            {
                var matches = await db.ItemSerials
                    .Where(s => s.ItemId == item.Id && !s.IsSold && pickedNumbers.Contains(s.SerialNumber))
                    .ToListAsync(ct);

                if (matches.Count == pickedNumbers.Count)
                    serialIds = matches.Select(s => s.Id).ToList();
            }

            await stock.DecrementAsync(item.Id, line.Quantity, refType, refId, serialIds: serialIds, ct: ct);
        }
    }

    private async Task<string> GetShopStateAsync(CancellationToken ct)
    {
        var settings = await db.CompanySettings.AsNoTracking().FirstOrDefaultAsync(ct)
            ?? throw new ConflictAppException("Company settings have not been configured.");

        return settings.State;
    }

    private async Task<DocumentTotals> CalculateAsync(List<DocumentLineRequest> lines, string shopState, string? customerState, DiscountType? overallDiscountType, decimal overallDiscountValue, CancellationToken ct)
    {
        if (lines.Count == 0) throw new ValidationAppException("A document must have at least one line.");

        var itemIds = lines.Where(l => l.ItemId is not null).Select(l => l.ItemId!.Value).Distinct().ToList();
        var items = await db.Items.Where(i => itemIds.Contains(i.Id)).ToDictionaryAsync(i => i.Id, ct);

        var lineInputs = lines.Select(l => new LineInput(
            l.ItemId,
            l.ItemId is { } withDesc && string.IsNullOrWhiteSpace(l.Description) ? items[withDesc].Name : l.Description,
            l.Quantity, l.Rate, l.Discount,
            l.ItemId is { } itemId ? items[itemId].TaxRatePercent : l.TaxRatePercent ?? 0m));

        return DocumentTotalsCalculator.Calculate(lineInputs, shopState, customerState, overallDiscountType, overallDiscountValue);
    }

    private static SalesInvoiceLine ToSalesInvoiceLine(LineResult r, DocumentLineRequest request) => new()
    {
        ItemId = r.ItemId,
        Description = r.Description,
        Quantity = r.Quantity,
        Rate = r.Rate,
        Discount = r.Discount,
        TaxRatePercent = r.TaxRatePercent,
        CgstAmount = r.Cgst,
        SgstAmount = r.Sgst,
        IgstAmount = r.Igst,
        LineTotal = r.LineTotal,
        SerialNumbersCsv = SerialNumbersCsv.Join(request.SerialNumbers),
        HsnCode = string.IsNullOrWhiteSpace(request.HsnCode) ? null : request.HsnCode.Trim(),
    };

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

        // Stock for a Direct invoice (and the historical QuotationDirect type) moved when the invoice
        // itself was created; for a historical ProformaConversion invoice, stock moved earlier, at
        // proforma creation — reverse whichever moved it.
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
        // Judgment call: a cancelled invoice owes nothing further — force Outstanding/PaymentStatus to
        // the settled state rather than leaving a stale Credit/PartiallyPaid label hanging around.
        invoice.OutstandingTotal = 0;
        invoice.PaymentStatus = Erp.Domain.Common.DocumentPaymentStatus.Paid;

        await audit.LogAsync("sales_invoice.cancelled", nameof(SalesInvoice), invoice.Id, reason: request.Reason, ct: ct);

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        return NoContent();
    }

    private static SalesInvoiceDto ToDto(SalesInvoice i) => new(
        i.Id, i.InvoiceNumber, i.CustomerId, i.CategoryId, i.SourceType, i.Status, i.Subtotal, i.OverallDiscountAmount, i.TaxTotal, i.GrandTotal, i.DepositAllocatedTotal,
        i.DueDate, i.OutstandingTotal, i.PaymentStatus,
        i.Lines.Select(l => new DocumentLineDto(l.Id, l.ItemId, l.Description, l.Quantity, l.Rate, l.Discount, l.TaxRatePercent, l.CgstAmount, l.SgstAmount, l.IgstAmount, l.LineTotal, Erp.Api.Common.SerialNumbersCsv.Parse(l.SerialNumbersCsv), l.HsnCode)).ToList(),
        i.CancellationReason, i.PlaceOfSupply, i.CreatedAt, i.CreatedBy);
}
