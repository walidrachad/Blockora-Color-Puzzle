# Player experience analytics — Blockora

This branch extends the existing Firebase Analytics integration on `develop`.

## Questions and events
- **Do players understand how to start?** `home_play_tapped` (new_run), `tutorial_started`, `tutorial_completed`.
- **Where do they struggle?** `invalid_placement` (reason, game_mode, move_number), `placement_difficulty` (future aggregated signal), existing `piece_placed`, `line_clear`, `combo_reached`.
- **Do they enjoy improving?** `score_milestone` (milestone, game_mode), existing `game_end` (score, duration_seconds, invalid_moves placeholder, outcome).
- **Do they retry?** `play_again` (replay_number, game_mode); `game_screen_exited` (status, score, moves, screen_seconds).
- **Do they accept rewarded revive?** `revive_declined` (game_mode, score); existing `revive_offered`, `rewarded_revive_requested`, `revive_success`, `rewarded_revive_failed`.
- **Ad experience:** existing `ad_loaded`, `ad_load_failed`, `ad_impression`, `ad_shown`, `rewarded_ad_earned`.

## Important interpretations
- **Enjoyment cannot be measured directly:** replay rate, play duration, combo/clear rate and return cohorts are proxies. Optional in-game ratings/feedback need careful, non-intrusive UX and consent.
- **D1/D7/D30 retention** are calculated from Firebase first_open cohorts, not manually emitted retention events.
- **Uninstall** cannot reliably be known from a client event. Avoid interpreting silent inactivity as definite uninstall.
- **Ad LTV** requires monetization revenue measurement and validated linking to AdMob, not just `ad_impression` counts.
- Analytics event volume matters. Consider aggregating invalid placement counts per run rather than sending one event per miss when scaling.
- `invalid_moves` in `game_end` requires follow-up to wire the observer aggregator to invalid placement callbacks; do not rely on it until tested.
- Check `play_again` and early exits on restored sessions, launch and replay; a session can end via navigation or process death without a final gameplay event.
- Don't collect player names, personal data, contact details, or ad IDs as event parameters. Review Firebase privacy/consent settings.

## QA
Run `flutter pub get`, `flutter analyze`, `flutter test`, test fresh install/tutorial, invalid drags, restart, replay, new best, revive decline and early exit on Android and iOS. Confirm event names and params in Firebase DebugView using a test-enabled build (debug analytics is disabled in the existing wrapper).

**Not verified by a Flutter compiler** — this branch was authored through GitHub tools.
