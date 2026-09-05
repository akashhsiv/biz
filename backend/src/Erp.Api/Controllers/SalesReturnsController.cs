using Erp.Api.Auth;
using Erp.Application.Common;
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

public record RequestReturnLineRequest(Guid SalesInvoiceLineId, decimal QuantityReturned, bool Restock);
public record RequestReturnRequest(Guid SalesInvoiceId, string Reason, List<RequestReturnLineRequest> Lines);

public record SalesReturnLineDto(Guid Id, Guid SalesInvoiceLineId, string Description, decimal QuantityReturned, decimal RefundAmount, bool Restock);
public record SalesReturnDto(
    Guid Id, string ReturnNumber, Guid SalesInvoiceId, Guid CustomerId, SalesReturnStatus Status,
    string? Reason, RefundMethod? RefundMethod, decimal TotalRefundAmount, List<SalesReturnLineDto> Lines, DateTime CreatedAt);

public record CompleteReturnRequest(RefundMethod RefundMethod);
public record RejectReturnRequest(string Reason);

[ApiController]
[Route("api/sales-returns")]
public class SalesReturnsController(
    ErpDbContext db,
    IAuditService audit,
    IFinanceLedgerService ledger,
    IStockService stock,
    IDocumentNumberService documentNumbers,
    ICurrentUserService currentUser) : ControllerBase
{
    [HttpGet]
    [RequirePermission(PermissionKeys.SalesReturnsRequest)]
    public async Task<ActionResult<List<SalesReturnDto>>> List([FromQuery] Guid? customerId, CancellationToken ct)
    {
        var query = db.SalesReturns.Include(r => r.Lines).ThenInclude(l => l.SalesInvoiceLine).AsQueryable();
        if (customerId is { } id) query = query.Where(r => r.CustomerId == id);

        var returns = await query.OrderByDescending(r => r.CreatedAt).ToListAsync(ct);
        return Ok(returns.Select(ToDto));
    }

    [HttpGet("{id:guid}")]
    [RequirePermission(PermissionKeys.SalesReturnsRequest)]
    public async Task<ActionResult<SalesReturnDto>> Get(Guid id, CancellationToken ct)
    {
        var salesReturn = await db.SalesReturns.Include(r => r.Lines).ThenInclude(l => l.SalesInvoiceLine).FirstOrDefaultAsync(r => r.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(SalesReturn), id);

        return Ok(ToDto(salesReturn));
    }

    [HttpPost]
    [RequirePermission(PermissionKeys.SalesReturnsRequest)]
    public async Task<ActionResult<SalesReturnDto>> RequestReturn(RequestReturnRequest request, CancellationToken ct)
    {
        if (request.Lines.Count == 0) throw new ValidationAppException("A return must have at least one line.");
        if (string.IsNullOrWhiteSpace(request.Reason)) throw new ValidationAppException("A reason is required to request a return.");

        var invoice = await db.SalesInvoices.Include(i => i.Lines).FirstOrDefaultAsync(i => i.Id == request.SalesInvoiceId, ct)
            ?? throw new NotFoundAppException(nameof(SalesInvoice), request.SalesInvoiceId);

        if (invoice.Status != SalesInvoiceStatus.Active)
            throw new ConflictAppException("Cannot return against a cancelled sales invoice.");

        var salesReturn = new SalesReturn
        {
            ReturnNumber = await documentNumbers.NextNumberAsync("sales_return", "SRN", ct),
            FinancialYear = documentNumbers.CurrentFinancialYear(),
            SalesInvoiceId = invoice.Id,
            CustomerId = invoice.CustomerId,
            Status = SalesReturnStatus.Requested,
            Reason = request.Reason,
        };

        decimal totalRefund = 0;

        foreach (var lineRequest in request.Lines)
        {
            var invoiceLine = invoice.Lines.FirstOrDefault(l => l.Id == lineRequest.SalesInvoiceLineId)
                ?? throw new NotFoundAppException(nameof(SalesInvoiceLine), lineRequest.SalesInvoiceLineId);

            if (lineRequest.QuantityReturned <= 0 || lineRequest.QuantityReturned > invoiceLine.Quantity)
                throw new ValidationAppException($"Invalid return quantity for line '{invoiceLine.Description}'.");

            var refundAmount = Math.Round(invoiceLine.LineTotal / invoiceLine.Quantity * lineRequest.QuantityReturned, 2);
            totalRefund += refundAmount;

            salesReturn.Lines.Add(new SalesReturnLine
            {
                SalesInvoiceLineId = invoiceLine.Id,
                SalesInvoiceLine = invoiceLine,
                QuantityReturned = lineRequest.QuantityReturned,
                RefundAmount = refundAmount,
                Restock = lineRequest.Restock,
            });
        }

        salesReturn.TotalRefundAmount = totalRefund;

        db.SalesReturns.Add(salesReturn);
        await audit.LogAsync("return.created", nameof(SalesReturn), salesReturn.Id, newValue: new { salesReturn.ReturnNumber, totalRefund }, ct: ct);
        await db.SaveChangesAsync(ct);

        return Ok(ToDto(salesReturn));
    }

    [HttpPost("{id:guid}/approve")]
    [RequirePermission(PermissionKeys.SalesReturnsApprove)]
    public async Task<IActionResult> Approve(Guid id, CancellationToken ct)
    {
        var salesReturn = await db.SalesReturns.FirstOrDefaultAsync(r => r.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(SalesReturn), id);

        if (salesReturn.Status != SalesReturnStatus.Requested)
            throw new ConflictAppException($"Only a Requested return can be approved (current status: {salesReturn.Status}).");

        salesReturn.Status = SalesReturnStatus.Approved;
        salesReturn.ApprovedBy = currentUser.UserId;
        salesReturn.ApprovedAt = DateTime.UtcNow;

        await audit.LogAsync("return.approved", nameof(SalesReturn), salesReturn.Id, ct: ct);
        await db.SaveChangesAsync(ct);

        return NoContent();
    }

    [HttpPost("{id:guid}/reject")]
    [RequirePermission(PermissionKeys.SalesReturnsApprove)]
    public async Task<IActionResult> Reject(Guid id, RejectReturnRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Reason))
            throw new ValidationAppException("A reason is required to reject a return.");

        var salesReturn = await db.SalesReturns.FirstOrDefaultAsync(r => r.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(SalesReturn), id);

        if (salesReturn.Status != SalesReturnStatus.Requested)
            throw new ConflictAppException($"Only a Requested return can be rejected (current status: {salesReturn.Status}).");

        salesReturn.Status = SalesReturnStatus.Rejected;
        await audit.LogAsync("return.rejected", nameof(SalesReturn), salesReturn.Id, reason: request.Reason, ct: ct);
        await db.SaveChangesAsync(ct);

        return NoContent();
    }

    /// <summary>Refund method is chosen here per-return (confirmed decision) — restocks approved lines and writes the corresponding financial transaction, atomically. The original sale is never modified.</summary>
    [HttpPost("{id:guid}/complete")]
    [RequirePermission(PermissionKeys.SalesReturnsApprove)]
    public async Task<IActionResult> Complete(Guid id, CompleteReturnRequest request, CancellationToken ct)
    {
        var salesReturn = await db.SalesReturns.Include(r => r.Lines).ThenInclude(l => l.SalesInvoiceLine).FirstOrDefaultAsync(r => r.Id == id, ct)
            ?? throw new NotFoundAppException(nameof(SalesReturn), id);

        if (salesReturn.Status != SalesReturnStatus.Approved)
            throw new ConflictAppException($"Only an Approved return can be completed (current status: {salesReturn.Status}).");

        var invoice = await db.SalesInvoices.FirstAsync(i => i.Id == salesReturn.SalesInvoiceId, ct);
        var (stockRefType, stockRefId) = invoice.SourceType == SalesInvoiceSourceType.ProformaConversion
            ? (DocumentReferenceType.ProformaInvoice, invoice.SourceId)
            : (DocumentReferenceType.SalesInvoice, invoice.Id);

        await using var tx = await db.Database.BeginTransactionAsync(ct);

        foreach (var line in salesReturn.Lines.Where(l => l.Restock))
        {
            var itemId = line.SalesInvoiceLine.ItemId;
            if (itemId is null) continue;

            var item = await db.Items.AsNoTracking().FirstAsync(i => i.Id == itemId.Value, ct);
            if (item.ItemKind != ItemKind.Stock) continue;

            var originalMovement = await db.StockMovements.AsNoTracking()
                .Where(m => m.ReferenceType == stockRefType && m.ReferenceId == stockRefId && m.ItemId == itemId.Value)
                .FirstOrDefaultAsync(ct);

            await stock.IncrementAsync(itemId.Value, line.QuantityReturned, DocumentReferenceType.SalesReturn, salesReturn.Id,
                reason: $"Return {salesReturn.ReturnNumber}", existingBatchId: originalMovement?.BatchId, ct: ct);
        }

        // Re-tag the restock movement(s) just written as Return type instead of the default inferred type.
        foreach (var movement in db.ChangeTracker.Entries<Erp.Domain.Items.StockMovement>().Where(e => e.State == EntityState.Added))
        {
            movement.Entity.MovementType = StockMovementType.Return;
        }

        if (request.RefundMethod == RefundMethod.CashAmountOut)
        {
            await ledger.RecordCashRefundAsync(salesReturn.CustomerId, salesReturn.TotalRefundAmount, DocumentReferenceType.SalesReturn, salesReturn.Id, ct);
        }
        else
        {
            await ledger.CreditDepositAsync(salesReturn.CustomerId, salesReturn.TotalRefundAmount, "return_credit", $"Return {salesReturn.ReturnNumber}", ct);
        }

        salesReturn.Status = SalesReturnStatus.Completed;
        salesReturn.RefundMethod = request.RefundMethod;

        await audit.LogAsync("return.completed", nameof(SalesReturn), salesReturn.Id, newValue: new { request.RefundMethod, salesReturn.TotalRefundAmount }, ct: ct);

        await db.SaveChangesAsync(ct);
        await tx.CommitAsync(ct);

        return NoContent();
    }

    private static SalesReturnDto ToDto(SalesReturn r) => new(
        r.Id, r.ReturnNumber, r.SalesInvoiceId, r.CustomerId, r.Status, r.Reason, r.RefundMethod, r.TotalRefundAmount,
        r.Lines.Select(l => new SalesReturnLineDto(l.Id, l.SalesInvoiceLineId, l.SalesInvoiceLine.Description, l.QuantityReturned, l.RefundAmount, l.Restock)).ToList(),
        r.CreatedAt);
}
