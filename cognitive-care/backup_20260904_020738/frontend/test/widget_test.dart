import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:frontend/main.dart';

void main() {
  testWidgets('starts at the login screen without a saved session', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CognitiveCareApp());
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
  });
}
