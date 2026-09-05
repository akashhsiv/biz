using Erp.Domain.Common;
using Erp.Domain.Customers;

namespace Erp.Domain.Finance;

/// <summary>One row per Amount In deposit event made by a customer.</summary>
public class CustomerDeposit : BaseEntity, IShopScoped
{
    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public Guid CustomerId { get; set; }
    public Customer Customer { get; set; } = default!;

    public Guid FinancialTransactionId { get; set; }
    public FinancialTransaction FinancialTransaction { get; set; } = default!;

    public decimal Amount { get; set; }
    public string? PaymentMethod { get; set; }
    public Guid ReceivedBy { get; set; }
    public string? Notes { get; set; }
}
