using Erp.Domain.Common;

namespace Erp.Domain.System;

/// <summary>Tracks the next document number per shop per document type per financial year. Incremented
/// inside the same transaction as document creation to avoid gaps/races across concurrent Slaves.
/// Scoped per-shop (not just per doc type/year) so two shops numbering invoices concurrently never
/// collide or share a counter.</summary>
public class DocumentSequence : IShopScoped
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    /// <summary>e.g. "quotation", "proforma", "sales_invoice", "purchase_order", "purchase_receipt", "sales_return".</summary>
    public string DocType { get; set; } = default!;

    /// <summary>Indian financial year label, e.g. "2026-27".</summary>
    public string FinancialYear { get; set; } = default!;

    public long LastNumber { get; set; }
}
