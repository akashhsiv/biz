using Erp.Application.Common;
using Erp.Domain.Common;

namespace Erp.Application.Sales;

public record LineInput(Guid? ItemId, string Description, decimal Quantity, decimal Rate, decimal Discount, decimal TaxRatePercent);

public record LineResult(Guid? ItemId, string Description, decimal Quantity, decimal Rate, decimal Discount, decimal TaxRatePercent, decimal Cgst, decimal Sgst, decimal Igst, decimal LineTotal);

public record DocumentTotals(List<LineResult> Lines, decimal Subtotal, decimal TaxTotal, decimal OverallDiscountAmount, decimal GrandTotal);

/// <summary>
/// Shared server-side recalculation for quotations/proformas/sales invoices/purchase orders — client-supplied
/// totals are never trusted (ARCHITECTURE.md §41). Tax is computed per line on the post-line-discount amount;
/// the overall document discount is applied as a final reduction after tax (documented simplification —
/// flag if a different GST-on-net-of-all-discounts treatment is required).
/// </summary>
public static class DocumentTotalsCalculator
{
    public static DocumentTotals Calculate(IEnumerable<LineInput> lines, string shopState, string? counterpartyState, DiscountType? overallDiscountType, decimal overallDiscountValue)
    {
        var results = new List<LineResult>();
        decimal subtotal = 0, taxTotal = 0;

        foreach (var line in lines)
        {
            if (line.Quantity <= 0) throw new ValidationAppException("Line quantity must be greater than zero.");
            if (line.Rate < 0 || line.Discount < 0) throw new ValidationAppException("Rate and discount cannot be negative.");

            var gross = Math.Round(line.Quantity * line.Rate, 2);
            if (line.Discount > gross) throw new ValidationAppException($"Discount cannot exceed the line amount for '{line.Description}'.");

            var taxable = gross - line.Discount;
            var split = TaxCalculator.Split(taxable, line.TaxRatePercent, shopState, counterpartyState);

            subtotal += gross;
            taxTotal += split.Total;

            results.Add(new LineResult(line.ItemId, line.Description, line.Quantity, line.Rate, line.Discount, line.TaxRatePercent, split.Cgst, split.Sgst, split.Igst, taxable + split.Total));
        }

        var lineDiscountTotal = results.Sum(r => r.Discount);
        var postLineDiscount = subtotal - lineDiscountTotal;

        var overallDiscountAmount = overallDiscountType switch
        {
            DiscountType.Percent => Math.Round(postLineDiscount * overallDiscountValue / 100m, 2),
            DiscountType.Flat => overallDiscountValue,
            _ => 0m,
        };

        if (overallDiscountAmount > postLineDiscount)
            throw new ValidationAppException("Overall discount cannot exceed the post-line-discount subtotal.");

        var grandTotal = postLineDiscount + taxTotal - overallDiscountAmount;

        return new DocumentTotals(results, subtotal, taxTotal, overallDiscountAmount, grandTotal);
    }
}
