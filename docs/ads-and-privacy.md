# Ads, Firebase, and privacy setup

The repository contains the supplied native Firebase configuration for the
Blockora project, using `com.rachaddev.colorBlock` on both platforms. The
owner's live AdMob identifiers and Remote Config values are still separate;
until those are published and consent permits requests, the app uses safe
defaults and shows no ads.

## Owner setup

1. Confirm the supplied Firebase project has the Android package
   `com.rachaddev.colorBlock` and iOS bundle identifier
   `com.rachaddev.colorBlock` registered. The native files are already at
   `android/app/google-services.json` and
   `ios/Runner/GoogleService-Info.plist`.
2. FlutterFire CLI is optional for this Android/iOS setup because the app uses
   those native files. If you need generated Dart options or additional
   platforms, install/use the CLI and run:

   ```bash
   flutterfire configure --platforms=android,ios
   ```

   If the command generates `firebase_options.dart`, pass
   `DefaultFirebaseOptions.currentPlatform` to the initializer callback used
   by `AdvertisingBootstrap`, for example:

   ```dart
   AdvertisingBootstrap(
     ads: ads,
     consent: consent,
     initializeFirebase: () async {
       await Firebase.initializeApp(
         options: DefaultFirebaseOptions.currentPlatform,
       );
     },
   );
   ```

   Native platform configuration can also be used where supported. Commit only
   the generated project configuration that belongs to the owner; do not add
   service-account keys or other secrets.
3. In AdMob, create Android and iOS apps and units for banner, interstitial,
   and rewarded formats. Replace the sample App IDs in
   `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`.
4. In Firebase Remote Config, publish the parameters below. Keep
   `ads_enabled=false` until the AdMob apps, consent messages, privacy policy,
   and store disclosures are ready.
5. In AdMob Privacy & messaging, configure the applicable GDPR/EEA, UK, Swiss,
   and US state messages. Decide the audience classification with the product
   owner/legal reviewer before setting an under-age tag; the code deliberately
   does not guess that value.
6. Complete the Google Play Data Safety form, Apple privacy disclosures,
   privacy-policy URL, and `app-ads.txt` for the publisher domain.

## Remote Config parameters

| Key | Type | Safe default | Purpose |
| --- | --- | --- | --- |
| `ads_enabled` | bool | `false` | Master kill switch |
| `banner_enabled` | bool | `false` | Enable banner format |
| `interstitial_enabled` | bool | `false` | Enable natural-break interstitials |
| `rewarded_enabled` | bool | `false` | Enable rewarded format |
| `banner_android_ad_unit_id` / `banner_ios_ad_unit_id` | string | empty | Platform banner units |
| `interstitial_android_ad_unit_id` / `interstitial_ios_ad_unit_id` | string | empty | Platform interstitial units |
| `rewarded_android_ad_unit_id` / `rewarded_ios_ad_unit_id` | string | empty | Platform rewarded units |
| `banner_show_on_gameplay` | bool | `true` | Fixed banner at the bottom of gameplay |
| `banner_show_on_home` | bool | `true` | Dedicated home area |
| `banner_show_on_results` | bool | `true` | Dedicated results area |
| `interstitial_every_n_completed_games` | int | `3` | Frequency gate; first game is never shown |
| `interstitial_min_interval_seconds` | int | `120` | Cooldown shared with rewarded ads |
| `interstitial_max_per_session` | int | `3` | Session cap |
| `rewarded_revive_enabled` | bool | `true` | Enable the one-second-chance feature |
| `rewarded_revive_max_per_game` | int | `1` | Maximum revives in a run |
| `rewarded_revive_countdown_seconds` | int | `5` | Continue prompt duration |
| `rewarded_revive_strategy` | string | `clear_most_filled_line` | Or `remove_last_placed_piece` |
| `ads_personalization_enabled` | bool | `false` | Use personalized requests only after policy approval |

Ad unit strings are accepted only when they match the AdMob unit-ID format.
Debug and profile builds always select Google's official test units, even when
Remote Config contains a production unit ID. Production release builds select
only the validated platform ID from Remote Config.

## Runtime behavior

- `AdvertisingBootstrap` starts consent and Remote Config without delaying the
  first game frame. Firebase/network failures fall back to cached/default
  values.
- UMP consent information is requested on each app launch. The SDK is only
  initialized and ad requests are only made when `canRequestAds()` allows it.
  The Settings sheet exposes privacy choices when UMP requires them.
- Rewarded ads are user-initiated. The revive is granted only by Google's
  `onUserEarnedReward` callback, once. A dismissal, load error, or show error
  leaves the board unchanged.
- Revives default to clearing the most-filled line. The alternate strategy
  removes cells carrying the last placement ID; legacy boards without IDs use
  the deterministic line/fallback policy. The result always scans until at
  least one displayed piece can move when a move is possible.
- Interstitials run only after a results screen, every third completed game by
  default, after a 120-second cooldown, with a three-per-session cap. They are
  never shown on the first game or immediately after a rewarded ad.
- Banners use a compact standard 320x50 unit and are anchored at the bottom of
  gameplay/results areas. Gameplay placement is enabled by default once the
  banner format is enabled, and failed banners collapse without changing the
  board layout.

## Verification and diagnostics

Use the Google Mobile Ads Ad Inspector on a development device, and use test
devices/test units only during development. Verify consent transitions,
background/foreground behavior, no-network startup, ad dismissal, and reward
callbacks on Android and iOS before publishing.
