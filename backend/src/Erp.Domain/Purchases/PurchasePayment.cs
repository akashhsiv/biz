using Erp.Domain.Common;

namespace Erp.Domain.Purchases;

public class PurchasePayment : BaseEntity
{
    public Guid PurchaseOrderId { get; set; }
    public PurchaseOrder PurchaseOrder { get; set; } = default!;

    /// <summary>Set only once the payment is marked Completed and an Amount Out FinancialTransaction has been written.</summary>
    public Guid? FinancialTransactionId { get; set; }

    public decimal Amount { get; set; }
    public PurchasePaymentStatus Status { get; set; } = PurchasePaymentStatus.Processing;
    public string? PaymentMethod { get; set; }
}
