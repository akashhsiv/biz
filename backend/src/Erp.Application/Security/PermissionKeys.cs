namespace Erp.Application.Security;

/// <summary>Canonical permission key constants, shared by controllers ([RequirePermission]) and the DB seed catalog, so the two can never drift apart.</summary>
public static class PermissionKeys
{
    public const string CustomersView = "customers.view";
    public const string CustomersManage = "customers.manage";

    public const string ItemsView = "items.view";
    public const string ItemsManage = "items.manage";

    public const string QuotationsManage = "quotations.manage";
    public const string ProformasManage = "proformas.manage";
    public const string SalesInvoicesManage = "sales_invoices.manage";
    public const string SalesInvoicesCancel = "sales_invoices.cancel";
    public const string SalesReturnsRequest = "sales_returns.request";
    public const string SalesReturnsApprove = "sales_returns.approve";
    public const string ReturnPoliciesManage = "return_policies.manage";

    public const string CustomerDepositsRecord = "customer_deposits.record";
    public const string FinanceAmountOutManage = "finance.amount_out.manage";
    public const string FinanceShopBalanceView = "finance.shop_balance.view";
    public const string FinanceAdjustmentsManage = "finance.adjustments.manage";
    public const string ExpensesManage = "expenses.manage";

    public const string PurchaseOrdersManage = "purchase_orders.manage";
    public const string PurchaseReceiptsManage = "purchase_receipts.manage";
    public const string PurchasePaymentsInitiate = "purchase_payments.initiate";
    public const string PurchasePaymentsApprove = "purchase_payments.approve";

    public const string StockView = "stock.view";
    public const string StockAdjust = "stock.adjust";

    public const string StaffView = "staff.view";
    public const string StaffManage = "staff.manage";
    public const string StaffSalaryView = "staff.salary.view";
    public const string StaffSalaryPay = "staff.salary.pay";

    public const string ReportsSalesView = "reports.sales.view";
    public const string ReportsPurchaseView = "reports.purchase.view";
    public const string ReportsFinanceView = "reports.finance.view";
    public const string ReportsCustomerView = "reports.customer.view";
    public const string ReportsAllView = "reports.all.view";

    public const string UsersManage = "users.manage";
    public const string RolesManage = "roles.manage";
    public const string AuditLogsView = "audit_logs.view";
    public const string WhatsappManage = "whatsapp.manage";
    public const string BackupManage = "backup.manage";
    public const string HostStatusView = "host.status.view";
    public const string CompanySettingsManage = "company_settings.manage";

    public const string CommissionView = "commission.view";
    public const string CommissionManage = "commission.manage";

    public const string NotificationSettingsView = "notifications.settings.view";
    public const string NotificationSettingsManage = "notifications.settings.manage";

    public static readonly (string Key, string Module, string Description)[] Catalog =
    [
        (CustomersView, "customers", "View customer master"),
        (CustomersManage, "customers", "Create/edit customers, including GST details"),

        (ItemsView, "items", "View item master"),
        (ItemsManage, "items", "Create/edit/deactivate items"),

        (QuotationsManage, "sales", "Create/edit/convert quotations"),
        (ProformasManage, "sales", "View/convert/cancel proforma invoices"),
        (SalesInvoicesManage, "sales", "View sales invoices"),
        (SalesInvoicesCancel, "sales", "Cancel a sales invoice (Admin-only)"),
        (SalesReturnsRequest, "sales", "Request a sales return"),
        (SalesReturnsApprove, "sales", "Approve/complete a sales return"),
        (ReturnPoliciesManage, "sales", "Manage return policies"),

        (CustomerDepositsRecord, "finance", "Record a customer deposit (Amount In)"),
        (FinanceAmountOutManage, "finance", "Record Amount Out entries"),
        (FinanceShopBalanceView, "finance", "View shop balance and ledger"),
        (FinanceAdjustmentsManage, "finance", "Create financial adjustments/reversals"),
        (ExpensesManage, "finance", "Record and view business expenses"),

        (PurchaseOrdersManage, "purchases", "Create/edit purchase orders"),
        (PurchaseReceiptsManage, "purchases", "Record purchase receipts"),
        (PurchasePaymentsInitiate, "purchases", "Initiate a purchase payment"),
        (PurchasePaymentsApprove, "purchases", "Approve/complete a purchase payment"),

        (StockView, "stock", "View stock levels and movements"),
        (StockAdjust, "stock", "Create manual stock adjustments"),

        (StaffView, "staff", "View staff master"),
        (StaffManage, "staff", "Create/edit/deactivate staff"),
        (StaffSalaryView, "staff", "View salary records and payment history"),
        (StaffSalaryPay, "staff", "Generate salary records and record salary payments"),

        (ReportsSalesView, "reports", "View sales reports (own/team)"),
        (ReportsPurchaseView, "reports", "View purchase reports (own/team)"),
        (ReportsFinanceView, "reports", "View finance reports"),
        (ReportsCustomerView, "reports", "View customer reports (sales, outstanding, payments, activity)"),
        (ReportsAllView, "reports", "View all reports across the shop"),

        (UsersManage, "admin", "Create/edit users"),
        (RolesManage, "admin", "Manage roles and permission grants"),
        (AuditLogsView, "admin", "View audit logs"),
        (WhatsappManage, "admin", "Manage WhatsApp sending"),
        (BackupManage, "admin", "Trigger and view database backups"),
        (HostStatusView, "admin", "View Host connection/infrastructure status"),
        (CompanySettingsManage, "admin", "Edit shop name/logo/GST/bank details"),

        (CommissionView, "commission", "View customer commission rates and commission entries"),
        (CommissionManage, "commission", "Create/edit customer commission rates; record/cancel commission payments"),

        (NotificationSettingsView, "notifications", "View notification channel settings (Low Stock/Purchase Due/Purchase Overdue/Customer Outstanding x WhatsApp/Mobile)"),
        (NotificationSettingsManage, "notifications", "Edit notification channel settings"),
    ];
}
