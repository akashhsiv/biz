using Erp.Application.Commission;
using Erp.Domain.Commission;
using Erp.Domain.Common;
using Erp.Domain.Sales;
using Erp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace Erp.Infrastructure.Services;

/// <summary>
/// PROVISIONAL — pending business sign-off on what "commission" actually means (paid to the
/// customer, earned through the customer, a discount, or something else entirely — see
/// CustomerProductRate doc comment). Kept deliberately simple and isolated so the formula/trigger
/// can be swapped without touching SalesInvoice creation code: callers only need to call
/// CalculateForInvoiceAsync once, after building the invoice + lines.
///
/// Current formula (provisional — confirm with business):
///     CommissionEntry.Amount = SalesInvoiceLine.LineTotal * CustomerProductRate.CommissionRate / 100
/// i.e. CommissionRate is treated as "percent of line total". This is the simplest possible
/// interpretation and is very likely to change once the business decision is made.
/// </summary>
public class CommissionCalculationService(ErpDbContext db) : ICommissionCalculationService
{
    public async Task CalculateForInvoiceAsync(SalesInvoice invoice, CancellationToken ct = default)
    {
        var itemIds = invoice.Lines.Where(l => l.ItemId.HasValue).Select(l => l.ItemId!.Value).Distinct().ToList();
        if (itemIds.Count == 0) return;

        var rates = await db.CustomerProductRates
            .Where(r => r.CustomerId == invoice.CustomerId && itemIds.Contains(r.ItemId) && r.IsActive && r.CommissionRate != null)
            .ToListAsync(ct);

        if (rates.Count == 0) return;

        var rateByItem = rates
            // If more than one active rate exists for the same item, prefer the most recently effective one.
            .GroupBy(r => r.ItemId)
            .ToDictionary(g => g.Key, g => g.OrderByDescending(r => r.EffectiveFrom).First());

        foreach (var line in invoice.Lines)
        {
            if (line.ItemId is not { } itemId) continue;
            if (!rateByItem.TryGetValue(itemId, out var rate)) continue;

            // Provisional formula — see class doc comment.
            var amount = Math.Round(line.LineTotal * rate.CommissionRate!.Value / 100m, 2);

            db.CommissionEntries.Add(new CommissionEntry
            {
                CustomerId = invoice.CustomerId,
                SalesInvoiceId = invoice.Id,
                ItemId = itemId,
                Amount = amount,
                Status = CommissionEntryStatus.Pending,
                PaidAmount = 0,
            });
        }
    }
}
