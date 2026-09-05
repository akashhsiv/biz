using Erp.Api.Auth;
using Erp.Application.Security;
using Erp.Domain.Common;
using Erp.Domain.Sales;
using Erp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Erp.Api.Controllers;

public record SalesByCustomerRow(Guid CustomerId, string CustomerName, decimal GrandTotal, int InvoiceCount);
public record SalesByItemRow(Guid ItemId, string ItemName, decimal Quantity, decimal LineTotal);
public record SalesSummaryDto(decimal TotalSales, int InvoiceCount, int QuotationCount, int ProformaCount, List<SalesByCustomerRow> ByCustomer, List<SalesByItemRow> ByItem);

public record PurchaseBySupplierRow(Guid SupplierId, string SupplierName, decimal GrandTotal, int OrderCount);
public record PurchaseSummaryDto(decimal TotalPurchases, int OrderCount, Dictionary<string, int> StatusCounts, Dictionary<string, int> PaymentStatusCounts, List<PurchaseBySupplierRow> BySupplier);

public record LowStockRow(Guid ItemId, string Sku, string Name, decimal QuantityOnHand);

public record FinanceSummaryDto(decimal AmountIn, decimal AmountOut, decimal Refunds, decimal Adjustments, decimal NetChange, decimal EndingBalance);
public record CustomerOutstandingRow(Guid CustomerId, string CustomerName, decimal OutstandingTotal, int OpenProformaCount);

public record AuditSummaryRow(string Action, int Count);

public record CustomerReportProductRow(Guid ItemId, string ItemName, decimal Quantity, decimal Amount);
public record CustomerReportActivityRow(DateTime Date, decimal Amount, int InvoiceCount);
public record CustomerReportRow(
    Guid CustomerId,
    string CustomerName,
    decimal TotalSales,
    decimal TotalOutstanding,
    decimal TotalPayments,
    int InvoiceCount,
    List<CustomerReportProductRow> Products,
    List<CustomerReportActivityRow> DateWiseActivity);
// TODO(commission-module): once a Commission entity/module exists, add per-customer commission totals here.

[ApiController]
[Route("api/reports")]
public class ReportsController(ErpDbContext db) : ControllerBase
{
    [HttpGet("sales")]
    [RequirePermission(PermissionKeys.ReportsSalesView)]
    public async Task<ActionResult<SalesSummaryDto>> Sales([FromQuery] DateTime? from, [FromQuery] DateTime? to, CancellationToken ct)
    {
        var (start, end) = Range(from, to);

        var invoices = await db.SalesInvoices.Include(i => i.Lines)
            .Where(i => i.Status == SalesInvoiceStatus.Active && i.CreatedAt >= start && i.CreatedAt < end)
            .ToListAsync(ct);

        var quotationCount = await db.Quotations.CountAsync(q => q.CreatedAt >= start && q.CreatedAt < end, ct);
        var proformaCount = await db.ProformaInvoices.CountAsync(p => p.CreatedAt >= start && p.CreatedAt < end, ct);

        var customerNames = await db.Customers.ToDictionaryAsync(c => c.Id, c => c.Name, ct);
        var itemNames = await db.Items.ToDictionaryAsync(i => i.Id, i => i.Name, ct);

        var byCustomer = invoices.GroupBy(i => i.CustomerId)
            .Select(g => new SalesByCustomerRow(g.Key, customerNames.GetValueOrDefault(g.Key, "?"), g.Sum(i => i.GrandTotal), g.Count()))
            .OrderByDescending(r => r.GrandTotal).ToList();

        var byItem = invoices.SelectMany(i => i.Lines).Where(l => l.ItemId is not null)
            .GroupBy(l => l.ItemId!.Value)
            .Select(g => new SalesByItemRow(g.Key, itemNames.GetValueOrDefault(g.Key, "?"), g.Sum(l => l.Quantity), g.Sum(l => l.LineTotal)))
            .OrderByDescending(r => r.LineTotal).ToList();

        return Ok(new SalesSummaryDto(invoices.Sum(i => i.GrandTotal), invoices.Count, quotationCount, proformaCount, byCustomer, byItem));
    }

    [HttpGet("purchase")]
    [RequirePermission(PermissionKeys.ReportsPurchaseView)]
    public async Task<ActionResult<PurchaseSummaryDto>> Purchase([FromQuery] DateTime? from, [FromQuery] DateTime? to, CancellationToken ct)
    {
        var (start, end) = Range(from, to);

        var orders = await db.PurchaseOrders.Where(o => o.CreatedAt >= start && o.CreatedAt < end).ToListAsync(ct);
        var supplierNames = await db.Suppliers.ToDictionaryAsync(s => s.Id, s => s.Name, ct);

        var statusCounts = orders.GroupBy(o => o.Status.ToString()).ToDictionary(g => g.Key, g => g.Count());
        var paymentStatusCounts = orders.GroupBy(o => o.PaymentStatus.ToString()).ToDictionary(g => g.Key, g => g.Count());

        var bySupplier = orders.GroupBy(o => o.SupplierId)
            .Select(g => new PurchaseBySupplierRow(g.Key, supplierNames.GetValueOrDefault(g.Key, "?"), g.Sum(o => o.GrandTotal), g.Count()))
            .OrderByDescending(r => r.GrandTotal).ToList();

        return Ok(new PurchaseSummaryDto(orders.Sum(o => o.GrandTotal), orders.Count, statusCounts, paymentStatusCounts, bySupplier));
    }

    [HttpGet("stock/low")]
    [RequirePermission(PermissionKeys.StockView)]
    public async Task<ActionResult<List<LowStockRow>>> LowStock([FromQuery] decimal threshold = 10, CancellationToken ct = default)
    {
        var rows = await db.Items.Where(i => i.ItemKind == ItemKind.Stock && i.StockBalance!.QuantityOnHand <= threshold)
            .OrderBy(i => i.StockBalance!.QuantityOnHand)
            .Select(i => new LowStockRow(i.Id, i.Sku, i.Name, i.StockBalance!.QuantityOnHand))
            .ToListAsync(ct);

        return Ok(rows);
    }

    [HttpGet("finance")]
    [RequirePermission(PermissionKeys.ReportsFinanceView)]
    public async Task<ActionResult<FinanceSummaryDto>> Finance([FromQuery] DateTime? from, [FromQuery] DateTime? to, CancellationToken ct)
    {
        var (start, end) = Range(from, to);

        var transactions = await db.FinancialTransactions
            .Where(t => t.CreatedAt >= start && t.CreatedAt < end)
            .Select(t => new { t.TransactionType, t.Direction, t.Amount })
            .ToListAsync(ct);

        decimal Sum(FinancialTransactionType type) => transactions.Where(t => t.TransactionType == type)
            .Sum(t => t.Direction == FinancialDirection.Credit ? t.Amount : -t.Amount);

        var amountIn = Sum(FinancialTransactionType.AmountIn);
        var amountOut = -Sum(FinancialTransactionType.AmountOut);
        var refunds = -Sum(FinancialTransactionType.Refund);
        var adjustments = Sum(FinancialTransactionType.Adjustment);
        var purchasePayments = -Sum(FinancialTransactionType.PurchasePayment);

        var netChange = amountIn - amountOut - refunds + adjustments - purchasePayments;
        var endingBalanceAllTime = await db.FinancialTransactions
            .Where(t => t.CreatedAt < end)
            .Select(t => new { t.TransactionType, t.Direction, t.Amount })
            .ToListAsync(ct);

        var endingBalance = endingBalanceAllTime
            .Where(t => t.TransactionType is FinancialTransactionType.AmountIn or FinancialTransactionType.AmountOut
                or FinancialTransactionType.Refund or FinancialTransactionType.Adjustment or FinancialTransactionType.PurchasePayment)
            .Sum(t => t.Direction == FinancialDirection.Credit ? t.Amount : -t.Amount);

        return Ok(new FinanceSummaryDto(amountIn, amountOut + purchasePayments, refunds, adjustments, netChange, endingBalance));
    }

    [HttpGet("finance/outstanding")]
    [RequirePermission(PermissionKeys.ReportsFinanceView)]
    public async Task<ActionResult<List<CustomerOutstandingRow>>> Outstanding(CancellationToken ct)
    {
        var openProformas = await db.ProformaInvoices
            .Where(p => p.Status == ProformaStatus.Open && p.OutstandingTotal > 0)
            .ToListAsync(ct);

        var customerNames = await db.Customers.ToDictionaryAsync(c => c.Id, c => c.Name, ct);

        var rows = openProformas.GroupBy(p => p.CustomerId)
            .Select(g => new CustomerOutstandingRow(g.Key, customerNames.GetValueOrDefault(g.Key, "?"), g.Sum(p => p.OutstandingTotal), g.Count()))
            .OrderByDescending(r => r.OutstandingTotal).ToList();

        return Ok(rows);
    }

    [HttpGet("customer")]
    [RequirePermission(PermissionKeys.ReportsCustomerView)]
    public async Task<ActionResult<List<CustomerReportRow>>> Customer(
        [FromQuery] DateTime? from, [FromQuery] DateTime? to, [FromQuery] Guid? customerId,
        [FromQuery] int page = 1, [FromQuery] int pageSize = 50, CancellationToken ct = default)
    {
        var (start, end) = Range(from, to);

        var customersQuery = db.Customers.AsQueryable();
        if (customerId is not null) customersQuery = customersQuery.Where(c => c.Id == customerId);

        var customers = await customersQuery
            .OrderBy(c => c.Name)
            .Skip((Math.Max(page, 1) - 1) * pageSize)
            .Take(pageSize)
            .Select(c => new { c.Id, c.Name })
            .ToListAsync(ct);

        if (customers.Count == 0) return Ok(new List<CustomerReportRow>());

        var customerIds = customers.Select(c => c.Id).ToHashSet();

        // Sales invoices in range, for the selected customers.
        var invoices = await db.SalesInvoices.Include(i => i.Lines)
            .Where(i => i.Status == SalesInvoiceStatus.Active && i.CreatedAt >= start && i.CreatedAt < end
                && customerIds.Contains(i.CustomerId))
            .ToListAsync(ct);

        // Outstanding: open proformas per customer (same shape as finance/outstanding), not date-range filtered
        // since outstanding is a point-in-time balance rather than an activity-in-range figure.
        var outstandingByCustomer = await db.ProformaInvoices
            .Where(p => p.Status == ProformaStatus.Open && p.OutstandingTotal > 0 && customerIds.Contains(p.CustomerId))
            .GroupBy(p => p.CustomerId)
            .Select(g => new { CustomerId = g.Key, Total = g.Sum(p => p.OutstandingTotal) })
            .ToDictionaryAsync(g => g.CustomerId, g => g.Total, ct);

        // Payments received: Amount In transactions against the customer within the date range.
        var paymentsByCustomer = await db.FinancialTransactions
            .Where(t => t.TransactionType == FinancialTransactionType.AmountIn && t.CustomerId != null
                && customerIds.Contains(t.CustomerId!.Value) && t.CreatedAt >= start && t.CreatedAt < end)
            .GroupBy(t => t.CustomerId!.Value)
            .Select(g => new { CustomerId = g.Key, Total = g.Sum(t => t.Direction == FinancialDirection.Credit ? t.Amount : -t.Amount) })
            .ToDictionaryAsync(g => g.CustomerId, g => g.Total, ct);

        var itemNames = await db.Items.ToDictionaryAsync(i => i.Id, i => i.Name, ct);

        var invoicesByCustomer = invoices.GroupBy(i => i.CustomerId).ToDictionary(g => g.Key, g => g.ToList());

        var rows = customers.Select(c =>
        {
            var customerInvoices = invoicesByCustomer.GetValueOrDefault(c.Id, []);

            var products = customerInvoices.SelectMany(i => i.Lines).Where(l => l.ItemId is not null)
                .GroupBy(l => l.ItemId!.Value)
                .Select(g => new CustomerReportProductRow(g.Key, itemNames.GetValueOrDefault(g.Key, "?"), g.Sum(l => l.Quantity), g.Sum(l => l.LineTotal)))
                .OrderByDescending(r => r.Amount).ToList();

            var dateWiseActivity = customerInvoices.GroupBy(i => i.CreatedAt.Date)
                .Select(g => new CustomerReportActivityRow(g.Key, g.Sum(i => i.GrandTotal), g.Count()))
                .OrderBy(r => r.Date).ToList();

            return new CustomerReportRow(
                c.Id,
                c.Name,
                customerInvoices.Sum(i => i.GrandTotal),
                outstandingByCustomer.GetValueOrDefault(c.Id, 0m),
                paymentsByCustomer.GetValueOrDefault(c.Id, 0m),
                customerInvoices.Count,
                products,
                dateWiseActivity);
        }).ToList();

        return Ok(rows);
    }

    [HttpGet("audit")]
    [RequirePermission(PermissionKeys.AuditLogsView)]
    public async Task<ActionResult<List<AuditSummaryRow>>> Audit([FromQuery] DateTime? from, [FromQuery] DateTime? to, CancellationToken ct)
    {
        var (start, end) = Range(from, to);

        var rows = await db.AuditLogs.Where(a => a.CreatedAt >= start && a.CreatedAt < end)
            .GroupBy(a => a.Action)
            .Select(g => new AuditSummaryRow(g.Key, g.Count()))
            .ToListAsync(ct);

        return Ok(rows.OrderByDescending(r => r.Count).ToList());
    }

    private static (DateTime start, DateTime end) Range(DateTime? from, DateTime? to)
    {
        var end = (to ?? DateTime.UtcNow).Date.AddDays(1);
        var start = (from ?? end.AddDays(-30)).Date;
        return (start, end);
    }
}
