# Firebase Analytics implementation notes

This branch adds Firebase Analytics and gameplay/AdMob lifecycle telemetry. No ad config flags or placement frequency are modified.

## Events

- `game_start`: game_mode
- `piece_placed`: game_mode, piece_cells, points, score, move_number, lines
- `line_clear`: game_mode, lines, points, combo, score
- `combo_reached`: game_mode, combo, score
- `revive_offered`, `rewarded_revive_requested`, `revive_success`: game_mode, score, best_score, moves, lines_cleared, combo, revive_count
- `rewarded_revive_failed`: game_mode, reason
- `game_end`: game_mode, score, best_score, moves, lines_cleared, combo, revive_count, outcome, duration_seconds
- `ad_loaded`, `ad_load_failed`, `ad_shown`, `ad_impression`, `rewarded_ad_earned`: ad_format (and ad_platform on ad_impression)

Firebase Analytics automatically collects some lifecycle events such as `first_open`, `session_start` and user engagement when correctly configured. D1/D7 retention should be computed from cohort reports instead of sending fabricated retention events.

## Before merge / publishing

1. Run `flutter pub get`, `flutter analyze` and `flutter test`. This pull request was edited via GitHub API and cannot claim local Flutter validation.
2. Confirm Firebase platform configuration for both Android (`google-services.json` with Google Services Gradle plugin) and iOS (`GoogleService-Info.plist`, configured Firebase bundle/app). The Android JSON is not tracked in this repository.
3. Confirm Analytics consent/privacy disclosures on Google Play and App Store, and Apple ATT if applicable. Do not log advertising IDs or personal information as custom parameters.
4. Validate Analytics DebugView on an isolated QA device, then verify release telemetry. Debug builds intentionally disable analytics collection in this integration; use a profile/release QA build or adjust the QA strategy before running DebugView.
5. Link AdMob with Firebase and verify monetization revenue; `ad_impression` here has **no actual paid value**, so it is not a substitute for impression-level ad revenue. A future task is to implement AdMob paid event (`onPaidEvent`) with revenue value/currency and correct aggregation, or confirm linked AdMob automatic revenue reporting.
6. Add onboarding funnel, game exits/abandonment, store acquisition attribution, and session-resume telemetry after the core events are validated.
7. Test new game/restart, failure/continue, successful revive, unavailable rewarded ad, and full-screen ad callbacks to rule out duplicate events.

**Important:** the Analytics observer detects run starts on game state transitions. Restored in-progress games, explicit abandonment and some first-run flows need follow-up testing and instrumentation.