import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:attendance_admin/providers/auth_provider.dart';
import 'package:attendance_admin/screens/login_screen.dart';
import 'package:attendance_admin/utils/formats.dart';

void main() {
  testWidgets('login screen renders email/password fields and validates',
      (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);

    // Submitting the empty form shows validation errors, no network call.
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  test('formatMinutes renders durations as h:mm', () {
    expect(formatMinutes(0), '0:00');
    expect(formatMinutes(5), '0:05');
    expect(formatMinutes(60), '1:00');
    expect(formatMinutes(508), '8:28');
    expect(formatMinutes(null), '—');
  });

  test('parseHHmm and timeOfDayToHHmm round-trip', () {
    const time = TimeOfDay(hour: 9, minute: 5);
    expect(timeOfDayToHHmm(time), '09:05');
    expect(parseHHmm('09:05'), time);
    expect(parseHHmm('24:00'), isNull);
    expect(parseHHmm('bogus'), isNull);
  });
}
