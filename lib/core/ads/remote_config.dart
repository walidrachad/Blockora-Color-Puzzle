import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'ads_config.dart';

abstract class AdsConfigurationRepository {
  Future<AdsRemoteConfig> load();
}

/// Firebase-backed Remote Config repository. It returns cached/default values
/// when the network or Firebase setup is unavailable.
class FirebaseAdsConfigurationRepository implements AdsConfigurationRepository {
  FirebaseAdsConfigurationRepository({FirebaseRemoteConfig? remoteConfig})
    : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig _remoteConfig;

  @override
  Future<AdsRemoteConfig> load() async {
    final defaults = AdsRemoteConfig.defaults();
    try {
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 2),
          minimumFetchInterval: kDebugMode || kProfileMode
              ? const Duration(minutes: 5)
              : const Duration(hours: 12),
        ),
      );
      await _remoteConfig.setDefaults(defaults.toRemoteConfigDefaults());
    } catch (_) {
      return defaults;
    }
    try {
      await _remoteConfig.fetchAndActivate();
    } catch (_) {
      // Existing activated values remain available offline. If there are no
      // cached values, the defaults below keep every ad format safe.
    }
    try {
      return AdsRemoteConfig.fromMap({
        'ads_enabled': _remoteConfig.getBool('ads_enabled'),
        'banner_enabled': _remoteConfig.getBool('banner_enabled'),
        'interstitial_enabled': _remoteConfig.getBool('interstitial_enabled'),
        'rewarded_enabled': _remoteConfig.getBool('rewarded_enabled'),
        'banner_android_ad_unit_id': _remoteConfig.getString(
          'banner_android_ad_unit_id',
        ),
        'banner_ios_ad_unit_id': _remoteConfig.getString(
          'banner_ios_ad_unit_id',
        ),
        'interstitial_android_ad_unit_id': _remoteConfig.getString(
          'interstitial_android_ad_unit_id',
        ),
        'interstitial_ios_ad_unit_id': _remoteConfig.getString(
          'interstitial_ios_ad_unit_id',
        ),
        'rewarded_android_ad_unit_id': _remoteConfig.getString(
          'rewarded_android_ad_unit_id',
        ),
        'rewarded_ios_ad_unit_id': _remoteConfig.getString(
          'rewarded_ios_ad_unit_id',
        ),
        'banner_show_on_gameplay': _remoteConfig.getBool(
          'banner_show_on_gameplay',
        ),
        'banner_show_on_home': _remoteConfig.getBool('banner_show_on_home'),
        'banner_show_on_results': _remoteConfig.getBool(
          'banner_show_on_results',
        ),
        'interstitial_every_n_completed_games': _remoteConfig.getInt(
          'interstitial_every_n_completed_games',
        ),
        'interstitial_min_interval_seconds': _remoteConfig.getInt(
          'interstitial_min_interval_seconds',
        ),
        'interstitial_max_per_session': _remoteConfig.getInt(
          'interstitial_max_per_session',
        ),
        'rewarded_revive_enabled': _remoteConfig.getBool(
          'rewarded_revive_enabled',
        ),
        'rewarded_revive_max_per_game': _remoteConfig.getInt(
          'rewarded_revive_max_per_game',
        ),
        'rewarded_revive_countdown_seconds': _remoteConfig.getInt(
          'rewarded_revive_countdown_seconds',
        ),
        'rewarded_revive_strategy': _remoteConfig.getString(
          'rewarded_revive_strategy',
        ),
        'ads_personalization_enabled': _remoteConfig.getBool(
          'ads_personalization_enabled',
        ),
      });
    } catch (_) {
      return defaults;
    }
  }
}

class MapAdsConfigurationRepository implements AdsConfigurationRepository {
  MapAdsConfigurationRepository(this.values);

  final Map<String, Object?> values;

  @override
  Future<AdsRemoteConfig> load() async => AdsRemoteConfig.fromMap(values);
}
