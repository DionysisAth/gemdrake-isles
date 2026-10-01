# Gemdrake Isles

A cozy **merge puzzle + idle** game for **iOS and Android**, built from one Flutter codebase.
Merge gems, plants and dragon eggs, hatch dragons that earn coins while you're away, and
restore a ruined floating island.

This repo implements the **MVP milestone** from the design doc (section 17) plus the post-launch
roadmap, including in-app purchases and rewarded ads. Online features use only free platform
services (Google Play Games, Game Center); nothing needs a server of our own (see
[Online features](#online-features)). To go live, follow [Going live](#going-live).

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
| **In-app purchases**: Starter Pack (once), gem packs, Energy and Dragon bundles, a Festival Pass for the premium track, and the **Dragon Club** monthly subscription (daily gems, +max energy, +hoard hours). Products and what they give are data in `store.json`; prices come from the stores | `store.json`, `purchase_service.dart`, `controller_purchases.dart`, `store_widgets.dart` |
| **Free Chest** for a rewarded video (once a day), **species eggs** (Fire, Crystal, Shadow) and a **bigger board** (+1 row, twice) for gems | `economy.json` → `ads.freeChest`, `meta.json` → `shop` |

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
flutter test           # 100 logic + widget tests
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
                            in-app purchases, local notifications, analytics
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

## Going live

### 1. Ads (AdMob)

1. In [AdMob](https://admob.google.com), add the app twice (Android and iOS) and create one
   **Rewarded** ad unit for each.
2. Put the four IDs into the game with one command:
   ```bash
   python3 tool/set_admob_ids.py \
       --android-app ca-app-pub-XXXXXXXXXXXXXXXX~AAAAAAAAAA \
       --android-rewarded ca-app-pub-XXXXXXXXXXXXXXXX/BBBBBBBBBB \
       --ios-app ca-app-pub-XXXXXXXXXXXXXXXX~CCCCCCCCCC \
       --ios-rewarded ca-app-pub-XXXXXXXXXXXXXXXX/DDDDDDDDDD
   ```
   It updates `AndroidManifest.xml`, `Info.plist`, `economy.json` and writes `docs/app-ads.txt`.
   With real IDs the placeholder "ad" is never shown; if no video loads, the player is told to
   try again later and nothing is used up.
3. In AdMob → *Privacy & messaging*, create a **GDPR** message and an **IDFA explainer** (iOS
   App Tracking Transparency). The game shows them through Google UMP and offers
   *Settings → Privacy options*.
4. **app-ads.txt:** AdMob checks it on the developer website listed in the stores. With GitHub
   Pages, it must be at the root of a user site, i.e. a repo named `<you>.github.io` with
   `app-ads.txt` in it; that site's address is then your store "website".

### 2. In-app purchases

Create these products in **Google Play Console** (*Monetize → Products*) and **App Store
Connect** (*In-App Purchases* / *Subscriptions*), with the **same IDs**:

| ID | Type | Suggested price |
|---|---|---|
| `starter_pack` | consumable | $2.99 |
| `gems_80`, `gems_450`, `gems_1000`, `gems_2200`, `gems_6000` | consumable | $0.99, $4.99, $9.99, $19.99, $49.99 |
| `energy_400` | consumable | $1.99 |
| `dragon_bundle` | consumable | $7.99 |
| `festival_pass` | consumable | $4.99 |
| `vip_monthly` | auto-renewing subscription, 1 month | $4.99 |

On Google Play this is one command (prices come from each product's `priceHint` in
`store.json`, converted by Google for every country; run it again after changing them):
```bash
python3 tool/play/setup_store.py --key play-key.json --products
```

Products that aren't set up (or a store that can't be reached, as in sideloaded test builds)
are simply hidden. What each product gives is in `assets/config/store.json`.

How payments are handled (`purchase_service.dart`): the reward is saved before the store is
told the purchase is done, every transaction id is remembered so nothing is given twice, and
purchases that finished while the game was closed are delivered on the next launch. The
Dragon Club lasts 31 days from each payment and is re-confirmed from Google Play at launch
(on iOS, renewals arrive as new transactions; *Restore purchases* recovers it on a new
phone). There is **no receipt-checking server**; add one (e.g. a Firebase function) if fraud
becomes a problem.

Test purchases: in Play Console add license testers; on iOS use a Sandbox account.

### 3. App identity, signing and store builds

- **Package name:** `com.gemdrake.gemdrake_isles` (Android) / `com.gemdrake.gemdrakeIsles`
  (iOS). Change them before the first upload if you want different ones; they can't be
  changed afterwards.
- **Android signing:** create an upload key once:
  ```bash
  keytool -genkey -v -keystore upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
  ```
  Then add GitHub secrets `ANDROID_KEYSTORE_BASE64` (`base64 -w0 upload.jks`),
  `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` (`upload`) and, if different,
  `ANDROID_KEY_PASSWORD`. CI then signs the APK and the **`.aab`** (the file to upload to
  Play Console) with it. Locally, put the same values in `android/key.properties`
  (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`; never committed). Keep the keystore
  safe: it can't be replaced. Without the secrets, builds are signed with the debug key and
  are for testing only. Note: a phone with a debug-signed build must uninstall it before
  installing a signed one (use a backup code first to keep progress).
- **iOS:** needs an Apple Developer account ($99/year), then signing in Xcode or a CI signing
  setup; the CI build is unsigned.

### 4. Store listings

- **Listing text** is in `tool/play/listing/en-US/`. **Screenshots, feature graphic, icon and a
  15-second 9:16 promo video** (TikTok, Reels, Shorts) are made from the game itself:
  ```bash
  SHOTS=build/promo flutter test test_shots/promo_test.dart
  python3 tool/promo/make_promo.py build/promo build/store   # pip install pillow imageio-ffmpeg
  ```
- **Uploading to Play Console:** with a service account that has access to the app
  (Play Console → *Users and permissions*):
  ```bash
  python3 tool/play/upload.py --key play-key.json --listing --graphics build/store
  python3 tool/play/upload.py --key play-key.json --bundle app.aab --track internal
  ```
  Releases are created as drafts; roll them out in Play Console. Add the key's JSON as the
  GitHub secret `PLAY_SERVICE_ACCOUNT_JSON` and CI uploads every signed build from `main`
  to the internal testing track by itself.

- **Privacy policy and website:** `docs/` is a small GitHub Pages site (home page and
  privacy policy). Turn on GitHub Pages once (*Settings → Pages → Deploy from a branch → main,
  folder /docs*); the site is then at `https://dionysisath.github.io/gemdrake-isles/` and the
  policy at `https://dionysisath.github.io/gemdrake-isles/privacy-policy.html`.
- **Play Console Data safety:** the answers are in `tool/play/data_safety.csv`: through AdMob
  the game collects and shares approximate location, device or other IDs, app interactions,
  crash logs and diagnostics (advertising, analytics, fraud prevention). No account, no
  personal data of our own. Upload with
  `python3 tool/play/setup_store.py --key play-key.json --data-safety tool/play/data_safety.csv`.
- **Contact details** (email and website on the store page):
  `python3 tool/play/setup_store.py --key play-key.json --email you@example.com --website https://...`
- **Content rating:** simulated gambling: no; random rewards with shown odds; in-app purchases:
  yes; ads: yes.
- **Art and audio:** everything is procedural and synthesized; swap in final assets if you like.

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
