import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

import 'package:board_game_dashboard/features/tools/presentation/widgets/calculator_widgets.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

Widget _wrap(TextEditingController controller, {bool signed = false}) =>
    MaterialApp(
      theme: buildDarkTheme(),
      localizationsDelegates: AppStrings.localizationsDelegates,
      supportedLocales: AppStrings.supportedLocales,
      home: Scaffold(
        body: ScoreInputRow(
          label: 'Score',
          controller: controller,
          signed: signed,
        ),
      ),
    );

void main() {
  // D17: the numeric keyboard was the only thing keeping non-digits out, so a
  // hardware keyboard or a paste put letters in the field, which int.tryParse
  // then silently scored as 0.
  group('ScoreInputRow rejects non-numeric input', () {
    testWidgets('letters never reach an unsigned field', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(controller));

      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();

      expect(controller.text, '');
    });

    testWidgets('digits are kept and letters dropped from a mixed paste', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(controller));

      await tester.enterText(find.byType(TextField), '12a3');
      await tester.pump();

      expect(controller.text, '123');
    });

    testWidgets('a signed field keeps a leading minus', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(controller, signed: true));

      await tester.enterText(find.byType(TextField), '-5');
      await tester.pump();

      expect(controller.text, '-5');
    });

    testWidgets('a signed field still rejects letters', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(controller, signed: true));

      await tester.enterText(find.byType(TextField), '-5x');
      await tester.pump();

      expect(controller.text, '');
    });

    testWidgets('an unsigned field rejects a minus', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_wrap(controller));

      await tester.enterText(find.byType(TextField), '-5');
      await tester.pump();

      expect(controller.text, '5');
    });
  });
}
