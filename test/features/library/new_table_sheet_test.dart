import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:board_game_dashboard/features/library/new_table_sheet.dart';
import 'package:board_game_dashboard/l10n/app_localizations.dart';
import 'package:board_game_dashboard/shared/models/campaign.dart';
import 'package:board_game_dashboard/shared/models/friend.dart';
import 'package:board_game_dashboard/shared/providers/repository_providers.dart';
import 'package:board_game_dashboard/shared/repositories/friend_repository.dart';
import 'package:board_game_dashboard/shared/theme/app_colors.dart';

class _FakeFriendRepo implements FriendRepository {
  _FakeFriendRepo(this.friends);
  final List<FriendSummary> friends;

  @override
  Stream<List<FriendSummary>> watchMyFriends() => Stream.value(friends);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // The picker sits on its own route, so the sheet's setState cannot rebuild
  // it. Its "Added" marks are a pure function of the addedUserIds it is handed,
  // which means a stale set leaves a friend with no feedback at all — the bug
  // reported after the D12 device test.
  testWidgets('adding a friend marks them Added in the open picker', (
    tester,
  ) async {
    List<CampaignMember>? result;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          friendRepositoryProvider.overrideWithValue(
            _FakeFriendRepo(const [
              FriendSummary(userId: 'uid-bob', name: 'Bob'),
            ]),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppStrings.localizationsDelegates,
          supportedLocales: AppStrings.supportedLocales,
          theme: buildDarkTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  result = await showNewTableSheet(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Open the participant picker from the new-table sheet.
    await tester.tap(find.text('Add player'));
    await tester.pumpAndSettle();

    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Added'), findsNothing);

    await tester.tap(find.text('Bob'));
    await tester.pumpAndSettle();

    // The regression: without a rebuild of the picker this stays absent.
    expect(find.text('Added'), findsOneWidget);

    // Bob is now on both surfaces: the picker row and the seat list behind it.
    expect(find.text('Bob'), findsNWidgets(2));

    // Close the picker; the seat should have landed on the table.
    Navigator.of(tester.element(find.text('open'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create table'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.map((m) => m.name), contains('Bob'));
    expect(result!.firstWhere((m) => m.name == 'Bob').userId, 'uid-bob');
  });
}
