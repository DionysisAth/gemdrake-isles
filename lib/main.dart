import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/game_config.dart';
import 'logic/game_controller.dart';
import 'services/ads_service.dart';
import 'services/analytics.dart';
import 'services/notification_service.dart';
import 'services/online_games.dart';
import 'services/online_sync.dart';
import 'services/remote_config.dart';
import 'services/save_store.dart';
import 'services/sound_service.dart';
import 'services/time_sync.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final GameConfig config = await RemoteConfig.load(rootBundle);
  final services = config.services;
  // A quick look at the real time; carries on in the background if slow.
  await TimeSync.sync(services.timeCheckUrl)
      .timeout(const Duration(seconds: 2), onTimeout: () {});
  final sound = SoundService();
  await sound.init();
  final NotificationService notifications = LocalNotificationService.supported
      ? LocalNotificationService()
      : NoopNotificationService();
  await notifications.init();
  final game = await GameController.load(
    config: config,
    saveStore: PrefsSaveStore(),
    feedback: sound,
    analytics: LocalAnalytics(),
    notifications: notifications,
    clock: TimeSync.now,
  );
  final OnlineGames platform = PlatformGames.enabledFor(services)
      ? PlatformGames(services)
      : NoOnlineGames();
  final online = OnlineSync(game, platform);
  final AdsService ads = AdMobAdsService.supported
      ? AdMobAdsService(config.economy)
      : SimulatedAdsService(seconds: config.economy.simulatedAdSeconds);

  runApp(GemdrakeApp(game: game, ads: ads, online: online));
  // After the first frame so the GDPR consent form can be shown.
  unawaited(ads.init());
  unawaited(online.start());
  unawaited(RemoteConfig.refresh(rootBundle, services.remoteConfigUrl));
}
