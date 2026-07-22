import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:board_game_dashboard/features/plays/add_play_notifier.dart';
import 'package:board_game_dashboard/features/plays/add_play_screen.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';

MaterialApp _app({Widget home = const AddPlayScreen()}) => MaterialApp(
  localizationsDelegates: AppStrings.localizationsDelegates,
  supportedLocales: AppStrings.supportedLocales,
  home: home,
);

void main() {
  testWidgets('AddPlayScreen renders the session location and notes fields', (
    tester,
  ) async {
    await tester.pumpWidget(ProviderScope(child: _app()));
    await tester.pump();

    expect(find.text('LOG A PLAY'), findsOneWidget);
    expect(find.text('Location (optional)'), findsOneWidget);
    expect(find.text('Notes (optional)'), findsOneWidget);
  });

  testWidgets('AddPlayScreen shows a score field per participant row', (
    tester,
  ) async {
    // Seed a single participant (the current user) so one player row renders.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          addPlayProvider.overrideWith(
            (ref) =>
                AddPlayNotifier(currentUserName: 'Me', currentUserId: 'u1'),
          ),
        ],
        child: _app(),
      ),
    );
    await tester.pump();

    // The score field renders its em-dash hint while empty — one per row.
    expect(find.text('—'), findsOneWidget);
    // Player name field is seeded with the current user.
    expect(find.text('Me'), findsOneWidget);
  });
}
