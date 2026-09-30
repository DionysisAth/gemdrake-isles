import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../logic/game_controller.dart';
import '../../model/item_ref.dart';
import '../dialogs/dialogs.dart';
import '../dialogs/meta_dialogs.dart';
import '../dialogs/store_widgets.dart';
import '../game_scope.dart';
import '../painters/board_painters.dart';
import '../theme.dart';
import '../widgets/online_widgets.dart';
import '../widgets/piece_view.dart';

/// The weekly festival: its reward track (free and premium) and the
/// weekly leaderboard.
class EventScreen extends StatelessWidget {
  const EventScreen({super.key, required this.onPlay});

  /// Opens the festival board.
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    return ListenableBuilder(
      listenable: Listenable.merge([game, game.clockTick]),
      builder: (context, _) {
        if (!game.eventUnlocked || game.state.event == null) {
          return _Locked(level: game.config.events.unlockLevel);
        }
        final def = game.currentEventDef!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
          children: [
            _EventHeader(def: def, onPlay: onPlay),
            const SizedBox(height: 10),
            _RewardTrack(def: def),
            const SizedBox(height: 10),
            const FestivalLeaderboardCard(),
          ],
        );
      },
    );
  }
}

class _Locked extends StatelessWidget {
  const _Locked({required this.level});

  final int level;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(20),
        decoration: panelDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.celebration_rounded,
              size: 56,
              color: Palette.pink,
            ),
            const SizedBox(height: 8),
            Text(
              'Festivals unlock at level $level',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            const Text(
              'Each week a new festival comes to the isles, with its own board, '
              'rewards and an exclusive dragon.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EventHeader extends StatelessWidget {
  const _EventHeader({required this.def, required this.onPlay});

  final EventDef def;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final e = game.state.event!;
    final chain = game.config.chain(def.chain);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            def.colors.last,
            Color.lerp(def.colors.first, Colors.white, .3)!,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40301E4F),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              DragonIcon(
                type: game.config.dragonType(def.dragon),
                level: 1,
                size: 64,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedText(
                      def.name,
                      size: 22,
                      stroke: Color.lerp(def.colors.first, Colors.black, .5)!,
                    ),
                    Text(def.desc, style: const TextStyle(fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.timer_rounded, size: 18, color: Palette.ink),
              Text(
                ' Ends in ${formatDuration(game.eventTimeLeft)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              const Icon(Icons.star_rounded, color: Color(0xFFFFB300)),
              Text(
                ' ${e.points} pts',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var l = 1; l <= chain.maxLevel; l++)
                Expanded(
                  child: Column(
                    children: [
                      ItemIcon(ItemRef(chain.id, l), size: 34),
                      Text(
                        l == chain.maxLevel
                            ? 'offer +${game.config.events.offerPoints}'
                            : l == 1
                            ? 'tap tree'
                            : '+${game.config.events.pointsForMerge(l)}',
                        style: const TextStyle(fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          GameButton(
            shine: true,
            color: Palette.pink,
            onTap: onPlay,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow_rounded),
                Text('Play festival board', style: TextStyle(fontSize: 17)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardTrack extends StatelessWidget {
  const _RewardTrack({required this.def});

  final EventDef def;

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final e = game.state.event!;
    final ev = game.config.events;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      decoration: panelDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 62),
              const Expanded(
                child: Center(
                  child: Text(
                    'Free',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: e.premium
                      ? const Text(
                          'Premium',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: Color(0xFFB8860B),
                          ),
                        )
                      : Column(
                          children: [
                            GameButton(
                              color: const Color(0xFFE0A21A),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              onTap: () async {
                                if (await confirmGems(
                                      context,
                                      ev.premiumCostGems,
                                      'Unlock the premium track',
                                    ) &&
                                    context.mounted) {
                                  game.unlockPremium();
                                }
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.lock_open_rounded, size: 16),
                                  Text(
                                    ' Premium ${ev.premiumCostGems} ',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const CurrencyIcon(
                                    CurrencyKind.gem,
                                    size: 15,
                                  ),
                                ],
                              ),
                            ),
                            const FestivalPassButton(),
                          ],
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < ev.milestones.length; i++)
            _MilestoneRow(index: i, premium: e.premium),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.index, required this.premium});

  final int index;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final m = game.config.events.milestones[index];
    final reached = game.milestoneReached(index);
    final prev = index == 0
        ? 0
        : game.config.events.milestones[index - 1].points;
    final pts = game.state.event!.points;
    final fill = ((pts - prev) / (m.points - prev)).clamp(0.0, 1.0);
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          SizedBox(
            width: 62,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Progress rail
                Positioned(
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 8,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE5F7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: Alignment.topCenter,
                    child: FractionallySizedBox(
                      heightFactor: fill,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: reached ? const Color(0xFFFFB300) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: reached ? Colors.white : const Color(0xFFD9CCE8),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    '${m.points}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: reached ? Colors.white : Palette.inkSoft,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _TrackReward(index: index, premium: false)),
          Expanded(child: _TrackReward(index: index, premium: true)),
        ],
      ),
    );
  }
}

class _TrackReward extends StatelessWidget {
  const _TrackReward({required this.index, required this.premium});

  final int index;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final game = context.game;
    final e = game.state.event!;
    final reward = game.milestoneReward(index, premium: premium);
    final claimed = (premium ? e.claimedPremium : e.claimedFree).contains(
      index,
    );
    final claimable = game.milestoneClaimable(index, premium: premium);
    final locked = premium && !e.premium;
    return GestureDetector(
      onTap: claimable
          ? () => game.claimMilestone(index, premium: premium)
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          color: claimable
              ? const Color(0xFFFFF1C1)
              : premium
              ? const Color(0xFFFFF8E1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: claimable ? Palette.gold : const Color(0xFFEDE3D6),
            width: claimable ? 2.5 : 1.5,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final r in splitReward(reward))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: RewardTile(
                      reward: r,
                      size: 30,
                      dim: claimed || locked,
                    ),
                  ),
              ],
            ),
            if (claimed)
              const Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  Icons.check_circle_rounded,
                  color: Palette.green,
                  size: 18,
                ),
              ),
            if (locked)
              const Positioned(
                right: 4,
                top: 4,
                child: Icon(
                  Icons.lock_rounded,
                  color: Palette.inkSoft,
                  size: 16,
                ),
              ),
            if (claimable)
              Positioned(
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: Palette.green,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Claim',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
