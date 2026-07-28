import 'package:board_game_dashboard/shared/services/analytics_service.dart';

/// No-op analytics override for widget tests. Using the disabled service avoids
/// constructing `FirebaseAnalytics.instance`, which requires Firebase to be
/// initialized (it isn't in widget tests).
final analyticsOverride = analyticsServiceProvider.overrideWithValue(
  const AnalyticsService.disabled(),
);
