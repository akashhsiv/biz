/// Mirrors Erp.Application.Security.PermissionKeys on the backend — kept in sync by hand since
/// there's no shared package between the two projects. The backend is still the authority: this
/// only controls what the UI *offers*, never what the server *allows*.
class Permissions {
  static const customersView = 'customers.view';
  static const customersManage = 'customers.manage';

  static const itemsView = 'items.view';
  static const itemsManage = 'items.manage';

  static const quotationsManage = 'quotations.manage';
  static const proformasManage = 'proformas.manage';
  static const salesInvoicesManage = 'sales_invoices.manage';
  static const salesInvoicesCancel = 'sales_invoices.cancel';
  static const salesReturnsRequest = 'sales_returns.request';
  static const salesReturnsApprove = 'sales_returns.approve';
  static const returnPoliciesManage = 'return_policies.manage';

  static const customerDepositsRecord = 'customer_deposits.record';
  static const financeAmountOutManage = 'finance.amount_out.manage';
  static const financeShopBalanceView = 'finance.shop_balance.view';
  static const financeAdjustmentsManage = 'finance.adjustments.manage';
  static const expensesManage = 'expenses.manage';

  static const purchaseOrdersManage = 'purchase_orders.manage';
  static const purchaseReceiptsManage = 'purchase_receipts.manage';
  static const purchasePaymentsInitiate = 'purchase_payments.initiate';
  static const purchasePaymentsApprove = 'purchase_payments.approve';

  static const stockView = 'stock.view';
  static const stockAdjust = 'stock.adjust';

  static const reportsSalesView = 'reports.sales.view';
  static const reportsPurchaseView = 'reports.purchase.view';
  static const reportsFinanceView = 'reports.finance.view';
  static const reportsAllView = 'reports.all.view';

  static const usersManage = 'users.manage';
  static const rolesManage = 'roles.manage';
  static const auditLogsView = 'audit_logs.view';
  static const whatsappManage = 'whatsapp.manage';
  static const backupManage = 'backup.manage';
  static const hostStatusView = 'host.status.view';
  static const companySettingsManage = 'company_settings.manage';
}
