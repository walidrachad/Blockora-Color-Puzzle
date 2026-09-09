import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_puzzle/core/ads/ads_config.dart';
import 'package:prism_puzzle/core/ads/remote_config.dart';

void main() {
  const androidRewarded = 'ca-app-pub-1234567890123456/1234567890';
  const iosRewarded = 'ca-app-pub-1234567890123456/0987654321';

  test('safe defaults disable every ad format', () {
    final config = AdsRemoteConfig.defaults();
    expect(config.adsEnabled, isFalse);
    expect(config.bannerEnabled, isFalse);
    expect(config.interstitialEnabled, isFalse);
    expect(config.rewardedEnabled, isFalse);
    expect(config.showsBannerAt(AdPlacement.gameplay), isFalse);
    expect(config.rewardedReviveMaxPerGame, 1);
    expect(
      config.rewardedReviveStrategy,
      AdsReviveStrategy.clearMostFilledLine,
    );
  });

  test('gameplay banner placement is enabled when banners are enabled', () {
    final config = AdsRemoteConfig.fromMap({
      'ads_enabled': true,
      'banner_enabled': true,
    });
    expect(config.showsBannerAt(AdPlacement.gameplay), isTrue);
  });

  test('Remote Config values are typed, validated, and clamped', () {
    final config = AdsRemoteConfig.fromMap({
      'ads_enabled': 'true',
      'banner_enabled': true,
      'interstitial_enabled': true,
      'rewarded_enabled': true,
      'rewarded_android_ad_unit_id': androidRewarded,
      'rewarded_ios_ad_unit_id': iosRewarded,
      'interstitial_every_n_completed_games': 0,
      'interstitial_min_interval_seconds': 999999,
      'interstitial_max_per_session': 30,
      'rewarded_revive_strategy': 'remove_last_placed_piece',
    });
    expect(config.adsEnabled, isTrue);
    expect(config.rewardedAndroidAdUnitId, androidRewarded);
    expect(config.rewardedIosAdUnitId, iosRewarded);
    expect(config.interstitialEveryNCompletedGames, 1);
    expect(config.interstitialMinIntervalSeconds, 86400);
    expect(config.interstitialMaxPerSession, 20);
    expect(
      config.rewardedReviveStrategy,
      AdsReviveStrategy.removeLastPlacedPiece,
    );
    expect(
      config.adUnitId(
        format: AdFormat.rewarded,
        platform: TargetPlatform.android,
      ),
      androidRewarded,
    );
  });

  test('invalid IDs are rejected and debug IDs are official test units', () {
    final config = AdsRemoteConfig.fromMap({
      'rewarded_android_ad_unit_id': 'live-id',
      'rewarded_ios_ad_unit_id': 'ca-app-pub-123/456',
    });
    expect(config.rewardedAndroidAdUnitId, isNull);
    expect(config.rewardedIosAdUnitId, isNull);
    expect(
      config.adUnitId(
        format: AdFormat.rewarded,
        platform: TargetPlatform.android,
        useTestIds: true,
      ),
      'ca-app-pub-3940256099942544/5224354917',
    );
    expect(
      config.adUnitId(
        format: AdFormat.banner,
        platform: TargetPlatform.iOS,
        useTestIds: true,
      ),
      'ca-app-pub-3940256099942544/2435281174',
    );
  });

  test('map repository returns the same typed configuration', () async {
    final expected = AdsRemoteConfig.fromMap({
      'ads_enabled': true,
      'banner_show_on_results': false,
    });
    final actual = await MapAdsConfigurationRepository(
      expected.toRemoteConfigDefaults(),
    ).load();
    expect(actual, expected);
  });
}
