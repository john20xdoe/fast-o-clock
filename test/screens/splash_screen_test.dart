import 'package:fast_oclock/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SplashScreen animates hands to zero and invokes onFinished',
      (WidgetTester tester) async {
    var finished = false;

    await tester.pumpWidget(
      MaterialApp(
        home: SplashScreen(
          duration: const Duration(milliseconds: 500),
          onFinished: () => finished = true,
        ),
      ),
    );

    expect(find.text("Fast O'Clock"), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(finished, isFalse);

    await tester.pumpAndSettle();

    expect(finished, isTrue);
  });
}
