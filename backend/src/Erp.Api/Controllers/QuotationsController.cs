using System.Text.Json;
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
public record UpsertQuotationRequest(Guid CustomerId, List<DocumentLineRequest> Lines, DiscountType? OverallDiscountType, decimal OverallDiscountValue, string? Notes = null, string? PlaceOfSupply = null);

public record DocumentLineDto(Guid Id, Guid? ItemId, string Description, decimal Quantity, decimal Rate, decimal Discount, decimal TaxRatePercent, decimal Cgst, decimal Sgst, decimal Igst, decimal LineTotal, List<string>? SerialNumbers = null, string? HsnCode = null);

public record QuotationDto(
    Guid Id, string QuotationNumber, Guid CustomerId, QuotationStatus Status,
    decimal Subtotal, DiscountType? OverallDiscountType, decimal OverallDiscountValue, decimal OverallDiscountAmount,
    decimal TaxTotal, decimal GrandTotal, List<DocumentLineDto> Lines, string? Notes, string? PlaceOfSupply, DateTime CreatedAt, Guid CreatedBy);

public record ConvertQuotationResultDto(string ResultType, Guid DocumentId, string DocumentNumber, decimal GrandTotal, decimal DepositApplied, decimal Outstanding);

[ApiController]
[Route("api/quotations")]
public class QuotationsController(
    ErpDbContext db,
    IAuditService audit,
    IFinanceLedgerService ledger,
    IStockService stock,
    IDocumentNumberService documentNumbers,
    IIdempotencyService idempotency,
    ICurrentUserService currentUser,
    IDocumentPdfService pdfService,
    Erp.Application.Commission.ICommissionCalculationService commission) : ControllerBase
{
    [HttpGet("{id:guid}/pdf")]
    [RequirePermission(PermissionKeys.QuotationsManage)]
    public async Task<IActionResult> Pdf(Guid id, CancellationToken ct)
    {
        var pdf = await pdfService.RenderQuotationAsync(id, ct);
        return File(pdf.Bytes, "application/pdf", pdf.FileName);
    }

    [HttpGet]
    [RequirePermission(PermissionKeys.QuotationsManage)]
    public async Task<ActionResult<List<QuotationDto>>> List([FromQuery] Guid? customerId, CancellationToken ct)
    {
        var query = db.Quotations.Include(q => q.Lines).AsQueryable();
        if (customerId is { } id) query = query.Where(q => q.CustomerId == id);

        var quotations = await query.OrderByDescending(q => q.CreatedAt).ToListAsync(ct);
        return Ok(quotations.Select(ToDto));
    }

    [HttpGet("{id:guid}")]
    [RequirePermission(PermissionKeys.QuotationsManage)]
    public async Task<ActionResult<QuotationDto>> Get(Guid id, CancellationToken ct)
    {
        var quotation = await db.Quotations.Include(q => q.Lines).FirstOrDefaultAsync(q => q.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Quotation), id);

        return Ok(ToDto(quotation));
    }

    [HttpPost]
    [RequirePermission(PermissionKeys.QuotationsManage)]
    public async Task<ActionResult<QuotationDto>> Create(UpsertQuotationRequest request, CancellationToken ct)
    {
        var customer = await db.Customers.FirstOrDefaultAsync(c => c.Id == request.CustomerId && c.IsActive, ct)
            ?? throw new NotFoundAppException(nameof(Customer), request.CustomerId);

        var shopState = await GetShopStateAsync(ct);
        var totals = await CalculateAsync(request.Lines, shopState, customer.GstState, request.OverallDiscountType, request.OverallDiscountValue, ct);

        var quotation = new Quotation
        {
            QuotationNumber = await documentNumbers.NextNumberAsync("quotation", "QTN", ct),
            FinancialYear = documentNumbers.CurrentFinancialYear(),
            CustomerId = customer.Id,
            Status = QuotationStatus.Draft,
            SalesPersonId = currentUser.UserId,
            Subtotal = totals.Subtotal,
            OverallDiscountType = request.OverallDiscountType,
            OverallDiscountValue = request.OverallDiscountValue,
            OverallDiscountAmount = totals.OverallDiscountAmount,
            TaxTotal = totals.TaxTotal,
            GrandTotal = totals.GrandTotal,
            Lines = totals.Lines.Zip(request.Lines, ToQuotationLine).ToList(),
            Notes = string.IsNullOrWhiteSpace(request.Notes) ? null : request.Notes.Trim(),
            PlaceOfSupply = string.IsNullOrWhiteSpace(request.PlaceOfSupply) ? null : request.PlaceOfSupply.Trim(),
        };

        db.Quotations.Add(quotation);
        await audit.LogAsync("quotation.created", nameof(Quotation), quotation.Id, newValue: new { quotation.QuotationNumber, quotation.GrandTotal }, ct: ct);
        await db.SaveChangesAsync(ct);

        return Ok(ToDto(quotation));
    }

    [HttpPut("{id:guid}")]
    [RequirePermission(PermissionKeys.QuotationsManage)]
    public async Task<ActionResult<QuotationDto>> Update(Guid id, UpsertQuotationRequest request, CancellationToken ct)
    {
        var quotation = await db.Quotations.Include(q => q.Lines).FirstOrDefaultAsync(q => q.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Quotation), id);

        if (quotation.Status != QuotationStatus.Draft)
            throw new ConflictAppException($"Only a Draft quotation can be edited (current status: {quotation.Status}).");

        var customer = await db.Customers.FirstOrDefaultAsync(c => c.Id == request.CustomerId && c.IsActive, ct)
            ?? throw new NotFoundAppException(nameof(Customer), request.CustomerId);

        var shopState = await GetShopStateAsync(ct);
        var totals = await CalculateAsync(request.Lines, shopState, customer.GstState, request.OverallDiscountType, request.OverallDiscountValue, ct);

        db.QuotationLines.RemoveRange(quotation.Lines);

        quotation.CustomerId = customer.Id;
        quotation.Subtotal = totals.Subtotal;
        quotation.OverallDiscountType = request.OverallDiscountType;
        quotation.OverallDiscountValue = request.OverallDiscountValue;
        quotation.OverallDiscountAmount = totals.OverallDiscountAmount;
        quotation.TaxTotal = totals.TaxTotal;
        quotation.GrandTotal = totals.GrandTotal;
        quotation.Lines = totals.Lines.Zip(request.Lines, ToQuotationLine).ToList();
        quotation.Notes = string.IsNullOrWhiteSpace(request.Notes) ? null : request.Notes.Trim();
        quotation.PlaceOfSupply = string.IsNullOrWhiteSpace(request.PlaceOfSupply) ? null : request.PlaceOfSupply.Trim();

        await audit.LogAsync("quotation.updated", nameof(Quotation), quotation.Id, newValue: new { quotation.QuotationNumber, quotation.GrandTotal }, ct: ct);
        await db.SaveChangesAsync(ct);

        return Ok(ToDto(quotation));
    }

    /// <summary>Marks a Draft quotation Issued (e.g. once it's been sent/shown to the customer). Purely
    /// a status flag — conversion already accepts either Draft or Issued, so this has no effect on
    /// what can be converted; it just distinguishes "still being worked on" from "shared with the customer".</summary>
    [HttpPost("{id:guid}/issue")]
    [RequirePermission(PermissionKeys.QuotationsManage)]
    public async Task<ActionResult<QuotationDto>> Issue(Guid id, CancellationToken ct)
    {
        var quotation = await db.Quotations.Include(q => q.Lines).FirstOrDefaultAsync(q => q.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Quotation), id);

        if (quotation.Status != QuotationStatus.Draft)
            throw new ConflictAppException($"Only a Draft quotation can be issued (current status: {quotation.Status}).");

        quotation.Status = QuotationStatus.Issued;
        await audit.LogAsync("quotation.issued", nameof(Quotation), quotation.Id, newValue: new { quotation.QuotationNumber }, ct: ct);
        await db.SaveChangesAsync(ct);

        return Ok(ToDto(quotation));
    }

    /// <summary>The core business decision from ARCHITECTURE.md §20-24: deposit >= grand total becomes a Sales Invoice, otherwise a Proforma Invoice, atomically with stock deduction, deposit allocation, and audit logging.</summary>
    [HttpPost("{id:guid}/convert")]
    [RequirePermission(PermissionKeys.QuotationsManage)]
    public async Task<ActionResult<ConvertQuotationResultDto>> Convert(Guid id, [FromQuery] DateTime? dueDate, CancellationToken ct)
    {
        const string endpoint = "POST /api/quotations/{id}/convert";
        var key = IdempotencyGuard.RequireKey(Request);
        var hash = IdempotencyGuard.HashRequest(new { id, dueDate });

        var replay = await idempotency.FindReplayAsync(key, endpoint, hash, ct);
        if (replay is not null)
            return new ContentResult { StatusCode = replay.StatusCode, Content = replay.ResponseBodyJson, ContentType = "application/json" };

        var quotation = await db.Quotations.Include(q => q.Lines).FirstOrDefaultAsync(q => q.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(Quotation), id);

        if (quotation.Status is not (QuotationStatus.Draft or QuotationStatus.Issued))
            throw new ConflictAppException($"Quotation cannot be converted from status {quotation.Status}.");

        await using var tx = await db.Database.BeginTransactionAsync(ct);

        var available = await ledger.GetAvailableDepositAsync(quotation.CustomerId, ct);
        ConvertQuotationResultDto result;

        if (available >= quotation.GrandTotal)
        {
            result = await ConvertToSalesInvoiceAsync(quotation, dueDate, ct);
        }
        else
        {
            result = await ConvertToProformaAsync(quotation, available, ct);
        }

        quotation.Status = QuotationStatus.Converted;
        await audit.LogAsync("quotation.converted", nameof(Quotation), quotation.Id, newValue: result, ct: ct);

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        var responseJson = IdempotencyGuard.SerializeResponse(result);
        await idempotency.StoreAsync(key, endpoint, hash, StatusCodes.Status200OK, responseJson, ct);

        return Ok(result);
    }

    private async Task<ConvertQuotationResultDto> ConvertToSalesInvoiceAsync(Quotation quotation, DateTime? dueDate, CancellationToken ct)
    {
        var invoiceNumber = await documentNumbers.NextNumberAsync("sales_invoice", "INV", ct);

        var invoice = new SalesInvoice
        {
            InvoiceNumber = invoiceNumber,
            FinancialYear = documentNumbers.CurrentFinancialYear(),
            SourceType = SalesInvoiceSourceType.QuotationDirect,
            SourceId = quotation.Id,
            CustomerId = quotation.CustomerId,
            Status = SalesInvoiceStatus.Active,
            Subtotal = quotation.Subtotal,
            OverallDiscountType = quotation.OverallDiscountType,
            OverallDiscountValue = quotation.OverallDiscountValue,
            OverallDiscountAmount = quotation.OverallDiscountAmount,
            TaxTotal = quotation.TaxTotal,
            GrandTotal = quotation.GrandTotal,
            DepositAllocatedTotal = quotation.GrandTotal,
            DueDate = dueDate,
            PlaceOfSupply = quotation.PlaceOfSupply,
            Lines = quotation.Lines.Select(l => new SalesInvoiceLine
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
                SerialNumbersCsv = l.SerialNumbersCsv,
                HsnCode = l.HsnCode,
            }).ToList(),
        };

        invoice.OutstandingTotal = Math.Max(0, invoice.GrandTotal - invoice.DepositAllocatedTotal);
        invoice.PaymentStatus = Erp.Application.Common.DocumentPaymentStatusCalculator.Calculate(invoice.GrandTotal, invoice.OutstandingTotal, invoice.DueDate, DateTime.UtcNow);

        db.SalesInvoices.Add(invoice);

        await DeductStockForLinesAsync(quotation.Lines, DocumentReferenceType.SalesInvoice, invoice.Id, ct);
        await ledger.AllocateDepositAsync(quotation.CustomerId, DepositAllocationDocumentType.SalesInvoice, invoice.Id, quotation.GrandTotal, ct);

        // Provisional commission trigger — isolated from invoice logic, see CommissionCalculationService.
        await commission.CalculateForInvoiceAsync(invoice, ct);

        await audit.LogAsync("sales_invoice.created", nameof(SalesInvoice), invoice.Id, newValue: new { invoice.InvoiceNumber, invoice.GrandTotal }, ct: ct);

        return new ConvertQuotationResultDto("SalesInvoice", invoice.Id, invoice.InvoiceNumber, invoice.GrandTotal, quotation.GrandTotal, 0);
    }

    private async Task<ConvertQuotationResultDto> ConvertToProformaAsync(Quotation quotation, decimal availableDeposit, CancellationToken ct)
    {
        var proformaNumber = await documentNumbers.NextNumberAsync("proforma", "PF", ct);

        var proforma = new ProformaInvoice
        {
            ProformaNumber = proformaNumber,
            FinancialYear = documentNumbers.CurrentFinancialYear(),
            QuotationId = quotation.Id,
            CustomerId = quotation.CustomerId,
            Status = ProformaStatus.Open,
            Subtotal = quotation.Subtotal,
            OverallDiscountType = quotation.OverallDiscountType,
            OverallDiscountValue = quotation.OverallDiscountValue,
            OverallDiscountAmount = quotation.OverallDiscountAmount,
            TaxTotal = quotation.TaxTotal,
            GrandTotal = quotation.GrandTotal,
            AllocatedTotal = availableDeposit,
            OutstandingTotal = quotation.GrandTotal - availableDeposit,
            PlaceOfSupply = quotation.PlaceOfSupply,
            Lines = quotation.Lines.Select(l => new ProformaLine
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
                SerialNumbersCsv = l.SerialNumbersCsv,
                HsnCode = l.HsnCode,
            }).ToList(),
        };

        db.ProformaInvoices.Add(proforma);

        await DeductStockForLinesAsync(quotation.Lines, DocumentReferenceType.ProformaInvoice, proforma.Id, ct);

        if (availableDeposit > 0)
        {
            await ledger.AllocateDepositAsync(quotation.CustomerId, DepositAllocationDocumentType.Proforma, proforma.Id, availableDeposit, ct);
        }

        await audit.LogAsync("proforma.created", nameof(ProformaInvoice), proforma.Id, newValue: new { proforma.ProformaNumber, proforma.GrandTotal, proforma.OutstandingTotal }, ct: ct);

        return new ConvertQuotationResultDto("ProformaInvoice", proforma.Id, proforma.ProformaNumber, proforma.GrandTotal, availableDeposit, proforma.OutstandingTotal);
    }

    private async Task DeductStockForLinesAsync(IEnumerable<DocumentLineBase> lines, DocumentReferenceType refType, Guid refId, CancellationToken ct)
    {
        foreach (var line in lines.Where(l => l.ItemId is not null))
        {
            var item = await db.Items.AsNoTracking().FirstAsync(i => i.Id == line.ItemId!.Value, ct);
            if (item.ItemKind != ItemKind.Stock) continue;

            // A manually-picked serial always wins over the FIFO default - but it must still be
            // unsold at conversion time (time may have passed since the quotation was drafted, and
            // another sale could have taken it in the meantime).
            List<Guid>? serialIds = null;
            var pickedNumbers = SerialNumbersCsv.Parse(line.SerialNumbersCsv);
            if (pickedNumbers is not null && item.IsSerialTracked)
            {
                var matches = await db.ItemSerials
                    .Where(s => s.ItemId == item.Id && !s.IsSold && pickedNumbers.Contains(s.SerialNumber))
                    .ToListAsync(ct);

                // A picked serial can go stale between drafting the quotation and converting it (time
                // passed, another sale took it) - rather than blocking the whole conversion, fall back
                // to FIFO auto-assignment for this line, same as if nothing had been picked at all.
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

        // A catalog item's tax rate always comes from the item record, never the client — see ARCHITECTURE.md §41.
        // Only a free-text line with no ItemId may supply its own rate. The item's name is likewise
        // the description whenever a catalog item is picked and the client didn't type its own text -
        // the client always sends an empty Description for a catalog-item line, so without this every
        // document showed a blank "Item" column.
        var lineInputs = lines.Select(l => new LineInput(
            l.ItemId,
            l.ItemId is { } withDesc && string.IsNullOrWhiteSpace(l.Description) ? items[withDesc].Name : l.Description,
            l.Quantity, l.Rate, l.Discount,
            l.ItemId is { } itemId ? items[itemId].TaxRatePercent : l.TaxRatePercent ?? 0m));

        return DocumentTotalsCalculator.Calculate(lineInputs, shopState, customerState, overallDiscountType, overallDiscountValue);
    }

    private static QuotationLine ToQuotationLine(LineResult r, DocumentLineRequest request) => new()
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

    private static QuotationDto ToDto(Quotation q) => new(
        q.Id, q.QuotationNumber, q.CustomerId, q.Status, q.Subtotal, q.OverallDiscountType, q.OverallDiscountValue,
        q.OverallDiscountAmount, q.TaxTotal, q.GrandTotal,
        q.Lines.Select(l => new DocumentLineDto(l.Id, l.ItemId, l.Description, l.Quantity, l.Rate, l.Discount, l.TaxRatePercent, l.CgstAmount, l.SgstAmount, l.IgstAmount, l.LineTotal, SerialNumbersCsv.Parse(l.SerialNumbersCsv), l.HsnCode)).ToList(), q.Notes, q.PlaceOfSupply,
        q.CreatedAt, q.CreatedBy);
}
