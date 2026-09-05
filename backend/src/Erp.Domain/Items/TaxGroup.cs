using Erp.Domain.Common;

namespace Erp.Domain.Items;

/// <summary>A GST slab, e.g. "GST 18%". Split into CGST+SGST or IGST at document-line time based on shop vs. customer state.</summary>
public class TaxGroup : BaseEntity
{
    public string Name { get; set; } = default!;
    public decimal RatePercent { get; set; }
    public bool IsActive { get; set; } = true;
}
