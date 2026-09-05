using Erp.Domain.Common;

namespace Erp.Domain.Shops;

/// <summary>Top-level tenant record. Expect exactly one row for the foreseeable future — multi-company
/// (as opposed to multi-shop) is out of scope for this rework — but Shop hangs off it so the model has
/// somewhere to grow if that ever changes.</summary>
public class Company : BaseEntity
{
    public string Name { get; set; } = default!;

    public ICollection<Shop> Shops { get; set; } = new List<Shop>();
}
