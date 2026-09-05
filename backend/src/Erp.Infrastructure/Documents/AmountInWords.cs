namespace Erp.Infrastructure.Documents;

/// <summary>Converts a rupee amount to words, Indian numbering (Crore/Lakh/Thousand) — the
/// "Amount in Words" line shown on generated documents. Paise are dropped, matching how these
/// documents already round to whole-rupee display elsewhere.</summary>
public static class AmountInWords
{
    private static readonly string[] Ones =
        ["", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten",
         "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen", "Seventeen", "Eighteen", "Nineteen"];

    private static readonly string[] Tens =
        ["", "", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"];

    private static string TwoDigits(int n) =>
        n < 20 ? Ones[n] : Tens[n / 10] + (n % 10 != 0 ? " " + Ones[n % 10] : "");

    private static string ThreeDigits(int n)
    {
        var parts = new List<string>();
        if (n / 100 > 0) parts.Add(Ones[n / 100] + " Hundred");
        if (n % 100 > 0) parts.Add(TwoDigits(n % 100));
        return string.Join(" ", parts);
    }

    public static string Convert(decimal amount)
    {
        var rupees = (long)Math.Floor(Math.Abs(amount));
        if (rupees == 0) return "Zero Rupees only";

        var crore = rupees / 1_00_00_000; rupees %= 1_00_00_000;
        var lakh = rupees / 1_00_000; rupees %= 1_00_000;
        var thousand = rupees / 1_000; rupees %= 1_000;
        var hundred = rupees;

        var parts = new List<string>();
        if (crore > 0) parts.Add(ThreeDigits((int)crore) + " Crore");
        if (lakh > 0) parts.Add(ThreeDigits((int)lakh) + " Lakh");
        if (thousand > 0) parts.Add(ThreeDigits((int)thousand) + " Thousand");
        if (hundred > 0) parts.Add(ThreeDigits((int)hundred));

        return string.Join(" ", parts) + " Rupees only";
    }
}
