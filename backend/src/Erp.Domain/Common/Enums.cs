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
    Expense
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
