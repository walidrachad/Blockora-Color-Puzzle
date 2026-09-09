import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_config.dart';
import 'consent.dart';

enum AdOutcome {
  rewarded,
  dismissed,
  dismissedWithoutReward,
  failed,
  failedToLoad,
  failedToShow,
  unavailable,
  disabled,
  consentRequired,
}

final ValueNotifier<bool> _defaultAdsBool = ValueNotifier(false);
final ValueNotifier<AdsRemoteConfig> _defaultAdsConfig = ValueNotifier(
  AdsRemoteConfig.defaults(),
);
final BannerAdController _disabledBannerController = BannerAdController();

/// Stable legacy boundary. Keeping this small lets existing game fakes remain
/// source-compatible while the optional production API lives below.
abstract class AdsService {
  Future<AdOutcome> showRewarded();

  void dispose();
}

/// Optional production capabilities. Callers can use the extension below when
/// they receive the legacy [AdsService] type.
abstract class AdvancedAdsService extends AdsService {
  ValueListenable<bool> get rewardedReady => _defaultAdsBool;

  bool get canRequestAds => false;

  bool get rewardedReadyValue => rewardedReady.value;

  ValueListenable<AdsRemoteConfig> get configListenable => _defaultAdsConfig;

  AdsRemoteConfig get config => configListenable.value;

  ValueListenable<bool> get privacyOptionsRequired => _defaultAdsBool;

  BannerAdController get bannerController => _disabledBannerController;

  Future<void> initialize({
    required AdsRemoteConfig config,
    required bool canRequestAds,
    bool? privacyOptionsRequired,
  }) async {}

  Future<void> updateConfiguration({
    required AdsRemoteConfig config,
    required bool canRequestAds,
    bool? privacyOptionsRequired,
  }) async {}

  @override
  Future<AdOutcome> showRewarded() async => AdOutcome.unavailable;

  Future<AdOutcome> showInterstitialIfEligible({
    required int completedGames,
  }) async => AdOutcome.unavailable;

  Future<ConsentSnapshot> showPrivacyOptions() async =>
      const ConsentSnapshot.unknown();

  @override
  void dispose() {}
}

extension AdsServiceOptionalApi on AdsService {
  ValueListenable<bool> get rewardedReady => this is AdvancedAdsService
      ? (this as AdvancedAdsService).rewardedReady
      : _defaultAdsBool;

  bool get rewardedReadyValue => rewardedReady.value;

  bool get canRequestAds => this is AdvancedAdsService
      ? (this as AdvancedAdsService).canRequestAds
      : false;

  ValueListenable<AdsRemoteConfig> get configListenable =>
      this is AdvancedAdsService
      ? (this as AdvancedAdsService).configListenable
      : _defaultAdsConfig;

  AdsRemoteConfig get config => configListenable.value;

  ValueListenable<bool> get privacyOptionsRequired => this is AdvancedAdsService
      ? (this as AdvancedAdsService).privacyOptionsRequired
      : _defaultAdsBool;

  BannerAdController get bannerController => this is AdvancedAdsService
      ? (this as AdvancedAdsService).bannerController
      : _disabledBannerController;

  Future<void> initialize({
    required AdsRemoteConfig config,
    required bool canRequestAds,
    bool? privacyOptionsRequired,
  }) => this is AdvancedAdsService
      ? (this as AdvancedAdsService).initialize(
          config: config,
          canRequestAds: canRequestAds,
          privacyOptionsRequired: privacyOptionsRequired,
        )
      : Future<void>.value();

  Future<void> updateConfiguration({
    required AdsRemoteConfig config,
    required bool canRequestAds,
    bool? privacyOptionsRequired,
  }) => this is AdvancedAdsService
      ? (this as AdvancedAdsService).updateConfiguration(
          config: config,
          canRequestAds: canRequestAds,
          privacyOptionsRequired: privacyOptionsRequired,
        )
      : Future<void>.value();

  Future<AdOutcome> showInterstitialIfEligible({required int completedGames}) =>
      this is AdvancedAdsService
      ? (this as AdvancedAdsService).showInterstitialIfEligible(
          completedGames: completedGames,
        )
      : Future<AdOutcome>.value(AdOutcome.unavailable);

  Future<ConsentSnapshot> showPrivacyOptions() => this is AdvancedAdsService
      ? (this as AdvancedAdsService).showPrivacyOptions()
      : Future<ConsentSnapshot>.value(const ConsentSnapshot.unknown());
}

/// Test/development implementation. It never touches the Google SDK or the
/// network, and remains compatible with the existing cubit tests.
class TestAdsService extends AdvancedAdsService {
  TestAdsService({
    this.outcome = AdOutcome.rewarded,
    this.interstitialOutcome = AdOutcome.unavailable,
    bool ready = true,
  }) : _rewardedReady = ValueNotifier(ready),
       _config = ValueNotifier(AdsRemoteConfig.defaults()),
       _canRequestAds = ready,
       _privacyOptionsRequired = ValueNotifier(false);

  AdOutcome outcome;
  AdOutcome interstitialOutcome;
  final ValueNotifier<bool> _rewardedReady;
  final ValueNotifier<AdsRemoteConfig> _config;
  bool _canRequestAds;
  final ValueNotifier<bool> _privacyOptionsRequired;
  int rewardedShowCount = 0;
  int interstitialShowCount = 0;

  @override
  ValueListenable<bool> get rewardedReady => _rewardedReady;

  @override
  ValueListenable<AdsRemoteConfig> get configListenable => _config;

  @override
  bool get canRequestAds => _canRequestAds;

  @override
  ValueListenable<bool> get privacyOptionsRequired => _privacyOptionsRequired;

  @override
  Future<AdOutcome> showRewarded() async {
    if (!_rewardedReady.value) return AdOutcome.unavailable;
    rewardedShowCount++;
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return outcome;
  }

  @override
  Future<void> initialize({
    required AdsRemoteConfig config,
    required bool canRequestAds,
    bool? privacyOptionsRequired,
  }) => updateConfiguration(
    config: config,
    canRequestAds: canRequestAds,
    privacyOptionsRequired: privacyOptionsRequired,
  );

  @override
  Future<AdOutcome> showInterstitialIfEligible({
    required int completedGames,
  }) async {
    interstitialShowCount++;
    return interstitialOutcome;
  }

  @override
  Future<void> updateConfiguration({
    required AdsRemoteConfig config,
    required bool canRequestAds,
    bool? privacyOptionsRequired,
  }) async {
    _config.value = config;
    _canRequestAds = canRequestAds;
    if (privacyOptionsRequired != null) {
      _privacyOptionsRequired.value = privacyOptionsRequired;
    }
    _rewardedReady.value = canRequestAds && config.canOfferRewardedRevive;
  }

  @override
  void dispose() {
    _rewardedReady.dispose();
    _config.dispose();
    _privacyOptionsRequired.dispose();
  }
}

class AdFrequencyController {
  int _interstitialsShown = 0;
  DateTime? _lastInterstitialAt;
  DateTime? _lastRewardedAt;

  int get interstitialsShown => _interstitialsShown;

  bool canShow({
    required AdsRemoteConfig config,
    required int completedGames,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    if (!config.adsEnabled || !config.interstitialEnabled) return false;
    if (config.interstitialMaxPerSession <= _interstitialsShown) return false;
    if (completedGames <= 0 ||
        completedGames % config.interstitialEveryNCompletedGames != 0) {
      return false;
    }
    final last = _lastInterstitialAt;
    if (last != null &&
        current.difference(last).inSeconds <
            config.interstitialMinIntervalSeconds) {
      return false;
    }
    final lastRewarded = _lastRewardedAt;
    if (lastRewarded != null &&
        current.difference(lastRewarded).inSeconds <
            config.interstitialMinIntervalSeconds) {
      return false;
    }
    return true;
  }

  void recordInterstitialShown([DateTime? now]) {
    _interstitialsShown++;
    _lastInterstitialAt = now ?? DateTime.now();
  }

  void recordRewardedShown([DateTime? now]) {
    _lastRewardedAt = now ?? DateTime.now();
  }
}

class BannerAdController {
  final ValueNotifier<BannerAd?> _ad = ValueNotifier(null);
  AdSize? _adSize;
  Future<void>? _loadInFlight;
  String? _loadedUnitId;
  bool _disposed = false;

  ValueListenable<BannerAd?> get ad => _ad;

  AdSize? get adSize => _adSize;

  Future<void> ensureLoaded({
    required AdsRemoteConfig config,
    required AdPlacement placement,
    required double width,
    required TargetPlatform platform,
    required bool canRequestAds,
    required bool useTestIds,
  }) {
    final unitId = config.adUnitId(
      format: AdFormat.banner,
      platform: platform,
      useTestIds: useTestIds,
    );
    final widthInPixels = width.truncate();
    if (_disposed ||
        !_isMobilePlatform(platform) ||
        !canRequestAds ||
        !config.showsBannerAt(placement) ||
        unitId == null ||
        widthInPixels <= 0) {
      return Future<void>.value();
    }
    if (_ad.value != null && _loadedUnitId == unitId) {
      return Future<void>.value();
    }
    return _loadInFlight ??= _load(
      unitId: unitId,
      nonPersonalizedAds: !config.adsPersonalizationEnabled,
    );
  }

  Future<void> _load({
    required String unitId,
    required bool nonPersonalizedAds,
  }) async {
    try {
      // Use Google's compact 320x50 banner for gameplay so the ad remains
      // visible without taking too much vertical space from the board.
      const size = AdSize.banner;
      if (_disposed) return;
      final ad = BannerAd(
        adUnitId: unitId,
        size: size,
        request: AdRequest(nonPersonalizedAds: nonPersonalizedAds),
        listener: BannerAdListener(
          onAdLoaded: (loadedAd) {
            if (_disposed || loadedAd is! BannerAd) {
              loadedAd.dispose();
              return;
            }
            _ad.value?.dispose();
            _adSize = loadedAd.size;
            _loadedUnitId = unitId;
            _ad.value = loadedAd;
          },
          onAdFailedToLoad: (failedAd, _) {
            failedAd.dispose();
            if (_ad.value == failedAd) _ad.value = null;
            _adSize = null;
            _loadedUnitId = null;
          },
        ),
      );
      await ad.load();
    } catch (_) {
      // A failed banner collapses to zero height and can retry on a later
      // layout/configuration change without affecting the game.
    } finally {
      _loadInFlight = null;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ad.value?.dispose();
    _ad.dispose();
  }

  void clear() {
    if (_disposed) return;
    _ad.value?.dispose();
    _ad.value = null;
    _adSize = null;
    _loadedUnitId = null;
  }
}

class AdsBannerSlot extends StatefulWidget {
  const AdsBannerSlot({required this.ads, required this.placement, super.key});

  final AdsService ads;
  final AdPlacement placement;

  @override
  State<AdsBannerSlot> createState() => _AdsBannerSlotState();
}

class _AdsBannerSlotState extends State<AdsBannerSlot> {
  @override
  void dispose() {
    // A BannerAd can be attached to only one AdWidget. The controller is
    // shared by the app, so release the ad when this screen leaves the tree
    // instead of reusing it in a newly pushed gameplay route.
    final controller = widget.ads.bannerController;
    super.dispose();
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AdsRemoteConfig>(
      valueListenable: widget.ads.configListenable,
      builder: (context, config, child) {
        if (!config.showsBannerAt(widget.placement)) {
          return const SizedBox.shrink();
        }
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            if (width > 0) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                unawaited(
                  widget.ads.bannerController.ensureLoaded(
                    config: config,
                    placement: widget.placement,
                    width: width,
                    platform: defaultTargetPlatform,
                    canRequestAds: widget.ads.canRequestAds,
                    useTestIds: kDebugMode || kProfileMode,
                  ),
                );
              });
            }
            return ValueListenableBuilder<BannerAd?>(
              valueListenable: widget.ads.bannerController.ad,
              builder: (context, ad, child) {
                if (ad == null) return const SizedBox.shrink();
                return Center(
                  child: SizedBox(
                    width: ad.size.width.toDouble(),
                    height: ad.size.height.toDouble(),
                    child: AdWidget(ad: ad),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class GoogleAdsService extends AdvancedAdsService {
  GoogleAdsService({ConsentService? consent, DateTime Function()? clock})
    : _consent = consent,
      _clock = clock ?? DateTime.now,
      _config = ValueNotifier(AdsRemoteConfig.defaults()),
      _rewardedReady = ValueNotifier(false),
      _privacyOptionsRequired = ValueNotifier(false),
      _bannerController = BannerAdController();

  final ConsentService? _consent;
  final DateTime Function() _clock;
  final ValueNotifier<AdsRemoteConfig> _config;
  final ValueNotifier<bool> _rewardedReady;
  final ValueNotifier<bool> _privacyOptionsRequired;
  final BannerAdController _bannerController;
  final AdFrequencyController frequency = AdFrequencyController();
  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;
  String? _rewardedUnitId;
  String? _interstitialUnitId;
  bool _sdkInitialized = false;
  bool _canRequestAds = false;
  bool _rewardedLoading = false;
  bool _interstitialLoading = false;
  bool _rewardedShowing = false;
  bool _interstitialShowing = false;
  bool _disposed = false;
  Timer? _rewardedRetry;
  Timer? _interstitialRetry;

  @override
  ValueListenable<bool> get rewardedReady => _rewardedReady;

  @override
  bool get canRequestAds => _canRequestAds;

  @override
  ValueListenable<AdsRemoteConfig> get configListenable => _config;

  @override
  ValueListenable<bool> get privacyOptionsRequired => _privacyOptionsRequired;

  @override
  BannerAdController get bannerController => _bannerController;

  @override
  Future<void> initialize({
    required AdsRemoteConfig config,
    required bool canRequestAds,
    bool? privacyOptionsRequired,
  }) => updateConfiguration(
    config: config,
    canRequestAds: canRequestAds,
    privacyOptionsRequired: privacyOptionsRequired,
  );

  @override
  Future<void> updateConfiguration({
    required AdsRemoteConfig config,
    required bool canRequestAds,
    bool? privacyOptionsRequired,
  }) async {
    if (_disposed) return;
    _config.value = config;
    _canRequestAds = canRequestAds;
    if (privacyOptionsRequired != null) {
      _privacyOptionsRequired.value = privacyOptionsRequired;
    }
    final useTestIds = kDebugMode || kProfileMode;
    final nextRewardedUnit = config.adUnitId(
      format: AdFormat.rewarded,
      platform: defaultTargetPlatform,
      useTestIds: useTestIds,
    );
    final nextInterstitialUnit = config.adUnitId(
      format: AdFormat.interstitial,
      platform: defaultTargetPlatform,
      useTestIds: useTestIds,
    );
    if (_rewardedUnitId != nextRewardedUnit && !_rewardedShowing) {
      _rewarded?.dispose();
      _rewarded = null;
      _rewardedUnitId = null;
    }
    if (_interstitialUnitId != nextInterstitialUnit && !_interstitialShowing) {
      _interstitial?.dispose();
      _interstitial = null;
      _interstitialUnitId = null;
    }
    if (!_isMobilePlatform(defaultTargetPlatform) ||
        !canRequestAds ||
        !config.adsEnabled) {
      if (!_rewardedShowing) {
        _rewarded?.dispose();
        _rewarded = null;
        _rewardedUnitId = null;
      }
      if (!_interstitialShowing) {
        _interstitial?.dispose();
        _interstitial = null;
        _interstitialUnitId = null;
      }
      _bannerController.clear();
      _rewardedReady.value = false;
      return;
    }
    final hasEnabledUnit =
        (config.rewardedEnabled &&
            config.canOfferRewardedRevive &&
            nextRewardedUnit != null) ||
        (config.interstitialEnabled && nextInterstitialUnit != null) ||
        (config.bannerEnabled &&
            config.adUnitId(
                  format: AdFormat.banner,
                  platform: defaultTargetPlatform,
                  useTestIds: useTestIds,
                ) !=
                null);
    if (!hasEnabledUnit) {
      _bannerController.clear();
      _rewardedReady.value = false;
      return;
    }
    try {
      if (!_sdkInitialized) {
        await MobileAds.instance.initialize();
        if (_disposed) return;
        _sdkInitialized = true;
      }
      _preloadRewarded();
      _preloadInterstitial();
    } catch (_) {
      _rewardedReady.value = false;
    }
  }

  void _preloadRewarded() {
    if (_disposed ||
        !_sdkInitialized ||
        !_canRequestAds ||
        !_config.value.canOfferRewardedRevive ||
        _rewarded != null ||
        _rewardedLoading) {
      return;
    }
    final unitId = _config.value.adUnitId(
      format: AdFormat.rewarded,
      platform: defaultTargetPlatform,
      useTestIds: kDebugMode || kProfileMode,
    );
    if (unitId == null) return;
    _rewardedLoading = true;
    RewardedAd.load(
      adUnitId: unitId,
      request: _request(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedLoading = false;
          _rewardedRetry?.cancel();
          _rewardedRetry = null;
          if (_disposed) {
            ad.dispose();
            return;
          }
          if (!_canRequestAds || !_config.value.canOfferRewardedRevive) {
            ad.dispose();
            return;
          }
          _rewarded?.dispose();
          _rewarded = ad;
          _rewardedUnitId = unitId;
          _rewardedReady.value = true;
        },
        onAdFailedToLoad: (error) {
          _rewardedLoading = false;
          _rewardedReady.value = false;
          _scheduleRewardedRetry();
        },
      ),
    );
  }

  void _scheduleRewardedRetry() {
    if (_disposed || _rewardedRetry?.isActive == true) return;
    _rewardedRetry = Timer(const Duration(seconds: 30), _preloadRewarded);
  }

  void _preloadInterstitial() {
    if (_disposed ||
        !_sdkInitialized ||
        !_canRequestAds ||
        !_config.value.interstitialEnabled ||
        _interstitial != null ||
        _interstitialLoading) {
      return;
    }
    final unitId = _config.value.adUnitId(
      format: AdFormat.interstitial,
      platform: defaultTargetPlatform,
      useTestIds: kDebugMode || kProfileMode,
    );
    if (unitId == null) return;
    _interstitialLoading = true;
    InterstitialAd.load(
      adUnitId: unitId,
      request: _request(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialLoading = false;
          _interstitialRetry?.cancel();
          _interstitialRetry = null;
          if (_disposed) {
            ad.dispose();
            return;
          }
          if (!_canRequestAds || !_config.value.interstitialEnabled) {
            ad.dispose();
            return;
          }
          _interstitial?.dispose();
          _interstitial = ad;
          _interstitialUnitId = unitId;
        },
        onAdFailedToLoad: (_) {
          _interstitialLoading = false;
          _scheduleInterstitialRetry();
        },
      ),
    );
  }

  void _scheduleInterstitialRetry() {
    if (_disposed || _interstitialRetry?.isActive == true) return;
    _interstitialRetry = Timer(
      const Duration(seconds: 30),
      _preloadInterstitial,
    );
  }

  AdRequest _request() =>
      AdRequest(nonPersonalizedAds: !_config.value.adsPersonalizationEnabled);

  @override
  Future<AdOutcome> showRewarded() async {
    if (_disposed ||
        !_sdkInitialized ||
        !_canRequestAds ||
        !_config.value.canOfferRewardedRevive ||
        _rewardedShowing ||
        _interstitialShowing) {
      return _canRequestAds ? AdOutcome.unavailable : AdOutcome.consentRequired;
    }
    final ad = _rewarded;
    if (ad == null) {
      _preloadRewarded();
      return AdOutcome.unavailable;
    }
    _rewarded = null;
    _rewardedUnitId = null;
    _rewardedReady.value = false;
    _rewardedShowing = true;
    var earned = false;
    var completed = false;
    final completer = Completer<AdOutcome>();
    void finish(AdOutcome result) {
      if (completed) return;
      completed = true;
      _rewardedShowing = false;
      ad.dispose();
      _rewardedRetry?.cancel();
      _rewardedRetry = Timer(const Duration(seconds: 2), _preloadRewarded);
      completer.complete(earned ? AdOutcome.rewarded : result);
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdShowedFullScreenContent: (_) =>
          frequency.recordRewardedShown(_clock()),
      onAdDismissedFullScreenContent: (_) => finish(
        earned ? AdOutcome.rewarded : AdOutcome.dismissedWithoutReward,
      ),
      onAdFailedToShowFullScreenContent: (_, _) =>
          finish(AdOutcome.failedToShow),
    );
    try {
      await ad.show(
        onUserEarnedReward: (_, _) {
          if (!earned) earned = true;
        },
      );
    } catch (_) {
      finish(AdOutcome.failedToShow);
    }
    return completer.future;
  }

  @override
  Future<AdOutcome> showInterstitialIfEligible({
    required int completedGames,
  }) async {
    if (_disposed ||
        !_sdkInitialized ||
        !_canRequestAds ||
        _rewardedShowing ||
        _interstitialShowing ||
        !_config.value.interstitialEnabled ||
        !frequency.canShow(
          config: _config.value,
          completedGames: completedGames,
          now: _clock(),
        )) {
      return AdOutcome.unavailable;
    }
    final ad = _interstitial;
    if (ad == null) {
      _preloadInterstitial();
      return AdOutcome.unavailable;
    }
    _interstitial = null;
    _interstitialUnitId = null;
    _interstitialShowing = true;
    var completed = false;
    final completer = Completer<AdOutcome>();
    void finish(AdOutcome result) {
      if (completed) return;
      completed = true;
      _interstitialShowing = false;
      ad.dispose();
      _interstitialRetry?.cancel();
      _interstitialRetry = Timer(
        const Duration(seconds: 2),
        _preloadInterstitial,
      );
      completer.complete(result);
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdShowedFullScreenContent: (_) {
        frequency.recordInterstitialShown(_clock());
      },
      onAdDismissedFullScreenContent: (_) => finish(AdOutcome.dismissed),
      onAdFailedToShowFullScreenContent: (_, _) =>
          finish(AdOutcome.failedToShow),
    );
    try {
      await ad.show();
    } catch (_) {
      finish(AdOutcome.failedToShow);
    }
    return completer.future;
  }

  @override
  Future<ConsentSnapshot> showPrivacyOptions() async {
    final consent = _consent;
    if (consent == null) return const ConsentSnapshot.unknown();
    final snapshot = await consent.showPrivacyOptions();
    _privacyOptionsRequired.value = snapshot.privacyOptionsRequired;
    await updateConfiguration(
      config: _config.value,
      canRequestAds: snapshot.canRequestAds,
    );
    return snapshot;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _rewardedRetry?.cancel();
    _interstitialRetry?.cancel();
    _rewarded?.dispose();
    _interstitial?.dispose();
    _rewarded = null;
    _interstitial = null;
    _bannerController.dispose();
    _rewardedReady.dispose();
    _privacyOptionsRequired.dispose();
    _config.dispose();
  }
}

bool _isMobilePlatform(TargetPlatform platform) =>
    platform == TargetPlatform.android || platform == TargetPlatform.iOS;
