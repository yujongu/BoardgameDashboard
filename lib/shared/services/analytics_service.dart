import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Mirrors main.dart's define so dev/emulator runs don't pollute the production
// Analytics property.
const bool _useEmulators = bool.fromEnvironment('USE_EMULATORS');

/// Thin wrapper over [FirebaseAnalytics] for the app's funnel events. On
/// platforms where Analytics is unavailable (Windows/Linux) it is built via
/// [AnalyticsService.disabled] and every method is a no-op.
class AnalyticsService {
  final FirebaseAnalytics? _analytics;

  const AnalyticsService._(this._analytics);

  /// Enabled service. Collection is turned off in debug / emulator runs so dev
  /// activity never reaches the production Analytics property.
  factory AnalyticsService.enabled(FirebaseAnalytics analytics) {
    analytics.setAnalyticsCollectionEnabled(!kDebugMode && !_useEmulators);
    return AnalyticsService._(analytics);
  }

  /// No-op service for unsupported platforms.
  const AnalyticsService.disabled() : _analytics = null;

  Future<void> logLogin(String method) async {
    await _analytics?.logLogin(loginMethod: method);
  }

  Future<void> logSignUp(String method) async {
    await _analytics?.logSignUp(signUpMethod: method);
  }

  Future<void> logAddPlay({
    required String gameId,
    required String mode,
  }) async {
    await _analytics?.logEvent(
      name: 'add_play',
      parameters: {'game_id': gameId, 'mode': mode},
    );
  }

  Future<void> logAddFriend() async {
    await _analytics?.logEvent(name: 'add_friend');
  }
}

/// Builds [FirebaseAnalytics.instance] only on supported platforms, so
/// unsupported platforms — and widget tests without Firebase initialized —
/// never touch it. Override with a no-op fake in tests.
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final supported =
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;
  return supported
      ? AnalyticsService.enabled(FirebaseAnalytics.instance)
      : const AnalyticsService.disabled();
});
