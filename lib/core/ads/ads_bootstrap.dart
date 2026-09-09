import 'package:firebase_core/firebase_core.dart';

import 'ads_config.dart';
import 'ads_service.dart';
import 'consent.dart';
import 'remote_config.dart';

class AdvertisingStartup {
  const AdvertisingStartup({required this.config, required this.consent});

  final AdsRemoteConfig config;
  final ConsentSnapshot consent;
}

/// Starts consent and configuration independently from the first game frame.
/// Missing Firebase options, offline fetches, or unsupported platforms fall
/// back to the safe config and never block the game.
class AdvertisingBootstrap {
  AdvertisingBootstrap({
    required this.ads,
    required this.consent,
    AdsConfigurationRepository? configurationRepository,
    Future<void> Function()? initializeFirebase,
  }) : _configurationRepository = configurationRepository,
       _initializeFirebase =
           initializeFirebase ??
           (() async {
             await Firebase.initializeApp();
           });

  final AdsService ads;
  final ConsentService consent;
  final AdsConfigurationRepository? _configurationRepository;
  final Future<void> Function() _initializeFirebase;

  Future<AdvertisingStartup> start() async {
    var config = AdsRemoteConfig.defaults();
    try {
      await _initializeFirebase();
      config =
          await (_configurationRepository ??
                  FirebaseAdsConfigurationRepository())
              .load();
    } catch (_) {
      // Firebase credentials are owner-supplied and may not exist in a source
      // checkout. The app deliberately remains ad-free with safe defaults.
    }

    final consentSnapshot = await consent.initialize();
    await ads.initialize(
      config: config,
      canRequestAds: consentSnapshot.canRequestAds,
      privacyOptionsRequired: consentSnapshot.privacyOptionsRequired,
    );
    return AdvertisingStartup(config: config, consent: consentSnapshot);
  }
}
