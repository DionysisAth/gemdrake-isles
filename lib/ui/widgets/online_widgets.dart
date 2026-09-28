import 'package:flutter/material.dart';

import '../../config/game_config.dart';
import '../../logic/game_controller.dart';
import '../../services/online_games.dart';
import '../dialogs/dialogs.dart';
import '../game_scope.dart';
import '../painters/nav_icons.dart';
import '../theme.dart';

/// This week's real festival leaderboard (Google Play Games / Game Center).
/// Hidden when the services aren't set up for this build.
class FestivalLeaderboardCard extends StatefulWidget {
  const FestivalLeaderboardCard({super.key});

  @override
  State<FestivalLeaderboardCard> createState() =>
      _FestivalLeaderboardCardState();
}

class _FestivalLeaderboardCardState extends State<FestivalLeaderboardCard> {
  Future<List<LeaderboardRow>?>? _rows;
  bool? _wasSignedIn;

  LeaderboardDef? get _board =>
      context.game.config.services.leaderboard('festival');

  void _load() {
    final board = _board;
    if (board == null) return;
    final sync = context.online;
    setState(() {
      _rows = sync.push().then((_) => sync.online.topScores(board));
    });
  }

  @override
  Widget build(BuildContext context) {
    final sync = context.online;
    final board = _board;
    if (!sync.available || board == null) return const SizedBox.shrink();
    return ValueListenableBuilder<bool>(
      valueListenable: sync.online.signedIn,
      builder: (context, signedIn, _) {
        if (signedIn && _wasSignedIn != true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _load();
          });
        }
        _wasSignedIn = signedIn;
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const NavIcon(NavIconKind.trophy, size: 28),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'Weekly leaderboard',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (signedIn)
                    IconButton(
                      tooltip: 'Refresh',
                      visualDensity: VisualDensity.compact,
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                ],
              ),
              Text(
                'Festival points against players everywhere, '
                'on ${sync.online.serviceName}.',
                style: const TextStyle(fontSize: 12, color: Palette.inkSoft),
              ),
              const SizedBox(height: 8),
              if (!signedIn)
                Center(
                  child: GameButton(
                    color: const Color(0xFF34A853),
                    onTap: () async {
                      if (!await sync.signIn() && context.mounted) {
                        showToast(context, "Couldn't sign in right now");
                      }
                    },
                    child: Text('Sign in to ${sync.online.serviceName}'),
                  ),
                )
              else
                FutureBuilder<List<LeaderboardRow>?>(
                  future: _rows,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final rows = snap.data;
                    if (rows == null || rows.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'No scores yet this week. Earn festival points to be first!',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    return Column(
                      children: [for (final r in rows) _Row(row: r)],
                    );
                  },
                ),
              if (signedIn) ...[
                const SizedBox(height: 6),
                Center(
                  child: TextButton(
                    onPressed: () => sync.online.showLeaderboard(board),
                    child: const Text('See full leaderboard'),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.row});

  final LeaderboardRow row;

  @override
  Widget build(BuildContext context) {
    final medal = switch (row.rank) {
      1 => Palette.gold,
      2 => const Color(0xFFB0BEC5),
      3 => const Color(0xFFD7995B),
      _ => null,
    };
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: row.you ? const Color(0xFFFFE9A8) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: row.you ? Border.all(color: Palette.gold, width: 2) : null,
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: medal ?? const Color(0xFFEDE5F7),
            ),
            child: Text(
              '${row.rank}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: medal != null ? Colors.white : Palette.ink,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              row.you ? '${row.name} (you)' : row.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: row.you ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const Icon(Icons.star_rounded, size: 16, color: Color(0xFFFFB300)),
          Text(
            ' ${row.score}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Settings block for Google Play Games / Game Center.
class OnlineSettings extends StatelessWidget {
  const OnlineSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.online;
    if (!sync.available) return const SizedBox.shrink();
    final online = sync.online;
    return ValueListenableBuilder<bool>(
      valueListenable: online.signedIn,
      builder: (context, signedIn, _) => Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const NavIcon(NavIconKind.trophy, size: 24),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    online.serviceName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  signedIn ? 'Signed in' : 'Signed out',
                  style: TextStyle(
                    fontSize: 12,
                    color: signedIn ? Palette.greenDark : Palette.inkSoft,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (!signedIn)
              GameButton(
                color: const Color(0xFF34A853),
                onTap: () => sync.signIn(),
                child: const Text('Sign in'),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  GameButton(
                    color: Palette.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    onTap: () => _pickLeaderboard(context),
                    child: const Text('Leaderboards'),
                  ),
                  GameButton(
                    color: const Color(0xFFE0A21A),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    onTap: online.showAchievements,
                    child: const Text('Achievements'),
                  ),
                ],
              ),
            if (sync.game.config.services.cloudSave)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Your game is also saved to your account when you leave '
                  'the app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.5, color: Palette.inkSoft),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _pickLeaderboard(BuildContext context) {
    final sync = context.online;
    showDialog(
      context: context,
      builder: (ctx) => GameDialog(
        title: 'Leaderboards',
        onClose: () => Navigator.pop(ctx),
        child: Column(
          children: [
            for (final lb in sync.game.config.services.leaderboards)
              ListTile(
                leading: const NavIcon(NavIconKind.trophy, size: 26),
                title: Text(lb.name),
                trailing: Text(
                  '${sync.game.metric(lb.metric)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  sync.online.showLeaderboard(lb);
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Offers a cloud save that is further along than this device's game.
Future<void> showCloudOffer(BuildContext context) async {
  final sync = context.online;
  final data = sync.cloudOffer.value;
  if (data == null) return;
  final cloud = sync.game.parseBackup(data);
  if (cloud == null) return;
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => GameDialog(
      title: 'Cloud save found',
      actions: [
        GameButton(
          color: Colors.grey,
          onTap: () => Navigator.pop(ctx, false),
          child: const Text('Keep this one'),
        ),
        GameButton(
          shine: true,
          onTap: () => Navigator.pop(ctx, true),
          child: const Text('Load cloud save'),
        ),
      ],
      child: Text(
        'Your ${sync.online.serviceName} account has a game at level '
        '${cloud.level} on island ${cloud.island + 1}. This device is at '
        'level ${sync.game.state.level}. Load the cloud save?',
        textAlign: TextAlign.center,
      ),
    ),
  );
  if (ok == true) {
    await sync.acceptCloud();
    if (context.mounted) showToast(context, 'Cloud save loaded!');
  } else {
    sync.declineCloud();
  }
}
