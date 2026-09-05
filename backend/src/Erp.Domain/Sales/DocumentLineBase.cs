using Erp.Domain.Items;

namespace Erp.Domain.Sales;

/// <summary>Shared shape for quotation/proforma/sales-invoice lines. Every total here is recalculated server-side; client-supplied totals are display-only.</summary>
public abstract class DocumentLineBase
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Null for a free-text non-stock line with no catalog item.</summary>
    public Guid? ItemId { get; set; }
    public Item? Item { get; set; }

    public string Description { get; set; } = default!;
    public decimal Quantity { get; set; }
    public decimal Rate { get; set; }
    public decimal Discount { get; set; }

    public decimal TaxRatePercent { get; set; }
    public decimal CgstAmount { get; set; }
    public decimal SgstAmount { get; set; }
    public decimal IgstAmount { get; set; }

    public decimal LineTotal { get; set; }

    /// <summary>
    /// Comma-separated serial numbers the user picked for a serial-tracked item, or null to let stock
    /// deduction auto-assign the oldest-received unit (FIFO) at conversion time — both optional, per
    /// business decision (2026-08-25): manual pick always wins over FIFO when supplied.
    /// </summary>
    public string? SerialNumbersCsv { get; set; }

    /// <summary>Manually-typed SAC/HSN code for a line with no catalog Item (e.g. a typed-in
    /// Service) — a catalog-linked line ignores this and uses Item.HsnCode instead, see
    /// DocumentPdfService.ToLine.</summary>
    public string? HsnCode { get; set; }
}
