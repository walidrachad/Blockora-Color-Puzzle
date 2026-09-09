import 'package:flutter/material.dart';

class PrismLocalizations {
  const PrismLocalizations();

  static PrismLocalizations of(BuildContext context) =>
      Localizations.of<PrismLocalizations>(context, PrismLocalizations) ??
      const PrismLocalizations();

  String get continueTitle => 'Continue?';
  String get reviveDescription => 'Your run is still alive';
  String get loadingReward => 'Loading your reward…';
  String get restoringMove => 'Restoring your next move…';
  String get watchReward => 'Watch a reward video to revive';
  String get reviveUsed => 'Revive already used';
  String get rewardNotCompleted => 'Reward not earned.';
  String get videoUnavailable => 'Video unavailable — try again.';
  String get oneRevivePerRun => 'Watch a short video • one revive per run';
  String get reviveUsedDescription => 'This run has used its one revive';
  String get revive => 'REVIVE';
  String get reviveUsedButton => 'REVIVE USED';
  String get loading => 'LOADING…';
  String get reviving => 'REVIVING…';
  String get noThanks => 'NO THANKS';

  String adMessage(String? key) => switch (key) {
    'reward_not_completed' => rewardNotCompleted,
    'ad_unavailable' => videoUnavailable,
    _ => key ?? '',
  };
}

class PrismLocalizationsDelegate
    extends LocalizationsDelegate<PrismLocalizations> {
  const PrismLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<PrismLocalizations> load(Locale locale) async =>
      const PrismLocalizations();

  @override
  bool shouldReload(PrismLocalizationsDelegate old) => false;
}
