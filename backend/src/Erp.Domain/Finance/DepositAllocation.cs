using Erp.Domain.Common;
using Erp.Domain.Customers;

namespace Erp.Domain.Finance;

/// <summary>Traceable link between a customer's deposit pool and the document it was applied to. Available deposit = SUM(CustomerDeposit.Amount) - SUM(active DepositAllocation.AmountAllocated) +/- adjustment FinancialTransactions.</summary>
public class DepositAllocation : BaseEntity, IShopScoped
{
    public Guid ShopId { get; set; }
    public Erp.Domain.Shops.Shop Shop { get; set; } = default!;

    public Guid CustomerId { get; set; }
    public Customer Customer { get; set; } = default!;

    public DepositAllocationDocumentType DocumentType { get; set; }
    public Guid DocumentId { get; set; }

    public decimal AmountAllocated { get; set; }
    public DepositAllocationStatus Status { get; set; } = DepositAllocationStatus.Active;

    public DateTime? ReversedAt { get; set; }
    public string? ReversedReason { get; set; }
}
