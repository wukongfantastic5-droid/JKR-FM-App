import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jkr_fm_guide/main.dart';

void main() {
  testWidgets('App launches without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const JkrFmGuideApp());
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Login screen shows Login button', (WidgetTester tester) async {
    await tester.pumpWidget(const JkrFmGuideApp());
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Login'), findsOneWidget);
  });
}
