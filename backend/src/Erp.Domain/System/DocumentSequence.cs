namespace Erp.Domain.System;

/// <summary>Tracks the next document number per document type per financial year. Incremented inside the same transaction as document creation to avoid gaps/races across concurrent Slaves.</summary>
public class DocumentSequence
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>e.g. "quotation", "proforma", "sales_invoice", "purchase_order", "purchase_receipt", "sales_return".</summary>
    public string DocType { get; set; } = default!;

    /// <summary>Indian financial year label, e.g. "2026-27".</summary>
    public string FinancialYear { get; set; } = default!;

    public long LastNumber { get; set; }
}
