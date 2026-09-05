using Erp.Domain.Common;
using Erp.Domain.Customers;
using Erp.Domain.Items;
using Erp.Domain.Sales;

namespace Erp.Domain.Commission;

/// <summary>
/// One calculated commission record for a single SalesInvoice line, created at invoice-creation
/// time by CommissionCalculationService. Amount is a SNAPSHOT of the calculated value at that
/// moment — matching the same convention DocumentLineBase/SalesInvoiceLine use for prices/taxes —
/// and is never recomputed later even if the underlying CustomerProductRate.CommissionRate changes.
/// The exact business meaning of "commission" is still unresolved (see CustomerProductRate doc
/// comment); this table only tracks amounts + payment/lifecycle status so reporting/CRUD can be
/// built now without a future schema change.
/// </summary>
public class CommissionEntry : BaseEntity, IShopScoped
{
    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public Guid CustomerId { get; set; }
    public Customer Customer { get; set; } = default!;

    public Guid SalesInvoiceId { get; set; }
    public SalesInvoice SalesInvoice { get; set; } = default!;

    public Guid ItemId { get; set; }
    public Item Item { get; set; } = default!;

    /// <summary>Snapshot — calculated once at invoice creation time, never recomputed from a live
    /// CommissionRate later. See CommissionCalculationService for the (provisional) formula.</summary>
    public decimal Amount { get; set; }

    public CommissionEntryStatus Status { get; set; } = CommissionEntryStatus.Pending;

    public decimal PaidAmount { get; set; }
}
