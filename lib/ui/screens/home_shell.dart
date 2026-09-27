import 'dart:async';

import 'package:flutter/material.dart';

import '../../logic/game_controller.dart';
import '../../logic/game_events.dart';
import '../dialogs/dialogs.dart';
import '../dialogs/meta_dialogs.dart';
import '../fx_layer.dart';
import '../game_scope.dart';
import '../painters/sky_painter.dart';
import '../theme.dart';
import '../widgets/board_area.dart';
import '../widgets/event_bar.dart';
import '../widgets/orders_bar.dart';
import '../widgets/top_bar.dart';
import '../widgets/tutorial_overlay.dart';
import 'book_screen.dart';
import 'event_screen.dart';
import 'island_screen.dart';

/// Top-level screen: HUD, the Board and Island tabs, popups, the per-second
/// clock and app lifecycle (pause/resume, welcome back).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.fx});

  final FxController fx;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  Timer? _clock;
  StreamSubscription<GameEvent>? _sub;
  final _popups = <Future<void> Function()>[];
  bool _showingPopup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _onForeground(initial: true),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub ??= context.game.events.listen(_onEvent);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final game = context.game;
    switch (state) {
      case AppLifecycleState.resumed:
        _onForeground();
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _clock?.cancel();
        _clock = null;
        game.onPause();
      case AppLifecycleState.inactive:
        break;
    }
  }

  void _onForeground({bool initial = false}) {
    if (!mounted) return;
    final game = context.game;
    final wb = game.checkWelcomeBack();
    _clock?.cancel();
    game.tick();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => game.tick());
    game.feedback.startMusic();
    if (wb != null && !game.tutorialActive) {
      _queue(() => showWelcomeBack(context, wb));
    }
    if (game.state.leagueResult != null) {
      _queue(() => showLeagueResult(context));
    }
    if (game.loginRewardReady) _queue(() => showDaily(context));
    if (game.shouldAskReminders) _queue(game.askReminders);
  }

  void _queue(Future<void> Function() popup) {
    _popups.add(popup);
    _drain();
  }

  Future<void> _drain() async {
    if (_showingPopup) return;
    _showingPopup = true;
    while (_popups.isNotEmpty && mounted) {
      final next = _popups.removeAt(0);
      // Let effects (bursts, flying coins) play first.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) break;
      await next();
    }
    _showingPopup = false;
  }

  void _onEvent(GameEvent e) {
    if (!mounted) return;
    switch (e) {
      case LevelUpEvent(:final level, :final gems, :final unlocks):
        _queue(() => showLevelUp(context, level, gems, unlocks));
      case HatchEvent(:final dragons):
        _queue(() => showHatch(context, dragons));
      case DragonMergedEvent(:final dragon):
        _queue(() => showHatch(context, [dragon], grown: true));
      case TaskCompletedEvent(:final task, :final islandComplete):
        if (task.perk != null || islandComplete) {
          _queue(() => showTaskComplete(context, task, islandComplete));
        }
      case OutOfEnergyEvent():
        if (!_showingPopup) _queue(() => showOutOfEnergy(context));
      case ChestOpenedEvent(:final title, :final rewards):
        _queue(() => showChestRewards(context, title, rewards));
      case IslandTravelEvent(:final island, :final unlocks):
        _queue(() => showIslandArrival(context, island, unlocks));
      case ToastEvent(:final message):
        showToast(context, message);
      default:
        break;
    }
  }

  void _setTab(int i) {
    if (_tab == i) return;
    setState(() => _tab = i);
    context.game.select(null);
    if (i <= 1) {
      context.game.tutorialEvent(i == 1 ? 'tab_island' : 'tab_board');
    }
  }

  void _playFestival() {
    context.game.setEventMode(true);
    _setTab(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(
            child: RepaintBoundary(child: CustomPaint(painter: SkyPainter())),
          ),
          SafeArea(
            child: Center(
              // Keep a phone-like column on tablets.
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  children: [
                    const TopBar(),
                    Expanded(
                      child: Stack(
                        children: [
                          _TabPage(
                            active: _tab == 0,
                            child: Column(
                              children: [
                                ListenableBuilder(
                                  listenable: context.game,
                                  builder: (context, _) {
                                    final game = context.game;
                                    return Column(
                                      children: [
                                        // ignore: prefer_const_constructors
                                        BoardModeSwitch(),
                                        if (game.eventMode)
                                          EventBar(
                                            onOpenTrack: () => _setTab(2),
                                          )
                                        else
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6,
                                            ),
                                            child: OrdersBar(),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 4),
                                const Expanded(child: BoardArea()),
                              ],
                            ),
                          ),
                          _TabPage(
                            active: _tab == 1,
                            child: const IslandScreen(),
                          ),
                          _TabPage(
                            active: _tab == 2,
                            child: EventScreen(onPlay: _playFestival),
                          ),
                          _TabPage(
                            active: _tab == 3,
                            child: const BookScreen(),
                          ),
                        ],
                      ),
                    ),
                    _BottomNav(tab: _tab, onTab: _setTab),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(child: FxLayer(controller: widget.fx)),
          Positioned.fill(child: TutorialOverlay(tab: _tab)),
        ],
      ),
    );
  }
}

class _TabPage extends StatelessWidget {
  const _TabPage({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Offstage(
      offstage: !active,
      child: TickerMode(enabled: active, child: child),
    ),
  );
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.tab, required this.onTab});

  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final targets = context.targets;
    return ListenableBuilder(
      listenable: Listenable.merge([game, game.clockTick]),
      builder: (context, _) {
        final readyOrders = game.state.orders
            .where((o) => game.findOrderItems(o) != null)
            .length;
        final affordable = game.currentIsland.tasks
            .where((t) => game.taskAvailable(t) && game.state.coins >= t.cost)
            .length;
        final islandBadge = affordable + (game.idleFull ? 1 : 0);
        final eventLocked = !game.eventUnlocked;
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Container(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: .8),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _NavButton(
                    key: targets.keyFor('tab:board'),
                    icon: Icons.grid_view_rounded,
                    label: 'Board',
                    active: tab == 0,
                    badge: readyOrders,
                    onTap: () => onTab(0),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _NavButton(
                    key: targets.keyFor('tab:island'),
                    icon: Icons.landscape_rounded,
                    label: 'Island',
                    active: tab == 1,
                    badge: islandBadge,
                    onTap: () => onTab(1),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _NavButton(
                    icon: eventLocked
                        ? Icons.lock_rounded
                        : Icons.celebration_rounded,
                    label: 'Festival',
                    active: tab == 2,
                    badge: game.eventBadge,
                    onTap: () => onTab(2),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _NavButton(
                    icon: Icons.menu_book_rounded,
                    label: 'Book',
                    active: tab == 3,
                    badge: game.bookBadge,
                    onTap: () => onTab(3),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.badge,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GameButton(
          color: active ? Palette.accent : const Color(0xFFB9A6DA),
          padding: const EdgeInsets.symmetric(vertical: 5),
          onTap: onTap,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: double.infinity),
              Icon(icon, size: 22),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 13.5, height: 1.1),
                ),
              ),
            ],
          ),
        ),
        if (badge > 0)
          Positioned(
            right: -4,
            top: -6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: Palette.danger,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                '$badge',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
