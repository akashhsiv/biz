using Erp.Domain.Common;

namespace Erp.Application.Common;

/// <summary>Single source of truth for deriving the unified Full/Partial/Credit/Overdue payment-status
/// (DocumentPaymentStatus) shared by SalesInvoice.PaymentStatus and PurchaseOrder.BalancePaymentStatus.
/// Never duplicate this if/else elsewhere — both documents must call this method.</summary>
public static class DocumentPaymentStatusCalculator
{
    public static DocumentPaymentStatus Calculate(decimal grandTotal, decimal outstandingTotal, DateTime? dueDate, DateTime today)
    {
        if (outstandingTotal <= 0) return DocumentPaymentStatus.Paid;

        if (dueDate.HasValue && dueDate.Value.Date < today.Date) return DocumentPaymentStatus.Overdue;

        if (outstandingTotal < grandTotal) return DocumentPaymentStatus.PartiallyPaid;

        return DocumentPaymentStatus.Credit;
    }
}
