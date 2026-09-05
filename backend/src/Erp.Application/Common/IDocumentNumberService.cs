namespace Erp.Application.Common;

/// <summary>Allocates the next sequential number for a document type, scoped per Indian financial year (Apr-Mar) — see ARCHITECTURE.md §13/§13a. The allocation is a single atomic UPSERT; wrap the call together with the entity insert in one transaction when a failed insert must not leave a gap.</summary>
public interface IDocumentNumberService
{
    /// <returns>A formatted document number, e.g. "INV-2026-27-0001".</returns>
    Task<string> NextNumberAsync(string docType, string prefix, CancellationToken ct = default);

    /// <summary>For codes that don't reset per financial year (e.g. customer codes). Returns e.g. "CUST-0001".</summary>
    Task<string> NextGlobalNumberAsync(string docType, string prefix, CancellationToken ct = default);

    /// <summary>Current Indian financial year label for "now", e.g. "2026-27".</summary>
    string CurrentFinancialYear();
}
