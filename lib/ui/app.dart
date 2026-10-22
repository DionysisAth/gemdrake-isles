import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/strings.dart';
import '../logic/game_controller.dart';
import '../services/ads_service.dart';
import '../services/online_games.dart';
import '../services/online_sync.dart';
import '../services/purchase_service.dart';
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
    this.store,
  });

  final GameController game;
  final AdsService ads;
  final OnlineSync? online;
  final PurchaseService? store;

  @override
  State<GemdrakeApp> createState() => _GemdrakeAppState();
}

class _GemdrakeAppState extends State<GemdrakeApp> with WidgetsBindingObserver {
  final _fx = FxController();
  final _targets = TargetRegistry();
  late final OnlineSync _online =
      widget.online ?? OnlineSync(widget.game, NoOnlineGames());
  late final PurchaseService _store = widget.store ?? NoPurchaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The phone's language changed while the game was open.
  @override
  void didChangeLocales(List<Locale>? locales) {
    if (widget.game.state.settings.language == null) {
      L10n.use(L10n.systemLanguage(locales));
    }
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: L10n.current,
    builder: (context, code, _) => _app(code),
  );

  Widget _app(String code) {
    return MaterialApp(
      // A new language rebuilds every screen.
      key: ValueKey(code),
      title: 'Gemdrake Isles',
      locale: Locale(code),
      supportedLocales: [for (final c in languages.keys) Locale(c)],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // GameScope wraps the Navigator so dialogs can reach the game too.
      builder: (context, child) => GameScope(
        game: widget.game,
        fx: _fx,
        targets: _targets,
        ads: widget.ads,
        online: _online,
        store: _store,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.2,
          child: child!,
        ),
      ),
      home: HomeShell(fx: _fx),
    );
  }
}
