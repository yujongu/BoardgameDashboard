import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/auth/login_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

import '../../helpers/analytics.dart';

Widget _wrap() => ProviderScope(
  overrides: [analyticsOverride],
  child: MaterialApp(
    theme: buildDarkTheme(),
    localizationsDelegates: AppStrings.localizationsDelegates,
    supportedLocales: AppStrings.supportedLocales,
    home: const LoginScreen(),
  ),
);

void main() {
  testWidgets(
    'Forgot password shows in sign-in mode, hidden in register mode',
    (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.text('Forgot password?'), findsOneWidget);

      // Toggle to register mode — the reset link should disappear.
      await tester.tap(find.text('Register'));
      await tester.pumpAndSettle();
      expect(find.text('Forgot password?'), findsNothing);
    },
  );

  testWidgets('tapping Forgot password with no email prompts for one', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap());

    // Empty email → the handler returns before any Firebase call.
    await tester.tap(find.text('Forgot password?'));
    await tester.pump();

    expect(
      find.text('Enter your email above to reset your password.'),
      findsOneWidget,
    );
  });
}
