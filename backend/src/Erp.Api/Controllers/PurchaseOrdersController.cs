using Erp.Api.Auth;
using Erp.Application.Common;
using Erp.Application.Documents;
using Erp.Application.Finance;
using Erp.Application.Sales;
using Erp.Application.Security;
using Erp.Application.Stock;
using Erp.Domain.Common;
using Erp.Domain.Items;
using Erp.Domain.Purchases;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record PurchaseOrderLineRequest(Guid ItemId, decimal QuantityOrdered, decimal Rate);
public record CreatePurchaseOrderRequest(Guid SupplierId, List<PurchaseOrderLineRequest> Lines);

public record PurchaseOrderLineDto(Guid Id, Guid ItemId, decimal QuantityOrdered, decimal QuantityReceived, decimal Rate, decimal TaxRatePercent, decimal Cgst, decimal Sgst, decimal Igst, decimal LineTotal);
public record PurchaseOrderDto(Guid Id, string PoNumber, Guid SupplierId, PurchaseOrderStatus Status, PurchasePaymentStatus PaymentStatus, decimal Subtotal, decimal TaxTotal, decimal GrandTotal, List<PurchaseOrderLineDto> Lines, List<PurchasePaymentDto> Payments, DateTime CreatedAt, Guid CreatedBy);

public record PurchaseReceiptLineRequest(Guid PoLineId, decimal QuantityReceived, string? BatchNumber, DateTime? ExpiryDate, List<string>? SerialNumbers);
public record CreatePurchaseReceiptRequest(List<PurchaseReceiptLineRequest> Lines);
public record PurchaseReceiptDto(Guid Id, string ReceiptNumber, Guid PurchaseOrderId, DateTime ReceivedAt, PurchaseOrderStatus PurchaseOrderStatus);

public record CreatePurchasePaymentRequest(decimal Amount, string? PaymentMethod);
public record PurchasePaymentDto(Guid Id, Guid PurchaseOrderId, decimal Amount, PurchasePaymentStatus Status, string? PaymentMethod);

public record CancelPurchaseOrderRequest(string Reason);

[ApiController]
[Route("api/purchase-orders")]
public class PurchaseOrdersController(
    ErpDbContext db,
    IAuditService audit,
    IFinanceLedgerService ledger,
    IStockService stock,
    IDocumentNumberService documentNumbers,
    ICurrentUserService currentUser,
    IDocumentPdfService pdfService) : ControllerBase
{
    [HttpGet("{id:guid}/pdf")]
    [RequirePermission(PermissionKeys.PurchaseOrdersManage)]
    public async Task<IActionResult> Pdf(Guid id, CancellationToken ct)
    {
        var pdf = await pdfService.RenderPurchaseOrderAsync(id, ct);
        return File(pdf.Bytes, "application/pdf", pdf.FileName);
    }

    [HttpGet]
    [RequirePermission(PermissionKeys.PurchaseOrdersManage)]
    public async Task<ActionResult<List<PurchaseOrderDto>>> List([FromQuery] Guid? supplierId, CancellationToken ct)
    {
        var query = db.PurchaseOrders.Include(p => p.Lines).Include(p => p.Payments).AsQueryable();
        if (supplierId is { } id) query = query.Where(p => p.SupplierId == id);

        var orders = await query.OrderByDescending(p => p.CreatedAt).ToListAsync(ct);
        return Ok(orders.Select(ToDto));
    }

    [HttpGet("{id:guid}")]
    [RequirePermission(PermissionKeys.PurchaseOrdersManage)]
    public async Task<ActionResult<PurchaseOrderDto>> Get(Guid id, CancellationToken ct)
    {
        var order = await db.PurchaseOrders.Include(p => p.Lines).Include(p => p.Payments).FirstOrDefaultAsync(p => p.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(PurchaseOrder), id);

        return Ok(ToDto(order));
    }

    [HttpPost]
    [RequirePermission(PermissionKeys.PurchaseOrdersManage)]
    public async Task<ActionResult<PurchaseOrderDto>> Create(CreatePurchaseOrderRequest request, CancellationToken ct)
    {
        if (request.Lines.Count == 0) throw new ValidationAppException("A purchase order must have at least one line.");

        var supplier = await db.Suppliers.FirstOrDefaultAsync(s => s.Id == request.SupplierId && s.IsActive, ct)
            ?? throw new NotFoundAppException(nameof(Supplier), request.SupplierId);

        var settings = await db.CompanySettings.AsNoTracking().FirstOrDefaultAsync(ct)
            ?? throw new ConflictAppException("Company settings have not been configured.");

        var itemIds = request.Lines.Select(l => l.ItemId).Distinct().ToList();
        var items = await db.Items.Where(i => itemIds.Contains(i.Id)).ToDictionaryAsync(i => i.Id, ct);

        var lines = new List<PurchaseOrderLine>();
        decimal subtotal = 0, taxTotal = 0;

        foreach (var lineRequest in request.Lines)
        {
            if (!items.TryGetValue(lineRequest.ItemId, out var item))
                throw new NotFoundAppException(nameof(Item), lineRequest.ItemId);

            if (lineRequest.QuantityOrdered <= 0) throw new ValidationAppException("Quantity ordered must be greater than zero.");

            var gross = Math.Round(lineRequest.QuantityOrdered * lineRequest.Rate, 2);
            var rate = item.TaxRatePercent;
            var split = TaxCalculator.Split(gross, rate, settings.State, supplier.State);

            subtotal += gross;
            taxTotal += split.Total;

            lines.Add(new PurchaseOrderLine
            {
                ItemId = item.Id,
                QuantityOrdered = lineRequest.QuantityOrdered,
                Rate = lineRequest.Rate,
                TaxRatePercent = rate,
                CgstAmount = split.Cgst,
                SgstAmount = split.Sgst,
                IgstAmount = split.Igst,
                LineTotal = gross + split.Total,
            });
        }

        var order = new PurchaseOrder
        {
            PoNumber = await documentNumbers.NextNumberAsync("purchase_order", "PO", ct),
            FinancialYear = documentNumbers.CurrentFinancialYear(),
            SupplierId = supplier.Id,
            Status = PurchaseOrderStatus.Draft,
            PaymentStatus = PurchasePaymentStatus.Processing,
            Subtotal = subtotal,
            TaxTotal = taxTotal,
            GrandTotal = subtotal + taxTotal,
            Lines = lines,
        };

        db.PurchaseOrders.Add(order);
        await audit.LogAsync("po.created", nameof(PurchaseOrder), order.Id, newValue: new { order.PoNumber, order.GrandTotal }, ct: ct);
        await db.SaveChangesAsync(ct);

        return Ok(ToDto(order));
    }

    [HttpPost("{id:guid}/submit")]
    [RequirePermission(PermissionKeys.PurchaseOrdersManage)]
    public async Task<IActionResult> Submit(Guid id, CancellationToken ct)
    {
        var order = await db.PurchaseOrders.FirstOrDefaultAsync(p => p.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(PurchaseOrder), id);

        if (order.Status != PurchaseOrderStatus.Draft)
            throw new ConflictAppException($"Only a Draft PO can be submitted (current status: {order.Status}).");

        var oldStatus = order.Status;
        order.Status = PurchaseOrderStatus.Submitted;
        await audit.LogAsync("po.status_changed", nameof(PurchaseOrder), order.Id, oldStatus, order.Status, ct: ct);
        await db.SaveChangesAsync(ct);

        return NoContent();
    }

    /// <summary>Records goods received against PO lines; creates a stock movement (and a new batch for batch-tracked items) per line, and advances PO.Status based on receipt completeness — independent of PaymentStatus per ARCHITECTURE.md §26.</summary>
    [HttpPost("{id:guid}/receipts")]
    [RequirePermission(PermissionKeys.PurchaseReceiptsManage)]
    public async Task<ActionResult<PurchaseReceiptDto>> Receive(Guid id, CreatePurchaseReceiptRequest request, CancellationToken ct)
    {
        if (request.Lines.Count == 0) throw new ValidationAppException("A receipt must have at least one line.");

        var order = await db.PurchaseOrders.Include(p => p.Lines).ThenInclude(l => l.Item)
            .FirstOrDefaultAsync(p => p.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(PurchaseOrder), id);

        if (order.Status is PurchaseOrderStatus.Draft or PurchaseOrderStatus.Cancelled or PurchaseOrderStatus.Completed)
            throw new ConflictAppException($"Cannot record a receipt against a PO with status {order.Status}.");

        await using var tx = await db.Database.BeginTransactionAsync(ct);

        var receiptNumber = await documentNumbers.NextNumberAsync("purchase_receipt", "GRN", ct);
        var receipt = new PurchaseReceipt
        {
            ReceiptNumber = receiptNumber,
            FinancialYear = documentNumbers.CurrentFinancialYear(),
            PurchaseOrderId = order.Id,
            ReceivedBy = currentUser.UserId,
            ReceivedAt = DateTime.UtcNow,
        };

        foreach (var lineRequest in request.Lines)
        {
            var poLine = order.Lines.FirstOrDefault(l => l.Id == lineRequest.PoLineId)
                ?? throw new NotFoundAppException(nameof(PurchaseOrderLine), lineRequest.PoLineId);

            if (lineRequest.QuantityReceived <= 0)
                throw new ValidationAppException("Quantity received must be greater than zero.");

            if (poLine.QuantityReceived + lineRequest.QuantityReceived > poLine.QuantityOrdered)
                throw new ValidationAppException($"Receiving {lineRequest.QuantityReceived} would exceed the ordered quantity for item '{poLine.Item.Name}'.");

            if (poLine.Item.IsSerialTracked && (lineRequest.SerialNumbers?.Count ?? 0) != (int)lineRequest.QuantityReceived)
                throw new ValidationAppException($"Enter exactly {(int)lineRequest.QuantityReceived} serial number(s) for item '{poLine.Item.Name}'.");

            var batchId = await stock.IncrementAsync(
                poLine.ItemId, lineRequest.QuantityReceived, DocumentReferenceType.PurchaseReceipt, receipt.Id,
                reason: $"Receipt {receiptNumber} against PO {order.PoNumber}",
                newBatchNumber: poLine.Item.IsBatchTracked ? lineRequest.BatchNumber ?? $"{order.PoNumber}-{poLine.Item.Sku}" : null,
                expiryDate: lineRequest.ExpiryDate,
                newSerialNumbers: poLine.Item.IsSerialTracked ? lineRequest.SerialNumbers : null, ct: ct);

            poLine.QuantityReceived += lineRequest.QuantityReceived;

            receipt.Lines.Add(new PurchaseReceiptLine
            {
                PoLineId = poLine.Id,
                QuantityReceived = lineRequest.QuantityReceived,
                ItemBatchId = batchId,
            });
        }

        db.PurchaseReceipts.Add(receipt);

        var totalOrdered = order.Lines.Sum(l => l.QuantityOrdered);
        var totalReceived = order.Lines.Sum(l => l.QuantityReceived);
        order.Status = totalReceived >= totalOrdered ? PurchaseOrderStatus.Completed : PurchaseOrderStatus.Processing;

        await audit.LogAsync("purchase_receipt.created", nameof(PurchaseReceipt), receipt.Id, newValue: new { receipt.ReceiptNumber, order.Status }, ct: ct);

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        return Ok(new PurchaseReceiptDto(receipt.Id, receipt.ReceiptNumber, order.Id, receipt.ReceivedAt, order.Status));
    }

    /// <summary>Cancels the un-received remainder of a PO. Any payment still Processing must be resolved first (default rule — ARCHITECTURE.md §13 item 6).</summary>
    [HttpPost("{id:guid}/cancel")]
    [RequirePermission(PermissionKeys.PurchaseOrdersManage)]
    public async Task<IActionResult> Cancel(Guid id, CancelPurchaseOrderRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Reason))
            throw new ValidationAppException("A reason is required to cancel a purchase order.");

        var order = await db.PurchaseOrders.Include(p => p.Lines).Include(p => p.Payments).FirstOrDefaultAsync(p => p.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(PurchaseOrder), id);

        if (order.Status is PurchaseOrderStatus.Completed or PurchaseOrderStatus.Cancelled)
            throw new ConflictAppException($"PO cannot be cancelled from status {order.Status}.");

        if (order.Payments.Any(p => p.Status == PurchasePaymentStatus.Processing))
            throw new ConflictAppException("Resolve (complete or cancel) all in-progress payments before cancelling this PO.");

        var hasAnyReceipt = order.Lines.Any(l => l.QuantityReceived > 0);
        order.Status = hasAnyReceipt ? PurchaseOrderStatus.PartiallyCompleted : PurchaseOrderStatus.Cancelled;

        await audit.LogAsync("po.status_changed", nameof(PurchaseOrder), order.Id, reason: request.Reason, newValue: order.Status, ct: ct);
        await db.SaveChangesAsync(ct);

        return NoContent();
    }

    [HttpPost("{id:guid}/payments")]
    [RequirePermission(PermissionKeys.PurchasePaymentsInitiate)]
    public async Task<ActionResult<PurchasePaymentDto>> CreatePayment(Guid id, CreatePurchasePaymentRequest request, CancellationToken ct)
    {
        if (request.Amount <= 0) throw new ValidationAppException("Payment amount must be positive.");

        var order = await db.PurchaseOrders.FirstOrDefaultAsync(p => p.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(PurchaseOrder), id);

        var payment = new PurchasePayment
        {
            PurchaseOrderId = order.Id,
            Amount = request.Amount,
            Status = PurchasePaymentStatus.Processing,
            PaymentMethod = request.PaymentMethod,
        };

        db.PurchasePayments.Add(payment);
        order.PaymentStatus = PurchasePaymentStatus.Processing;

        await audit.LogAsync("payment.created", nameof(PurchasePayment), payment.Id, newValue: new { order.PoNumber, request.Amount }, ct: ct);
        await db.SaveChangesAsync(ct);

        return Ok(new PurchasePaymentDto(payment.Id, order.Id, payment.Amount, payment.Status, payment.PaymentMethod));
    }

    /// <summary>Completing a payment writes the Amount Out ledger entry — PO creation itself is never an automatic financial transaction (ARCHITECTURE.md §26).</summary>
    [HttpPost("{id:guid}/payments/{paymentId:guid}/complete")]
    [RequirePermission(PermissionKeys.PurchasePaymentsApprove)]
    public async Task<IActionResult> CompletePayment(Guid id, Guid paymentId, CancellationToken ct)
    {
        var order = await db.PurchaseOrders.Include(p => p.Payments).FirstOrDefaultAsync(p => p.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(PurchaseOrder), id);

        var payment = order.Payments.FirstOrDefault(p => p.Id == paymentId)
            ?? throw new NotFoundAppException(nameof(PurchasePayment), paymentId);

        if (payment.Status != PurchasePaymentStatus.Processing)
            throw new ConflictAppException($"Only a Processing payment can be completed (current status: {payment.Status}).");

        await using var tx = await db.Database.BeginTransactionAsync(ct);

        var transactionId = await ledger.RecordAmountOutAsync(payment.Amount, $"Purchase payment for PO {order.PoNumber}", DocumentReferenceType.PurchaseReceipt, order.Id, ct);

        payment.Status = PurchasePaymentStatus.Completed;
        payment.FinancialTransactionId = transactionId;

        order.PaymentStatus = order.Payments.All(p => p.Status == PurchasePaymentStatus.Completed)
            ? PurchasePaymentStatus.Completed
            : PurchasePaymentStatus.Processing;

        await audit.LogAsync("payment.status_changed", nameof(PurchasePayment), payment.Id, newValue: payment.Status, ct: ct);

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        return NoContent();
    }

    private static PurchaseOrderDto ToDto(PurchaseOrder o) => new(
        o.Id, o.PoNumber, o.SupplierId, o.Status, o.PaymentStatus, o.Subtotal, o.TaxTotal, o.GrandTotal,
        o.Lines.Select(l => new PurchaseOrderLineDto(l.Id, l.ItemId, l.QuantityOrdered, l.QuantityReceived, l.Rate, l.TaxRatePercent, l.CgstAmount, l.SgstAmount, l.IgstAmount, l.LineTotal)).ToList(),
        o.Payments.Select(p => new PurchasePaymentDto(p.Id, p.PurchaseOrderId, p.Amount, p.Status, p.PaymentMethod)).ToList(),
        o.CreatedAt, o.CreatedBy);
}
