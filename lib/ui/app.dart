import 'package:flutter/material.dart';

import '../logic/game_controller.dart';
import '../services/ads_service.dart';
import '../services/online_games.dart';
import '../services/online_sync.dart';
import 'fx_layer.dart';
import 'game_scope.dart';
import 'screens/home_shell.dart';
import 'targets.dart';
import 'theme.dart';

class GemdrakeApp extends StatefulWidget {
  const GemdrakeApp({
    super.key,
    required this.game,
    required this.ads,
    this.online,
  });

  final GameController game;
  final AdsService ads;
  final OnlineSync? online;

  @override
  State<GemdrakeApp> createState() => _GemdrakeAppState();
}

class _GemdrakeAppState extends State<GemdrakeApp> {
  final _fx = FxController();
  final _targets = TargetRegistry();
  late final OnlineSync _online =
      widget.online ?? OnlineSync(widget.game, NoOnlineGames());

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gemdrake Isles',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // GameScope wraps the Navigator so dialogs can reach the game too.
      builder: (context, child) => GameScope(
        game: widget.game,
        fx: _fx,
        targets: _targets,
        ads: widget.ads,
        online: _online,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: child!,
        ),
      ),
      home: HomeShell(fx: _fx),
    );
  }
}
