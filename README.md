# Blockora

Blockora is an original blue/purple block puzzle game for Android and iOS. It uses an 8×8 board, three-piece batches, drag previews, line clears, combo feedback, and three play modes—Classic, Journey, and Daily Challenge—without copying reference branding, artwork, or audio.

## Run

```bash
flutter pub get
flutter run
```

The app starts with the Blockora splash and mode selection. Ads start disabled
until Firebase Remote Config and UMP consent permit requests. The supplied
native Firebase files configure `com.rachaddev.colorBlock` on Android and iOS.
Debug/profile builds use Google's official test units; the game remains
playable with safe defaults.
See [`docs/ads-and-privacy.md`](docs/ads-and-privacy.md) for owner setup.

## Architecture

- `lib/features/game/domain/`: pure Dart board, piece library, placement, line detection, scoring, generator, revive policy, Journey catalog, and UTC Daily rules.
- `lib/features/game/application/game_cubit.dart`: immutable `GameState` plus the Cubit orchestration layer. Animation controllers are kept in widgets, never in state.
- `lib/features/game/presentation/`: splash destination, mode/level/daily screens, responsive gameplay, custom board/piece/countdown painters, drag interaction, clear effects, combo overlay, Continue overlay, results screen, and settings sheet.
- `lib/core/audio/`: preloaded local clear-tier audio pools and the pure one/two/three-line mapping.
- `lib/core/ads/`: typed Remote Config, UMP consent, Google Mobile Ads
  adapters, frequency controls, adaptive banners, and safe test fakes.
- `lib/core/services/services.dart`: storage, audio, haptics, and compatibility
  exports for the app-facing services.

## Rules and fairness

Every placement scores one point per placed cell. A cleared line scores 100 points; each additional line in the same turn adds 40; each row/column intersection adds 10. A scoring combo applies a 1.25× multiplier per consecutive clear turn, capped at 2×. A no-clear turn resets the combo. Piece batches are seedable and are only replaced after all three slots are used. When a new batch has no playable piece and a playable library shape exists, the first slot is selected from the playable set before the batch is shown.

`ConfiguredRevivePolicy` supports `clear_most_filled_line` and
`remove_last_placed_piece`, with a deterministic legal-move fallback.
Placement IDs are persisted per board cell for the latter strategy. Classic
keeps the endless flow and revive prompt; Journey and Daily default to no
revive and finish with objective/move-limit result dialogs. Journey progress
and Daily streaks are stored separately from the active board.

Daily challenges are generated from a versioned UTC date key, so they work
offline and remain deterministic for every player on that date. Journey ships
with 30 local data-driven levels, including score, line, and colored-cell
objectives.

Local feedback assets live in `assets/lottie/` and `assets/audio/`. Lottie
compositions are cached/preloaded and rendered inside a `RepaintBoundary`; the
clear sounds use one short preloaded pool per line-count tier and are scheduled
without blocking a turn.

## Verification

```bash
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is emitted at `build/app/outputs/flutter-apk/app-debug.apk` after a successful build.

For a focused mode/feedback check:

```bash
flutter test test/game_modes_test.dart test/mode_cubit_test.dart \
  test/mode_widget_test.dart test/feedback_assets_test.dart
```

## Release follow-ups

- The included clear-tier audio is original synthesized placeholder feedback; replace it with approved original/royalty-free mastering if the product owner wants a different sound palette.
- Run the owner setup in [`docs/ads-and-privacy.md`](docs/ads-and-privacy.md),
  including `flutterfire configure`, Firebase Console Remote Config, AdMob
  units/App IDs, UMP messages, store privacy disclosures, Data Safety, and
  `app-ads.txt`.
- Add device integration coverage for app backgrounding, real ad lifecycle
  callbacks, consent transitions, and haptic/audio output.
- Add golden snapshots on the product's target Flutter version after final typography and device-font choices are approved.
