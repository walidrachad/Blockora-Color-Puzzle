import 'package:flutter_test/flutter_test.dart';
import 'package:prism_puzzle/core/ads/ads_config.dart';
import 'package:prism_puzzle/core/ads/ads_service.dart';

void main() {
  final config = AdsRemoteConfig.fromMap({
    'ads_enabled': true,
    'interstitial_enabled': true,
    'interstitial_every_n_completed_games': 3,
    'interstitial_min_interval_seconds': 120,
    'interstitial_max_per_session': 2,
  });
  final start = DateTime(2026, 1, 1);

  test('interstitials skip the first game and use the every-N rule', () {
    final frequency = AdFrequencyController();
    expect(
      frequency.canShow(config: config, completedGames: 1, now: start),
      isFalse,
    );
    expect(
      frequency.canShow(config: config, completedGames: 3, now: start),
      isTrue,
    );
    frequency.recordInterstitialShown(start);
    expect(
      frequency.canShow(
        config: config,
        completedGames: 6,
        now: start.add(const Duration(seconds: 119)),
      ),
      isFalse,
    );
    expect(
      frequency.canShow(
        config: config,
        completedGames: 6,
        now: start.add(const Duration(seconds: 120)),
      ),
      isTrue,
    );
  });

  test('session cap and rewarded cooldown are enforced', () {
    final frequency = AdFrequencyController();
    frequency.recordInterstitialShown(start);
    frequency.recordInterstitialShown(start.add(const Duration(seconds: 120)));
    expect(
      frequency.canShow(
        config: config,
        completedGames: 3,
        now: start.add(const Duration(days: 1)),
      ),
      isFalse,
    );

    final second = AdFrequencyController();
    second.recordRewardedShown(start);
    expect(
      second.canShow(
        config: config,
        completedGames: 3,
        now: start.add(const Duration(seconds: 119)),
      ),
      isFalse,
    );
    expect(
      second.canShow(
        config: config,
        completedGames: 3,
        now: start.add(const Duration(seconds: 120)),
      ),
      isTrue,
    );
  });
}
