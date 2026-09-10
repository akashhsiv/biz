import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_controller.dart';
import 'core/constants/permissions.dart';
import 'core/shortcuts/form_nav_shortcuts.dart';
import 'core/shortcuts/global_shortcuts_listener.dart';
import 'core/theme/app_theme.dart';
import 'features/admin/super_admin_dashboard_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/categories/categories_provider.dart';
import 'features/categories/category_workspace_screen.dart';
import 'features/commission/commission_screen.dart';
import 'features/customers/customers_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/error_log/error_log_screen.dart';
import 'features/expenses/expenses_screen.dart';
import 'features/finance/deposits_screen.dart';
import 'features/finance/finance_screen.dart';
import 'features/items/items_screen.dart';
import 'features/purchases/purchases_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/returns/sales_returns_screen.dart';
import 'features/settings/company_settings_screen.dart';
import 'features/settings/notification_settings_screen.dart';
import 'features/settings/return_policies_screen.dart';
import 'features/settings/shop_configuration_screen.dart';
import 'features/settings/tax_groups_screen.dart';
import 'features/shops/shop_gate.dart';
import 'features/staff/staff_screen.dart';
import 'features/shops/shops_provider.dart';
import 'features/stock/stock_screen.dart';
import 'features/users/users_screen.dart';
import 'features/whatsapp/whatsapp_screen.dart';
import 'core/platform/desktop_window.dart';
import 'shared/widgets/app_shell.dart';
import 'shared/widgets/custom_title_bar.dart';
import 'shared/widgets/overlay_host.dart';
import 'shared/widgets/app_toast.dart';
import 'shared/widgets/nav_item.dart';

class BizApp extends ConsumerWidget {
  const BizApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);

    // Session validation against the (now fixed) backend happens once at startup instead - see
    // _Bootstrap in main.dart, which calls AuthController.validateSession() right after
    // restoreFromCache() rather than waiting on a connection-status transition that no longer exists.

    Widget home;
    if (!auth.isAuthenticated) {
      home = const LoginScreen();
    } else if (auth.isSuperAdmin) {
      // A super admin has no shop-scoped UserShopRole in general, so the normal shop-selection
      // flow (ShopGate/AppShell) doesn't apply — send them straight to their own dashboard.
      home = const SuperAdminDashboardScreen();
    } else if (ref.watch(selectedShopControllerProvider) == null) {
      // Multi-shop rework: no shop persisted/valid yet for this session - resolve one (auto-select
      // if there's only one, otherwise show the picker) before AppShell. A shop restored from a
      // previous session skips straight past this branch (still fine to lazily re-validate later).
      home = const ShopGate();
    } else {
      // One sidebar entry per active Item Category (always includes the auto-seeded "Cash Bill"
      // category plus whatever the Shop Admin has created) — replaces the old flat "Purchases"/
      // "Sales Invoices" entries. While categories are still loading/unavailable, this simply
      // contributes no extra nav items yet rather than a placeholder — mirrors how the rest of
      // this list is built eagerly with no other provider-dependent item today.
      final categoriesAsync = ref.watch(categoriesProvider);
      // No single required permission — like Reports below, each tab (Purchase List, Sales List)
      // enforces its own permission on the backend, and a role with only one of
      // purchase_orders.manage/sales_invoices.manage should still see this category entry.
      final categoryNavItems = (categoriesAsync.valueOrNull ?? const [])
          .map((category) => NavItem(
                label: category.name,
                icon: Icons.category_outlined,
                builder: (_) => CategoryWorkspaceScreen(category: category),
              ))
          .toList();

      home = AppShell(items: [
        NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, builder: (_) => const DashboardScreen()),
        NavItem(
          label: 'Customers',
          icon: Icons.people_outline,
          requiredPermission: Permissions.customersView,
          builder: (_) => const CustomersScreen(),
        ),
        ...categoryNavItems,
        NavItem(
          label: 'Returns',
          icon: Icons.assignment_return_outlined,
          requiredPermission: Permissions.salesReturnsRequest,
          builder: (_) => const SalesReturnsScreen(),
        ),
        NavItem(
          label: 'Return Policies',
          icon: Icons.rule_folder_outlined,
          requiredPermission: Permissions.returnPoliciesManage,
          builder: (_) => const ReturnPoliciesScreen(),
        ),
        NavItem(
          label: 'Suppliers',
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
          label: 'Tax Groups',
          icon: Icons.percent_outlined,
          requiredPermission: Permissions.itemsView,
          builder: (_) => const TaxGroupsScreen(),
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
          label: 'Notification Settings',
          icon: Icons.notifications_outlined,
          requiredPermission: Permissions.notificationsSettingsView,
          builder: (_) => const NotificationSettingsScreen(),
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
    // both would show two title-bar-ish strips stacked on top of each other. Login/ShopGate have
    // no such bar of their own, so they still get the standalone CustomTitleBar.
    final showCustomTitleBar = home is! AppShell && isDesktopWindowed;

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Biz',
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
