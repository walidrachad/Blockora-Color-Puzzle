import 'package:flutter_test/flutter_test.dart';
import 'package:prism_puzzle/core/ads/ads_bootstrap.dart';
import 'package:prism_puzzle/core/ads/ads_config.dart';
import 'package:prism_puzzle/core/ads/ads_service.dart';
import 'package:prism_puzzle/core/ads/consent.dart';
import 'package:prism_puzzle/core/ads/remote_config.dart';

void main() {
  test(
    'bootstrap loads config and consent before enabling ad service',
    () async {
      final consent = FakeConsentService(
        snapshot: const ConsentSnapshot(
          status: ConsentFlowStatus.obtained,
          canRequestAds: true,
          privacyOptionsRequired: true,
        ),
      );
      final ads = TestAdsService(ready: false);
      final config = AdsRemoteConfig.fromMap({
        'ads_enabled': true,
        'rewarded_enabled': true,
        'rewarded_android_ad_unit_id': 'ca-app-pub-1234567890123456/1234567890',
      });
      final startup = await AdvertisingBootstrap(
        ads: ads,
        consent: consent,
        initializeFirebase: () async {},
        configurationRepository: MapAdsConfigurationRepository(
          config.toRemoteConfigDefaults(),
        ),
      ).start();

      expect(startup.config, config);
      expect(consent.initializeCalls, 1);
      expect(ads.config, config);
      expect(ads.rewardedReadyValue, isTrue);
      expect(ads.privacyOptionsRequired.value, isTrue);
    },
  );
}
