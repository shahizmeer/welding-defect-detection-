import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firstly/main.dart'; // use relative path for local testing

void main() {
  testWidgets('Smoke test: MyApp builds and shows UI',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // Check for expected widgets
    expect(find.text('Teacher Dashboard'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });
}
