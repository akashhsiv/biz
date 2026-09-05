namespace Erp.Application.Common;

public readonly record struct TaxSplit(decimal Cgst, decimal Sgst, decimal Igst)
{
    public decimal Total => Cgst + Sgst + Igst;
}

/// <summary>Intra-state (same state as the shop) splits into CGST+SGST; inter-state is IGST — see ARCHITECTURE.md §13 decision #2.</summary>
public static class TaxCalculator
{
    public static TaxSplit Split(decimal taxableAmount, decimal ratePercent, string shopState, string? customerState)
    {
        var taxAmount = Math.Round(taxableAmount * ratePercent / 100m, 2);

        var sameState = !string.IsNullOrWhiteSpace(customerState) &&
                         string.Equals(customerState, shopState, StringComparison.OrdinalIgnoreCase);

        return sameState
            ? new TaxSplit(Math.Round(taxAmount / 2m, 2), taxAmount - Math.Round(taxAmount / 2m, 2), 0m)
            : new TaxSplit(0m, 0m, taxAmount);
    }
}
