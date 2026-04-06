import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TelemetryService {
  TelemetryService._();

  static final TelemetryService instance = TelemetryService._();
  static const String _firstLevelAttemptedKey = 'analytics_first_level_attempted';
  static const String _firstSeenTimestampMsKey = 'analytics_first_seen_timestamp_ms';
  static const Set<int> _trackedMilestones = <int>{5, 10, 20, 50};

  FirebaseAnalytics get analytics => FirebaseAnalytics.instance;
  FirebaseAnalyticsObserver get analyticsObserver =>
      FirebaseAnalyticsObserver(analytics: analytics);

  Future<void> initialize({required bool enabled}) async {
    await analytics.setAnalyticsCollectionEnabled(enabled);
    if (!enabled) return;

    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final firstSeenMs = prefs.getInt(_firstSeenTimestampMsKey) ?? nowMs;
    if (!prefs.containsKey(_firstSeenTimestampMsKey)) {
      await prefs.setInt(_firstSeenTimestampMsKey, nowMs);
    }

    final firstSeen = DateTime.fromMillisecondsSinceEpoch(firstSeenMs);
    final isFirstWeekActive = DateTime.now().difference(firstSeen).inDays < 7;
    await analytics.setUserProperty(
      name: 'first_week_active',
      value: isFirstWeekActive ? 'true' : 'false',
    );
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

  Future<void> logTutorialStarted({
    required String tutorialType,
    required bool isReplay,
  }) {
    return analytics.logEvent(
      name: 'tutorial_started',
      parameters: {
        'tutorial_type': tutorialType,
        'is_replay': isReplay ? 1 : 0,
      },
    );
  }

  Future<void> logTutorialCompleted({
    required String tutorialType,
    required bool isReplay,
  }) {
    return analytics.logEvent(
      name: 'tutorial_completed',
      parameters: {
        'tutorial_type': tutorialType,
        'is_replay': isReplay ? 1 : 0,
      },
    );
  }

  Future<void> logTutorialSkipped({
    required String tutorialType,
    required bool isReplay,
    required int stepIndex,
  }) {
    return analytics.logEvent(
      name: 'tutorial_skipped',
      parameters: {
        'tutorial_type': tutorialType,
        'is_replay': isReplay ? 1 : 0,
        'step_index': stepIndex,
      },
    );
  }

  Future<void> logFirstLevelAttemptedIfNeeded({required int level}) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_firstLevelAttemptedKey) ?? false) {
      return;
    }

    await analytics.logEvent(
      name: 'first_level_attempted',
      parameters: {
        'level_number': level,
      },
    );
    await prefs.setBool(_firstLevelAttemptedKey, true);
  }

  Future<void> logLevelMilestoneReachedIfNeeded({required int milestone}) async {
    if (!_trackedMilestones.contains(milestone)) {
      return;
    }

    final key = 'analytics_milestone_$milestone';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) ?? false) {
      return;
    }

    await analytics.logEvent(
      name: 'level_milestone_reached',
      parameters: {
        'milestone': milestone,
      },
    );
    await prefs.setBool(key, true);
  }

  Future<void> logRewardedAdRequested({required String actionName}) {
    return analytics.logEvent(
      name: 'rewarded_ad_requested',
      parameters: {
        'action_name': actionName.toLowerCase(),
      },
    );
  }

  Future<void> logRewardedAdShown({required String actionName}) {
    return analytics.logEvent(
      name: 'rewarded_ad_shown',
      parameters: {
        'action_name': actionName.toLowerCase(),
      },
    );
  }

  Future<void> logRewardedAdRewarded({required String actionName}) {
    return analytics.logEvent(
      name: 'rewarded_ad_rewarded',
      parameters: {
        'action_name': actionName.toLowerCase(),
      },
    );
  }

  Future<void> logRewardedAdFailed({
    required String actionName,
    required String reason,
  }) {
    return analytics.logEvent(
      name: 'rewarded_ad_failed',
      parameters: {
        'action_name': actionName.toLowerCase(),
        'reason': reason.toLowerCase(),
      },
    );
  }

  Future<void> logSessionEndSummary({
    required int levelsCompletedInSession,
    required int helpersUsedInSession,
    required String sessionLengthBucket,
  }) {
    return analytics.logEvent(
      name: 'session_end_summary',
      parameters: {
        'levels_completed_in_session': levelsCompletedInSession,
        'helpers_used_in_session': helpersUsedInSession,
        'session_length_bucket': sessionLengthBucket,
      },
    );
  }

  Future<void> setPreferredMode({required String mode}) {
    return analytics.setUserProperty(name: 'preferred_mode', value: mode);
  }

  Future<void> setSoundEnabledUserProperty({required bool enabled}) {
    return analytics.setUserProperty(
      name: 'sound_enabled',
      value: enabled ? 'true' : 'false',
    );
  }
}
