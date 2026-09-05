import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_controller.dart';
import 'core/constants/app_variant.dart';
import 'core/constants/permissions.dart';
import 'core/shortcuts/form_nav_shortcuts.dart';
import 'core/shortcuts/global_shortcuts_listener.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/connection/connection_controller.dart';
import 'features/connection/connection_state.dart';
import 'features/connection/connection_screen.dart';
import 'features/commission/commission_screen.dart';
import 'features/customers/customers_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/error_log/error_log_screen.dart';
import 'features/expenses/expenses_screen.dart';
import 'features/finance/deposits_screen.dart';
import 'features/finance/finance_screen.dart';
import 'features/items/items_screen.dart';
import 'features/proforma/proformas_screen.dart';
import 'features/purchases/purchases_screen.dart';
import 'features/quotations/quotations_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/returns/sales_returns_screen.dart';
import 'features/settings/company_settings_screen.dart';
import 'features/settings/shop_configuration_screen.dart';
import 'features/shops/shop_gate.dart';
import 'features/staff/staff_screen.dart';
import 'features/shops/shops_provider.dart';
import 'features/sales/sales_invoices_screen.dart';
import 'features/stock/stock_screen.dart';
import 'features/users/users_screen.dart';
import 'features/whatsapp/whatsapp_screen.dart';
import 'shared/widgets/app_shell.dart';
import 'shared/widgets/custom_title_bar.dart';
import 'shared/widgets/overlay_host.dart';
import 'shared/widgets/app_toast.dart';
import 'shared/widgets/nav_item.dart';

class ErpApp extends ConsumerWidget {
  const ErpApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionControllerProvider);
    final auth = ref.watch(authControllerProvider);

    // A cached token/profile has no per-Host scoping - re-validate it against whichever Host we
    // just confirmed a connection to, so a stale/wrong-Host session doesn't optimistically show
    // Home (see AuthController.validateSession).
    ref.listen(connectionControllerProvider, (previous, next) {
      if (next.status == ConnectionStatus.connected && previous?.status != ConnectionStatus.connected) {
        ref.read(authControllerProvider.notifier).validateSession();
      }
    });

    Widget home;
    // The connection screen is only for the very first connect - once a session has connected at
    // least once, any later blip (a 20s health-check poll, or a real drop) is shown as a banner
    // inside the app (ConnectivityBanner) instead of tearing the whole app down and back up, which
    // was resetting AppShell's selected tab to Dashboard on every single poll.
    if (!connection.hasEverConnected && connection.status != ConnectionStatus.connected) {
      home = const ConnectionScreen();
    } else if (!auth.isAuthenticated) {
      home = const LoginScreen();
    } else if (ref.watch(selectedShopControllerProvider) == null) {
      // Multi-shop rework: no shop persisted/valid yet for this session - resolve one (auto-select
      // if there's only one, otherwise show the picker) before AppShell. A shop restored from a
      // previous session skips straight past this branch (still fine to lazily re-validate later).
      home = const ShopGate();
    } else {
      home = AppShell(items: [
        NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, builder: (_) => const DashboardScreen()),
        NavItem(
          label: 'Customers',
          icon: Icons.people_outline,
          requiredPermission: Permissions.customersView,
          builder: (_) => const CustomersScreen(),
        ),
        NavItem(
          label: 'Quotations',
          icon: Icons.request_quote_outlined,
          requiredPermission: Permissions.quotationsManage,
          builder: (_) => const QuotationsScreen(),
        ),
        NavItem(
          label: 'Proformas',
          icon: Icons.description_outlined,
          requiredPermission: Permissions.proformasManage,
          builder: (_) => const ProformasScreen(),
        ),
        NavItem(
          label: 'Sales Invoices',
          icon: Icons.receipt_long_outlined,
          requiredPermission: Permissions.salesInvoicesManage,
          builder: (_) => const SalesInvoicesScreen(),
        ),
        NavItem(
          label: 'Returns',
          icon: Icons.assignment_return_outlined,
          requiredPermission: Permissions.salesReturnsRequest,
          builder: (_) => const SalesReturnsScreen(),
        ),
        NavItem(
          label: 'Purchases',
          icon: Icons.local_shipping_outlined,
          requiredPermission: Permissions.purchaseOrdersManage,
          builder: (_) => const PurchasesScreen(),
        ),
        NavItem(
          label: 'Items',
          icon: Icons.inventory_2_outlined,
          requiredPermission: Permissions.itemsView,
          builder: (_) => const ItemsScreen(),
        ),
        NavItem(
          label: 'Stock',
          icon: Icons.inventory_outlined,
          requiredPermission: Permissions.stockView,
          builder: (_) => const StockScreen(),
        ),
        NavItem(
          label: 'Deposits',
          icon: Icons.savings_outlined,
          requiredPermission: Permissions.customerDepositsRecord,
          builder: (_) => const DepositsScreen(),
        ),
        NavItem(
          label: 'Finance',
          icon: Icons.account_balance_outlined,
          requiredPermission: Permissions.financeShopBalanceView,
          builder: (_) => const FinanceScreen(),
        ),
        NavItem(
          label: 'Staff',
          icon: Icons.badge_outlined,
          requiredPermission: Permissions.staffView,
          builder: (_) => const StaffScreen(),
        ),
        NavItem(
          label: 'Commission',
          icon: Icons.percent_outlined,
          requiredPermission: Permissions.commissionView,
          builder: (_) => const CommissionScreen(),
        ),
        NavItem(
          label: 'Expenses',
          icon: Icons.receipt_long_outlined,
          requiredPermission: Permissions.expensesManage,
          builder: (_) => const ExpensesScreen(),
        ),
        NavItem(
          label: 'WhatsApp',
          icon: Icons.chat_outlined,
          requiredPermission: Permissions.whatsappManage,
          builder: (_) => const WhatsappScreen(),
        ),
        NavItem(
          label: 'Users',
          icon: Icons.admin_panel_settings_outlined,
          requiredPermission: Permissions.usersManage,
          builder: (_) => const UsersScreen(),
        ),
        // No single required permission — each report tab enforces its own on the backend and
        // shows a graceful "Failed" message for a tab a given role can't see.
        NavItem(
          label: 'Reports',
          icon: Icons.bar_chart_outlined,
          builder: (_) => const ReportsScreen(),
        ),
        NavItem(
          label: 'Shop Details',
          icon: Icons.storefront_outlined,
          requiredPermission: Permissions.companySettingsManage,
          builder: (_) => const CompanySettingsScreen(),
        ),
        NavItem(
          label: 'Shop Configuration',
          icon: Icons.settings_outlined,
          requiredPermission: Permissions.companySettingsManage,
          builder: (_) => const ShopConfigurationScreen(),
        ),
        NavItem(
          label: 'Error Log',
          icon: Icons.bug_report_outlined,
          requiredPermission: Permissions.auditLogsView,
          builder: (_) => const ErrorLogScreen(),
        ),
      ]);
    }

    // Once AppShell is showing, its own TopStatusBar folds in the window drag/minimize/maximize/
    // close controls and clock that CustomTitleBar otherwise provides (confirmed decision) - having
    // both would show two title-bar-ish strips stacked on top of each other. Connection/Login have
    // no such bar of their own, so they still get the standalone CustomTitleBar.
    final showCustomTitleBar = home is! AppShell;

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: AppVariant.appTitle,
      theme: appTheme,
      // Wraps the whole app including the Navigator's overlay, so this reaches dialogs too - most
      // forms in this app (create-customer, create-item, etc.) are shown via showDialog, which
      // mounts outside whatever screen opened it. CustomTitleBar's own Tooltips need an Overlay
      // ancestor - it sits outside the MaterialApp's Navigator (which owns the only Overlay
      // otherwise), so it gets its own here.
      // A blanket TextScaler bump was tried here and reverted (confirmed) - this app's tables,
      // sidebar, and status bar all use fixed pixel widths/heights that assume the base font
      // size, so scaling every piece of text up broke layout everywhere at once (wrapped table
      // headers, overlapping sidebar branding, etc.) rather than being a safe global change.
      builder: (context, child) => OverlayHost(
        child: Column(
          children: [
            if (showCustomTitleBar) const CustomTitleBar(),
            Expanded(child: GlobalShortcutsListener(child: FormNavShortcuts(child: child!))),
          ],
        ),
      ),
      home: home,
    );
  }
}
