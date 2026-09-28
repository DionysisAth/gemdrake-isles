# Gemdrake Isles

A cozy **merge puzzle + idle** game for **iOS and Android**, built from one Flutter codebase.
Merge gems, plants and dragon eggs, hatch dragons that earn coins while you're away, and
restore a ruined floating island.

This repo implements the **MVP milestone** from the design doc (section 17) plus the post-launch
roadmap, except real-money purchases and real ads. Online features use only free platform
services (Google Play Games, Game Center); nothing needs a server of our own (see
[Online features](#online-features)).

## What's in the MVP

| Design doc item | Where |
|---|---|
| 7×9 merge board with locked cells (fog, cobwebs, rubble) | `lib/ui/widgets/board_area.dart`, `assets/config/board.json` |
| 3 item chains (Gems ×7, Plants ×5, Eggs ×3) + 2 generators | `assets/config/items.json`, `generators.json` |
| 2→1 merges plus the **5→3 bonus merge** (tunable) | `lib/logic/merge_logic.dart`, `economy.json` → `merge` |
| Generators with charges, cooldowns, upgrades, drop odds | `game_controller.dart`, info bar |
| Energy with time-based refill (1 every 2 min, max 100) | `economy.json` → `energy` |
| Orders from 2 characters (Pip, Sage Ember), scripted tutorial orders first | `orders.json`, `lib/logic/order_generator.dart` |
| 4 dragon types / 4 rarities, hatching, dragon merging Baby → Gemdrake | `dragons.json`, island screen |
| Island 1 (Meadow Ruins) with 10 restoration tasks that visibly change the island | `island.json`, `lib/ui/painters/island_painter.dart` |
| Idle and offline dragon earnings, 8h cap, "Welcome back" popup | `game_controller.dart` (`_accrueIdle`, `checkWelcomeBack`) |
| Storage slots (3 free, more for gems), selling items, reward gift box | board area, info bar |
| Guided tutorial (first ~5 minutes) | `tutorial.json`, `lib/ui/widgets/tutorial_overlay.dart` |
| Rewarded ads: double idle earnings, free energy, skip generator cooldown | `lib/services/ads_service.dart` |
| Local save after every action, basic analytics | `save_store.dart`, `analytics.dart` |
| Odds shown for every random reward (eggs, generators) | Chain info, generator info, Settings → Reward odds |

## Beyond the MVP

| Feature | Where |
|---|---|
| **Islands 2–5**: Ember Volcano, Coral Lagoon, Crystal Peaks, Shadow Sky, each with its own look, 10 tasks, perks and egg odds. Travel once an island is restored; browse earlier islands with the arrows | `island.json`, `island_theme.dart`, `island_painter.dart`, `controller_islands.dart` |
| **New chains and generators**: Tools (Forge), Shells (Tide Pool), Geodes (Geode Cavern), Stars (Star Well), Treasure chests (openable, with shown odds), Legendary eggs | `items.json`, `generators.json`, `extra_*_painters.dart` |
| **New dragons**: Shadow (legendary), plus festival-only Blossom and Lumen | `dragons.json` |
| **New characters**: Brann, Marina, Quartz, Umbra, who order each island's items | `orders.json` |
| **Daily tasks**: 3 per day from a pool, progress from game stats, all-done bonus that grows with the login streak | `meta.json` → `daily`, `controller_meta.dart`, Daily button in the HUD |
| **Login calendar**: 7-day gift cycle, streak counter | `meta.json` → `login` |
| **Dragon Book**: every type at every level (silhouettes until found), gem rewards for completing a type and for hatching every basic type | `dragons.json` → `collection`, `book_screen.dart` |
| **Gem shop**: chests and egg packs with their exact odds, coins, energy, bigger dragon hoard (12h/24h). Gems are earned in the game only | `meta.json` → `shop`, tap the gem counter |
| **Weekly festivals**: rotating Blossom and Lantern festivals with their own board and generator, points for merges and for offering top items, a 12-step reward track with a premium track unlocked with gems, and an exclusive dragon | `events.json`, `controller_events.dart`, `event_screen.dart` |
| **Leaderboards**: a weekly festival leaderboard against real players in the Festival tab, plus level, dragons and merges boards (Google Play Games / Game Center) | `services.json`, `online_games.dart`, `online_widgets.dart` |
| **Achievements**: 16 achievements with gem rewards (Book tab → Achievements), also unlocked on Play Games / Game Center | `services.json` → `achievements`, `controller_extras.dart` |
| **Cloud save**: saved to the player's Play Games / Game Center account when leaving the app; a newer cloud save is offered on another device | `online_sync.dart` |
| **Energy potions**: 4-level chain dropped by generators; drink for energy or merge first | `items.json` → `potion` |
| **Living island**: dragons fly laps, nap (z's) and hop about; tap one to hear it chirp or roar | `island_screen.dart` |
| **Music per island** and dragon chirps/roars | `tool/generate_audio.py`, `assets/audio/` |
| **Local reminders**: energy full, hoard full, daily gift, festival ending soon (toggle in Settings) | `notification_service.dart`, `controller_extras.dart` |
| **Sharing**: share a picture of your island, or a 9:16 card of a rare dragon from the hatch popup | share button on the island, hatch popup |
| **Backup codes**: copy or save your whole game as a code and restore it on another device | Settings → Backup & restore |

**Look and feel:** a new app icon (`tool/icon/`, rendered by `tool/icon/make_icons.py`), animated
dialogs with gem-studded frames and ribbon titles, hand-painted currency and tab icons, and merge
effects that grow with the merge: streaks, bursts, shockwaves, rays, screen shake, confetti and
words from "Nice!" to "LEGENDARY!" (`fx_layer.dart`, `board_area.dart` → `_mergeFx`).

Extras that support the design pillars: particle bursts, flying coins, squash-and-stretch pop-ins,
merge sounds that rise in pitch with level, haptics, a rarity-scaled hatch reveal (screen flash for
Epic and above), animated dragons flying around the island, task perks (+energy, +storage,
+offline hours, dragon boost), and a dragon collection row with silhouettes.

## Running it

Requires Flutter 3.47+ (Dart 3.13+).

```bash
flutter pub get
flutter run            # on a connected iOS/Android device or simulator
flutter test           # 90 logic + widget tests
flutter test test_shots  # renders screens/effects to PNGs (SHOTS=dir) for visual checks
flutter analyze
```

The app is portrait-only, lays out for phones from iPhone SE size up, and keeps a phone-width
column on tablets.

## Architecture

```
lib/
  config/game_config.dart   Typed models for everything in assets/config/*.json
  model/                    Plain serializable game state (board, pieces, orders, dragons...)
  logic/
    game_controller.dart    All game rules; ChangeNotifier + a stream of one-shot GameEvents
    controller_*.dart       Parts of the controller: islands and chests, daily/book/shop,
                            festivals, reminders, achievements and backups
    merge_logic.dart        Pure merge planning (standard + bonus rule)
    order_generator.dart    Scripted + level-scaled random orders
    new_game.dart           Builds a fresh save from board.json
  services/                 Save (SharedPreferences), sound (audioplayers), ads (AdMob + UMP),
                            local notifications, analytics
  ui/
    screens/                Home shell (tabs, popups, lifecycle), island, festival, Dragon Book
    widgets/                Board area, orders bar, info bar, HUD, tutorial overlay
    painters/               All art is procedural CustomPainter code (items, dragons, island)
    fx_layer.dart           Particles, fly-to-counter coins, floating text, flashes
assets/
  config/                   ALL economy and content data (data-driven, remote-config ready)
  audio/                    Generated SFX + music (tool/generate_audio.py)
  fonts/                    Fredoka (SIL OFL)
```

- **Data-driven:** the Dart code has no balancing numbers. Change chains, drop tables, prices, energy
  rates, dragon stats, orders, island tasks, the board layout or tutorial text in `assets/config/`.
  `GameConfig.fromJson` accepts the same maps, so a remote-config fetch can replace the bundled files.
- **Time:** energy, cooldowns and idle income are computed from timestamps, so they keep working while
  the app is closed. Timestamps never move backwards, so turning the clock back and forth grants
  nothing. For release, back `GameController.clock` with server time (see the note in the controller).
- **Saving:** state is serialized after every action (coalesced within 250 ms) and on app pause.
  Corrupt or outdated saves are repaired or replaced instead of crashing.

## Before shipping to the stores

- **Ads:** `AndroidManifest.xml`, `ios/Runner/Info.plist` and `economy.json` use Google's public
  **test** AdMob IDs. Replace them with your own. Consent (GDPR) goes through Google UMP; configure the
  consent and IDFA messages in the AdMob console. If no ad is available, a placeholder "ad" is shown
  (`fallbackToSimulated` in `economy.json`); set it to `false` for release.
- **Bundle IDs and signing:** `com.gemdrake.gemdrake_isles` / `com.gemdrake.gemdrakeIsles` are
  placeholders. Android release builds are signed with the debug key until you add a signing config.
- **Art and audio:** everything is procedural placeholder art and synthesized sound. Swap in final
  assets, or tweak the painters and `tool/generate_audio.py`.
- **Left out on purpose:** real-money purchases (IAP, VIP) and real ad units.

## Online features

Everything online is free and needs no server of our own:

| Feature | How |
|---|---|
| Leaderboards, achievements, cloud save | Google Play Games (Android) and Game Center (iOS) through `games_services` |
| Trusted time | the `Date` header of a well-known HTTPS server (`timeCheckUrl`) corrects the game clock when the device clock is off |
| Remote config | optional: host the `assets/config/*.json` files on any static host (GitHub Pages...) and set `remoteConfigUrl`; new files apply from the next launch |
| Reminders | local notifications scheduled on the phone |

**Turning on Play Games / Game Center** (they're off until the game exists in the stores):

1. **Android:** in Play Console, create the game under *Play Games Services*, add leaderboards and
   achievements, and link the app. Put the project ID in
   `android/app/src/main/res/values/strings.xml` (`game_services_project_id`), the IDs in
   `assets/config/services.json` (`android` fields), and set `playGames.enabled` to `true`.
2. **iOS:** in App Store Connect, enable Game Center for the app, create leaderboards and
   achievements, add the *Game Center* capability to the Runner target in Xcode, fill in the `ios`
   fields in `services.json` and set `gameCenter.enabled` to `true`.

Until then the leaderboard card and the Play Games settings are hidden; achievements still work
in-game.

**Not included** because they would need a server of our own: friends and gifting, visiting other
islands, and invite rewards.

## Open decisions taken for the MVP

- **Engine:** Flutter (the design doc's "good fit" option). The game is grid- and UI-heavy, and one
  codebase ships to both stores. Plain Flutter widgets and painters were enough, so there's no Flame
  dependency.
- **Merge rule:** 2 → 1 with the 5 → 3 bonus. Switch to "3 → 1" by setting `standardConsume: 3` in
  `economy.json`.
- **Backend:** none yet. Save, analytics and time sit behind interfaces ready for Firebase or PlayFab.
