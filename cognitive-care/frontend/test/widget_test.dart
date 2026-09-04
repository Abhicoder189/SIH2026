import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Cognitive Care smoke test', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Cognitive Care'))));
    expect(find.text('Cognitive Care'), findsOneWidget);
  });
}
