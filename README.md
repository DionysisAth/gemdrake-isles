# Gemdrake Isles

A cozy **merge puzzle + idle** game for **iOS and Android**, built from one Flutter codebase.
Merge gems, plants and dragon eggs, hatch dragons that earn coins while you're away, and
restore a ruined floating island.

This repo implements the **MVP milestone** from the design doc (section 17).

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

Extras that support the design pillars: particle bursts, flying coins, squash-and-stretch pop-ins,
merge sounds that rise in pitch with level, haptics, a rarity-scaled hatch reveal (screen flash for
Epic and above), animated dragons flying around the island, task perks (+energy, +storage,
+offline hours, dragon boost), and a dragon collection row with silhouettes.

## Running it

Requires Flutter 3.47+ (Dart 3.13+).

```bash
flutter pub get
flutter run            # on a connected iOS/Android device or simulator
flutter test           # 39 logic + widget tests
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
    merge_logic.dart        Pure merge planning (standard + bonus rule)
    order_generator.dart    Scripted + level-scaled random orders
    new_game.dart           Builds a fresh save from board.json
  services/                 Save (SharedPreferences), sound (audioplayers), ads (AdMob + UMP), analytics
  ui/
    screens/                Home shell (tabs, popups, lifecycle), island screen
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
- **Not in the MVP (per the design doc):** gems/IAP, chests, live events, islands 2–5, a full dragon
  book, leaderboards, friends, push notifications, cloud save, VIP.

## Open decisions taken for the MVP

- **Engine:** Flutter (the design doc's "good fit" option). The game is grid- and UI-heavy, and one
  codebase ships to both stores. Plain Flutter widgets and painters were enough, so there's no Flame
  dependency.
- **Merge rule:** 2 → 1 with the 5 → 3 bonus. Switch to "3 → 1" by setting `standardConsume: 3` in
  `economy.json`.
- **Backend:** none yet. Save, analytics and time sit behind interfaces ready for Firebase or PlayFab.
