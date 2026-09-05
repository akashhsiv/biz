namespace Erp.Domain.Common;

public enum CustomerType
{
    Registered,
    Unregistered
}

public enum ItemKind
{
    Stock,
    NonStock
}

public enum StockMovementType
{
    Opening,
    Purchase,
    Sale,
    Return,
    Adjustment,
    Reversal
}

public enum DocumentReferenceType
{
    Quotation,
    ProformaInvoice,
    SalesInvoice,
    PurchaseReceipt,
    SalesReturn,
    ManualAdjustment,
    Expense,
    PurchaseOrder
}

public enum FinancialTransactionType
{
    AmountIn,
    AmountOut,
    DepositAllocation,
    DepositReversal,
    PurchasePayment,
    Refund,
    Adjustment
}

public enum FinancialDirection
{
    Credit,
    Debit
}

public enum DiscountType
{
    Percent,
    Flat
}

public enum QuotationStatus
{
    Draft,
    Issued,
    Converted,
    Cancelled,
    Expired
}

public enum ProformaStatus
{
    Open,
    FullyFunded,
    Converted,
    Cancelled
}

public enum SalesInvoiceStatus
{
    Active,
    Cancelled
}

public enum SalesInvoiceSourceType
{
    QuotationDirect,
    ProformaConversion
}

public enum SalesReturnStatus
{
    Requested,
    Approved,
    Rejected,
    Completed,
    Cancelled
}

public enum RefundMethod
{
    CashAmountOut,
    CreditToDeposit
}

public enum PurchaseOrderStatus
{
    Draft,
    Submitted,
    Processing,
    PartiallyCompleted,
    Completed,
    Cancelled
}

public enum PurchasePaymentStatus
{
    Processing,
    Completed,
    Cancelled
}

public enum DepositAllocationStatus
{
    Active,
    Reversed
}

public enum DepositAllocationDocumentType
{
    Proforma,
    SalesInvoice
}

public enum WhatsappMessageType
{
    Quotation,
    Proforma,
    SalesInvoice,
    DepositReceipt,
    Custom
}

public enum WhatsappOutboxStatus
{
    Queued,
    Sending,
    Sent,
    Failed
}

public enum BackupType
{
    Automatic,
    Manual
}

public enum BackupStatus
{
    Success,
    Failed
}

public enum StaffEmploymentStatus
{
    Active,
    Inactive,
    Terminated
}

public enum StaffSalaryType
{
    Monthly,
    Daily,
    Hourly
}

public enum SalaryPaymentStatus
{
    Pending,
    PartiallyPaid,
    Paid
}

/// <summary>Lifecycle status for a Commission/CommissionEntry (see Erp.Domain.Commission). The exact
/// business meaning of "commission" is unresolved pending sign-off; this status only tracks the
/// entry's payment/lifecycle state, independent of that decision.</summary>
public enum CommissionEntryStatus
{
    Pending,
    PartiallyPaid,
    Paid,
    Cancelled,
    Adjusted
}

/// <summary>Generic notification engine (see Erp.Domain.Notifications, ARCHITECTURE §19/§23/§24 in
/// Biz_Product_Requirements.md). Business logic only creates events of these types — it never knows
/// about WhatsApp/Baileys or push delivery. PurchaseDue and CustomerOutstanding are recognized event
/// types (and have settings flags) but nothing currently raises them — only LowStock and
/// PurchaseOverdue are wired to a trigger today; the enum stays extensible for the others.</summary>
public enum NotificationEventType
{
    LowStock,
    PurchaseDue,
    PurchaseOverdue,
    CustomerOutstanding,
    SalesPaymentDue,
    SalesPaymentOverdue
}

/// <summary>Unified Full/Partial/Credit payment-status concept shared by SalesInvoice.PaymentStatus and
/// PurchaseOrder.BalancePaymentStatus — see DocumentPaymentStatusCalculator, the single place that
/// derives one of these from (grandTotal, outstandingTotal, dueDate). Deliberately independent from
/// PurchasePaymentStatus, which tracks a different workflow (payment-record lifecycle, not balance-owed).</summary>
public enum DocumentPaymentStatus
{
    Paid,
    PartiallyPaid,
    Credit,
    Overdue
}

public enum NotificationEventStatus
{
    Pending,
    Dispatched,
    Failed
}

/// <summary>Delivery status for the mobile-push placeholder outbox — see MobilePushOutboxItem.
/// No provider (Firebase/APNs) is wired up yet, so every row created today stays Pending forever;
/// this exists so the data model doesn't need reshaping once a provider is chosen.</summary>
public enum MobilePushOutboxStatus
{
    Pending,
    Sent,
    Failed
}
