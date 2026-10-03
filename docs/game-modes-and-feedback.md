# Game modes and feedback

## Player flow

`Blockora` shows a short splash, then `ModeSelectionScreen` with one option:
**Classic**, the endless board with the existing continue/revive flow.

Journey and Daily Challenge data remains readable for save compatibility, but
those modes are no longer exposed by the product UI.

The active run is stored as schema 2 `SavedGame` data. Mode progress has its
own storage record, so showing a result can clear the resumable board without
clearing Journey unlocks or Daily history. Schema 1 saves migrate to Classic;
piece IDs continue to use the current canonical piece definitions.

## Determinism and clock handling

`dailyChallengeFor(DateTime)` normalizes the input to UTC and hashes
`configurationVersion:yyyy-mm-dd`. No network request is needed to generate a
Daily board. `DailyProgress.recordCompletion` refuses a date older than the
last observed date, preventing a simple clock-back change from repeatedly
awarding a streak. This is intentionally best-effort client-only protection;
server verification would be needed for a competitive leaderboard.

## Combo animation

`ComboAssets.forCombo` maps combo 2, 3, 4, 5, and 6+ to the five local Lottie
files in `assets/lottie/`. `ComboLottieCache` loads each file once with
background loading. `ComboOverlay` is centered over the board, wrapped in a
`RepaintBoundary`, ignores pointer input, plays once, and removes itself after
the composition/fallback duration. Reduced-motion mode uses a lightweight
text scale/fade fallback. A second or later consecutive line-clear turn shows
the overlay; a no-clear turn cannot leave an overlay behind.

## Clear audio

`clear_1.m4a`, `clear_2.m4a`, and `clear_3.m4a` are short local synthesized
tones. `tierForCompletedLines` maps all completed rows and columns from one
placement to exactly one tier: one line, two lines, or three-plus lines. The
Cubit's drop path schedules the tier once and never awaits audio before
updating the board. `LocalGameAudioService` preloads two-player pools and
silently degrades if a platform audio backend is unavailable. The user sound
preference gates playback; ad ducking lowers the volume for newly-started
effects while a rewarded ad is active.

## Manual smoke checklist

1. Run `flutter run` on an Android or iOS device/simulator.
2. Wait for the splash, then open Classic.
3. Make consecutive line clears. Confirm combo 2/3/4/5/6+ shows
   the appropriate centered feedback and then disappears.
4. Use the debug-only Feedback tools in a debug build to force one, two, or
   three-line clears. Confirm only one clear sound tier is played per drop.
5. Background the app during a run, relaunch it, and use Resume. Confirm the
   board, pieces, mode, score, and mode metrics restore.
6. Drag shapes against all board edges. Confirm the ghost and final board use
   the exact current piece cells and no retired fifth cell.
