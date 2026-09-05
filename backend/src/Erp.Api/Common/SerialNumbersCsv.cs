namespace Erp.Api.Common;

/// <summary>Shared comma-separated-string &lt;-&gt; List&lt;string&gt; conversion for DocumentLineBase.SerialNumbersCsv,
/// used by every document controller that reads or writes a line's picked serial numbers.</summary>
public static class SerialNumbersCsv
{
    public static List<string>? Parse(string? csv) =>
        string.IsNullOrWhiteSpace(csv) ? null : csv.Split(',').ToList();

    public static string? Join(List<string>? numbers) =>
        numbers is { Count: > 0 } ? string.Join(",", numbers) : null;
}
