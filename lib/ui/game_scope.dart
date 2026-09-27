import 'package:flutter/widgets.dart';

import '../logic/game_controller.dart';
import '../services/ads_service.dart';
import 'fx_layer.dart';
import 'targets.dart';

/// Makes the game controller and UI services available to widgets.
/// Widgets listen to [game] themselves (ListenableBuilder) for fine-grained
/// rebuilds.
class GameScope extends InheritedWidget {
  const GameScope({
    super.key,
    required this.game,
    required this.fx,
    required this.targets,
    required this.ads,
    required super.child,
  });

  final GameController game;
  final FxController fx;
  final TargetRegistry targets;
  final AdsService ads;

  static GameScope of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<GameScope>()!;

  @override
  bool updateShouldNotify(GameScope old) => false;
}

extension GameContext on BuildContext {
  GameController get game => GameScope.of(this).game;
  FxController get fx => GameScope.of(this).fx;
  TargetRegistry get targets => GameScope.of(this).targets;
  AdsService get ads => GameScope.of(this).ads;
}
