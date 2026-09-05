using Erp.Domain.Common;

namespace Erp.Domain.Items;

public class ItemCategory : BaseEntity
{
    public string Name { get; set; } = default!;
    public bool IsActive { get; set; } = true;
}
