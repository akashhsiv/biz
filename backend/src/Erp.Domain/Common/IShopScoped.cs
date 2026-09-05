namespace Erp.Domain.Common;

/// <summary>Marks an entity as belonging to exactly one Shop. ErpDbContext discovers every
/// implementer via reflection in OnModelCreating and applies a global HasQueryFilter scoping reads
/// to ICurrentUserService.CurrentShopId — see the multi-shop rework notes on ErpDbContext.</summary>
public interface IShopScoped
{
    Guid ShopId { get; set; }
}
