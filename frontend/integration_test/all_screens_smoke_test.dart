// Navigates to every nav-rail screen and confirms each renders without throwing — catches JSON
// parsing mismatches, null-safety bugs, and provider wiring errors across the whole app quickly.
// This complements golden_path_test.dart, which scripts one full business workflow in depth.
//
// Run with: flutter test integration_test/all_screens_smoke_test.dart -d windows
// Prerequisite: the .NET backend must already be running on http://localhost:5000, seeded with
// the default admin/ChangeMe123! login.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:erp_client/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('every nav screen renders without throwing', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 900));
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const ProviderScope(child: BizApp()));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    if (find.text('Host Connection Required').evaluate().isNotEmpty) {
      await tester.enterText(find.byType(TextField).first, 'localhost:5000');
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    if (find.text('Log In').evaluate().isNotEmpty) {
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), 'admin');
      await tester.enterText(textFields.at(1), 'ChangeMe123!');
      await tester.tap(find.text('Log In'));
      await tester.pumpAndSettle(const Duration(seconds: 3));
    }

    expect(find.textContaining('Welcome,'), findsOneWidget);

    // Let the Host Status card's async fetch resolve and re-render before moving on, and
    // attribute any resulting overflow to the Dashboard rather than whatever screen comes next.
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final dashboardException = tester.takeException();
    if (dashboardException != null) {
      debugPrint('=== FULL DASHBOARD EXCEPTION DUMP ===');
      debugPrint(dashboardException.toString());
      debugPrint('=== END DUMP ===');
      fail('Dashboard threw after Host Status data loaded — see full dump above.');
    }
    debugPrint('✓ Dashboard loaded (as Shop Admin, all nav items should be visible).');

    const expectedLabels = [
      'Customers',
      'Items',
      'Quotations',
      'Proformas',
      'Sales Invoices',
      'Deposits',
      'Purchases',
      'Stock',
      'Returns',
      'Finance',
      'Users',
      'Reports',
      'WhatsApp',
      'Shop Settings',
    ];

    final sidebarScrollable = find.byType(Scrollable).first;

    for (final label in expectedLabels) {
      // The sidebar is a lazy ListView now (fixed for a real overflow bug found here — too many
      // nav items for a NavigationRail with no scrolling), so an item further down may not be
      // built yet. Scroll it into view before asserting on it.
      await tester.dragUntilVisible(find.text(label), sidebarScrollable, const Offset(0, -80));
      await tester.pumpAndSettle();

      final navFinder = find.text(label);
      if (navFinder.evaluate().isEmpty) {
        fail('Expected nav item "$label" not found for Shop Admin — permission wiring likely wrong.');
      }

      await tester.tap(navFinder.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      final exception = tester.takeException();
      if (exception != null) {
        fail('Screen "$label" threw during render: $exception');
      }

      debugPrint('✓ "$label" screen rendered with no exceptions.');
    }

    debugPrint('✓ All ${expectedLabels.length} nav screens rendered cleanly.');
  });
}
