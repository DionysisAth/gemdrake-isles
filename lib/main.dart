import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'config/game_config.dart';
import 'logic/game_controller.dart';
import 'services/ads_service.dart';
import 'services/analytics.dart';
import 'services/notification_service.dart';
import 'services/save_store.dart';
import 'services/sound_service.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final config = await GameConfig.load(rootBundle);
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
  );
  final AdsService ads = AdMobAdsService.supported
      ? AdMobAdsService(config.economy)
      : SimulatedAdsService(seconds: config.economy.simulatedAdSeconds);

  runApp(GemdrakeApp(game: game, ads: ads));
  // After the first frame so the GDPR consent form can be shown.
  unawaited(ads.init());
}
