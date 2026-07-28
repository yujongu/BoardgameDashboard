import 'package:board_game_dashboard/shared/services/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled AnalyticsService no-ops without touching Firebase', () async {
    const service = AnalyticsService.disabled();

    // None of these construct or call FirebaseAnalytics, so they complete
    // even though Firebase is never initialized in this test.
    await service.logLogin('password');
    await service.logSignUp('google');
    await service.logAddPlay(gameId: 'the-crew', mode: 'coop');
    await service.logAddFriend();
  });
}
