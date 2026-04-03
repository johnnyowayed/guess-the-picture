import 'package:firebase_analytics/firebase_analytics.dart';

class TelemetryService {
  TelemetryService._();

  static final TelemetryService instance = TelemetryService._();

  FirebaseAnalytics get analytics => FirebaseAnalytics.instance;
  FirebaseAnalyticsObserver get analyticsObserver =>
      FirebaseAnalyticsObserver(analytics: analytics);

  Future<void> initialize({required bool enabled}) async {
    await analytics.setAnalyticsCollectionEnabled(enabled);
  }

  Future<void> logLevelStarted({
    required int level,
    required bool isScramble,
    required bool fromReplay,
  }) {
    return analytics.logEvent(
      name: 'level_started',
      parameters: {
        'level_number': level,
        'level_type': isScramble ? 'scramble' : 'image',
        'from_replay': fromReplay ? 1 : 0,
      },
    );
  }

  Future<void> logLevelCompleted({
    required int level,
    required bool isScramble,
  }) {
    return analytics.logEvent(
      name: 'level_completed',
      parameters: {
        'level_number': level,
        'level_type': isScramble ? 'scramble' : 'image',
      },
    );
  }

  Future<void> logLevelFailed({
    required int level,
    required bool isScramble,
  }) {
    return analytics.logEvent(
      name: 'level_failed',
      parameters: {
        'level_number': level,
        'level_type': isScramble ? 'scramble' : 'image',
      },
    );
  }

  Future<void> logHelperUsed({
    required String helper,
    required int level,
    required bool isScramble,
  }) {
    return analytics.logEvent(
      name: 'helper_used',
      parameters: {
        'helper_name': helper,
        'level_number': level,
        'level_type': isScramble ? 'scramble' : 'image',
      },
    );
  }

  Future<void> logTutorialReplay({required String tutorialType}) {
    return analytics.logEvent(
      name: 'tutorial_replay_started',
      parameters: {
        'tutorial_type': tutorialType,
      },
    );
  }

  Future<void> logSettingsOpened() {
    return analytics.logEvent(name: 'settings_opened');
  }

  Future<void> logLoadingFinished({required int initialImagesPreloaded}) {
    return analytics.logEvent(
      name: 'loading_finished',
      parameters: {
        'initial_images_preloaded': initialImagesPreloaded,
      },
    );
  }
}
