import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:erp_client/app.dart';

void main() {
  testWidgets('shows the connection screen when no Host is configured', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: ErpApp()));
    await tester.pumpAndSettle();

    expect(find.text('Host Connection Required'), findsOneWidget);
  });
}
