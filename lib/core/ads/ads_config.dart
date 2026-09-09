import 'package:flutter/foundation.dart';

enum AdsReviveStrategy { clearMostFilledLine, removeLastPlacedPiece }

enum AdFormat { banner, interstitial, rewarded }

enum AdPlacement { gameplay, home, results }

/// Typed, validated Remote Config values used by the ad layer.
///
/// Remote Config is client-readable configuration, never a secret store. The
/// in-app defaults intentionally keep every ad format disabled until the
/// owner publishes and validates a configuration.
@immutable
class AdsRemoteConfig {
  const AdsRemoteConfig({
    required this.adsEnabled,
    required this.bannerEnabled,
    required this.interstitialEnabled,
    required this.rewardedEnabled,
    required this.bannerAndroidAdUnitId,
    required this.bannerIosAdUnitId,
    required this.interstitialAndroidAdUnitId,
    required this.interstitialIosAdUnitId,
    required this.rewardedAndroidAdUnitId,
    required this.rewardedIosAdUnitId,
    required this.bannerShowOnGameplay,
    required this.bannerShowOnHome,
    required this.bannerShowOnResults,
    required this.interstitialEveryNCompletedGames,
    required this.interstitialMinIntervalSeconds,
    required this.interstitialMaxPerSession,
    required this.rewardedReviveEnabled,
    required this.rewardedReviveMaxPerGame,
    required this.rewardedReviveCountdownSeconds,
    required this.rewardedReviveStrategy,
    required this.adsPersonalizationEnabled,
  });

  factory AdsRemoteConfig.defaults() => const AdsRemoteConfig(
    adsEnabled: false,
    bannerEnabled: false,
    interstitialEnabled: false,
    rewardedEnabled: false,
    bannerAndroidAdUnitId: null,
    bannerIosAdUnitId: null,
    interstitialAndroidAdUnitId: null,
    interstitialIosAdUnitId: null,
    rewardedAndroidAdUnitId: null,
    rewardedIosAdUnitId: null,
    bannerShowOnGameplay: true,
    bannerShowOnHome: true,
    bannerShowOnResults: true,
    interstitialEveryNCompletedGames: 3,
    interstitialMinIntervalSeconds: 120,
    interstitialMaxPerSession: 3,
    rewardedReviveEnabled: true,
    rewardedReviveMaxPerGame: 1,
    rewardedReviveCountdownSeconds: 5,
    rewardedReviveStrategy: AdsReviveStrategy.clearMostFilledLine,
    adsPersonalizationEnabled: false,
  );

  factory AdsRemoteConfig.fromMap(Map<String, Object?> values) {
    final defaults = AdsRemoteConfig.defaults();
    return AdsRemoteConfig(
      adsEnabled: _readBool(values, 'ads_enabled', defaults.adsEnabled),
      bannerEnabled: _readBool(
        values,
        'banner_enabled',
        defaults.bannerEnabled,
      ),
      interstitialEnabled: _readBool(
        values,
        'interstitial_enabled',
        defaults.interstitialEnabled,
      ),
      rewardedEnabled: _readBool(
        values,
        'rewarded_enabled',
        defaults.rewardedEnabled,
      ),
      bannerAndroidAdUnitId: _readAdUnit(values['banner_android_ad_unit_id']),
      bannerIosAdUnitId: _readAdUnit(values['banner_ios_ad_unit_id']),
      interstitialAndroidAdUnitId: _readAdUnit(
        values['interstitial_android_ad_unit_id'],
      ),
      interstitialIosAdUnitId: _readAdUnit(
        values['interstitial_ios_ad_unit_id'],
      ),
      rewardedAndroidAdUnitId: _readAdUnit(
        values['rewarded_android_ad_unit_id'],
      ),
      rewardedIosAdUnitId: _readAdUnit(values['rewarded_ios_ad_unit_id']),
      bannerShowOnGameplay: _readBool(
        values,
        'banner_show_on_gameplay',
        defaults.bannerShowOnGameplay,
      ),
      bannerShowOnHome: _readBool(
        values,
        'banner_show_on_home',
        defaults.bannerShowOnHome,
      ),
      bannerShowOnResults: _readBool(
        values,
        'banner_show_on_results',
        defaults.bannerShowOnResults,
      ),
      interstitialEveryNCompletedGames: _readInt(
        values,
        'interstitial_every_n_completed_games',
        defaults.interstitialEveryNCompletedGames,
        min: 1,
        max: 100,
      ),
      interstitialMinIntervalSeconds: _readInt(
        values,
        'interstitial_min_interval_seconds',
        defaults.interstitialMinIntervalSeconds,
        min: 0,
        max: 86400,
      ),
      interstitialMaxPerSession: _readInt(
        values,
        'interstitial_max_per_session',
        defaults.interstitialMaxPerSession,
        min: 0,
        max: 20,
      ),
      rewardedReviveEnabled: _readBool(
        values,
        'rewarded_revive_enabled',
        defaults.rewardedReviveEnabled,
      ),
      rewardedReviveMaxPerGame: _readInt(
        values,
        'rewarded_revive_max_per_game',
        defaults.rewardedReviveMaxPerGame,
        min: 0,
        max: 3,
      ),
      rewardedReviveCountdownSeconds: _readInt(
        values,
        'rewarded_revive_countdown_seconds',
        defaults.rewardedReviveCountdownSeconds,
        min: 1,
        max: 30,
      ),
      rewardedReviveStrategy: _readStrategy(
        values['rewarded_revive_strategy'],
        defaults.rewardedReviveStrategy,
      ),
      adsPersonalizationEnabled: _readBool(
        values,
        'ads_personalization_enabled',
        defaults.adsPersonalizationEnabled,
      ),
    );
  }

  final bool adsEnabled;
  final bool bannerEnabled;
  final bool interstitialEnabled;
  final bool rewardedEnabled;
  final String? bannerAndroidAdUnitId;
  final String? bannerIosAdUnitId;
  final String? interstitialAndroidAdUnitId;
  final String? interstitialIosAdUnitId;
  final String? rewardedAndroidAdUnitId;
  final String? rewardedIosAdUnitId;
  final bool bannerShowOnGameplay;
  final bool bannerShowOnHome;
  final bool bannerShowOnResults;
  final int interstitialEveryNCompletedGames;
  final int interstitialMinIntervalSeconds;
  final int interstitialMaxPerSession;
  final bool rewardedReviveEnabled;
  final int rewardedReviveMaxPerGame;
  final int rewardedReviveCountdownSeconds;
  final AdsReviveStrategy rewardedReviveStrategy;
  final bool adsPersonalizationEnabled;

  bool showsBannerAt(AdPlacement placement) {
    if (!adsEnabled || !bannerEnabled) return false;
    return switch (placement) {
      AdPlacement.gameplay => bannerShowOnGameplay,
      AdPlacement.home => bannerShowOnHome,
      AdPlacement.results => bannerShowOnResults,
    };
  }

  bool get canOfferRewardedRevive =>
      adsEnabled &&
      rewardedEnabled &&
      rewardedReviveEnabled &&
      rewardedReviveMaxPerGame > 0;

  String? adUnitId({
    required AdFormat format,
    required TargetPlatform platform,
    bool useTestIds = false,
  }) {
    if (useTestIds) return _testAdUnitId(format, platform);
    if (platform == TargetPlatform.android) {
      return switch (format) {
        AdFormat.banner => bannerAndroidAdUnitId,
        AdFormat.interstitial => interstitialAndroidAdUnitId,
        AdFormat.rewarded => rewardedAndroidAdUnitId,
      };
    }
    if (platform == TargetPlatform.iOS) {
      return switch (format) {
        AdFormat.banner => bannerIosAdUnitId,
        AdFormat.interstitial => interstitialIosAdUnitId,
        AdFormat.rewarded => rewardedIosAdUnitId,
      };
    }
    return null;
  }

  Map<String, Object> toRemoteConfigDefaults() => {
    'ads_enabled': adsEnabled,
    'banner_enabled': bannerEnabled,
    'interstitial_enabled': interstitialEnabled,
    'rewarded_enabled': rewardedEnabled,
    'banner_android_ad_unit_id': bannerAndroidAdUnitId ?? '',
    'banner_ios_ad_unit_id': bannerIosAdUnitId ?? '',
    'interstitial_android_ad_unit_id': interstitialAndroidAdUnitId ?? '',
    'interstitial_ios_ad_unit_id': interstitialIosAdUnitId ?? '',
    'rewarded_android_ad_unit_id': rewardedAndroidAdUnitId ?? '',
    'rewarded_ios_ad_unit_id': rewardedIosAdUnitId ?? '',
    'banner_show_on_gameplay': bannerShowOnGameplay,
    'banner_show_on_home': bannerShowOnHome,
    'banner_show_on_results': bannerShowOnResults,
    'interstitial_every_n_completed_games': interstitialEveryNCompletedGames,
    'interstitial_min_interval_seconds': interstitialMinIntervalSeconds,
    'interstitial_max_per_session': interstitialMaxPerSession,
    'rewarded_revive_enabled': rewardedReviveEnabled,
    'rewarded_revive_max_per_game': rewardedReviveMaxPerGame,
    'rewarded_revive_countdown_seconds': rewardedReviveCountdownSeconds,
    'rewarded_revive_strategy': switch (rewardedReviveStrategy) {
      AdsReviveStrategy.clearMostFilledLine => 'clear_most_filled_line',
      AdsReviveStrategy.removeLastPlacedPiece => 'remove_last_placed_piece',
    },
    'ads_personalization_enabled': adsPersonalizationEnabled,
  };

  @override
  bool operator ==(Object other) =>
      other is AdsRemoteConfig &&
      adsEnabled == other.adsEnabled &&
      bannerEnabled == other.bannerEnabled &&
      interstitialEnabled == other.interstitialEnabled &&
      rewardedEnabled == other.rewardedEnabled &&
      bannerAndroidAdUnitId == other.bannerAndroidAdUnitId &&
      bannerIosAdUnitId == other.bannerIosAdUnitId &&
      interstitialAndroidAdUnitId == other.interstitialAndroidAdUnitId &&
      interstitialIosAdUnitId == other.interstitialIosAdUnitId &&
      rewardedAndroidAdUnitId == other.rewardedAndroidAdUnitId &&
      rewardedIosAdUnitId == other.rewardedIosAdUnitId &&
      bannerShowOnGameplay == other.bannerShowOnGameplay &&
      bannerShowOnHome == other.bannerShowOnHome &&
      bannerShowOnResults == other.bannerShowOnResults &&
      interstitialEveryNCompletedGames ==
          other.interstitialEveryNCompletedGames &&
      interstitialMinIntervalSeconds == other.interstitialMinIntervalSeconds &&
      interstitialMaxPerSession == other.interstitialMaxPerSession &&
      rewardedReviveEnabled == other.rewardedReviveEnabled &&
      rewardedReviveMaxPerGame == other.rewardedReviveMaxPerGame &&
      rewardedReviveCountdownSeconds == other.rewardedReviveCountdownSeconds &&
      rewardedReviveStrategy == other.rewardedReviveStrategy &&
      adsPersonalizationEnabled == other.adsPersonalizationEnabled;

  @override
  int get hashCode => Object.hashAll([
    adsEnabled,
    bannerEnabled,
    interstitialEnabled,
    rewardedEnabled,
    bannerAndroidAdUnitId,
    bannerIosAdUnitId,
    interstitialAndroidAdUnitId,
    interstitialIosAdUnitId,
    rewardedAndroidAdUnitId,
    rewardedIosAdUnitId,
    bannerShowOnGameplay,
    bannerShowOnHome,
    bannerShowOnResults,
    interstitialEveryNCompletedGames,
    interstitialMinIntervalSeconds,
    interstitialMaxPerSession,
    rewardedReviveEnabled,
    rewardedReviveMaxPerGame,
    rewardedReviveCountdownSeconds,
    rewardedReviveStrategy,
    adsPersonalizationEnabled,
  ]);
}

const _adUnitPattern = r'^ca-app-pub-\d{16}/\d{10}$';

String? _readAdUnit(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return RegExp(_adUnitPattern).hasMatch(trimmed) ? trimmed : null;
}

bool _readBool(Map<String, Object?> values, String key, bool fallback) {
  final value = values[key];
  if (value is bool) return value;
  if (value is String) {
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
        return true;
      case 'false':
      case '0':
      case 'no':
        return false;
    }
  }
  return fallback;
}

int _readInt(
  Map<String, Object?> values,
  String key,
  int fallback, {
  required int min,
  required int max,
}) {
  final value = values[key];
  final parsed = value is int ? value : int.tryParse('$value');
  if (parsed == null) return fallback;
  return parsed.clamp(min, max);
}

AdsReviveStrategy _readStrategy(Object? value, AdsReviveStrategy fallback) {
  return switch ('$value'.trim().toLowerCase()) {
    'clear_most_filled_line' => AdsReviveStrategy.clearMostFilledLine,
    'remove_last_placed_piece' => AdsReviveStrategy.removeLastPlacedPiece,
    _ => fallback,
  };
}

String? _testAdUnitId(AdFormat format, TargetPlatform platform) {
  if (platform == TargetPlatform.android) {
    return switch (format) {
      AdFormat.banner => 'ca-app-pub-3940256099942544/9214589741',
      AdFormat.interstitial => 'ca-app-pub-3940256099942544/1033173712',
      AdFormat.rewarded => 'ca-app-pub-3940256099942544/5224354917',
    };
  }
  if (platform == TargetPlatform.iOS) {
    return switch (format) {
      AdFormat.banner => 'ca-app-pub-3940256099942544/2435281174',
      AdFormat.interstitial => 'ca-app-pub-3940256099942544/4411468910',
      AdFormat.rewarded => 'ca-app-pub-3940256099942544/1712485313',
    };
  }
  return null;
}
