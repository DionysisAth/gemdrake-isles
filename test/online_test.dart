import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gemdrake_isles/config/game_config.dart';
import 'package:gemdrake_isles/logic/game_controller.dart';
import 'package:gemdrake_isles/model/game_state.dart';
import 'package:gemdrake_isles/model/item_ref.dart';
import 'package:gemdrake_isles/services/online_games.dart';
import 'package:gemdrake_isles/services/online_sync.dart';
import 'package:gemdrake_isles/services/time_sync.dart';

import 'helpers.dart';

class FakeOnline implements OnlineGames {
  final scores = <String, int>{};
  final unlocked = <String>{};
  String? cloud;
  final _signedIn = ValueNotifier(false);

  @override
  bool get available => true;
  @override
  String get serviceName => 'Test Games';
  @override
  ValueListenable<bool> get signedIn => _signedIn;
  @override
  Future<bool> signIn() async => _signedIn.value = true;
  @override
  Future<void> submitScore(LeaderboardDef board, int value) async =>
      scores[board.key] = value;
  @override
  Future<void> unlock(AchievementDef a) async => unlocked.add(a.id);
  @override
  Future<void> showLeaderboard(LeaderboardDef board) async {}
  @override
  Future<void> showAchievements() async {}
  @override
  Future<List<LeaderboardRow>?> topScores(
    LeaderboardDef board, {
    int count = 10,
  }) async => [LeaderboardRow(1, 'You', scores[board.key] ?? 0, you: true)];
  @override
  Future<bool> cloudSave(String data) async {
    cloud = data;
    return true;
  }

  @override
  Future<String?> cloudLoad() async => cloud;
}

void main() {
  group('achievements', () {
    test('progress follows stats and pays gems once', () {
      final g = newController();
      final a = g.config.services.achievements.firstWhere(
        (a) => a.id == 'merge_100',
      );
      expect(g.achievementDone(a), isFalse);
      expect(g.claimAchievement(a.id), isFalse);
      g.state.addStat('merges', 100);
      expect(g.achievementProgress(a), 100);
      expect(g.achievementBadge, greaterThanOrEqualTo(1));
      final gems = g.state.gems;
      expect(g.claimAchievement(a.id), isTrue);
      expect(g.state.gems, gems + a.gems);
      expect(g.claimAchievement(a.id), isFalse);
      expect(GameState.fromJson(g.state.toJson()).achievements, {a.id});
    });

    test('derived metrics', () {
      final g = newController();
      g.state.island = 1;
      g.state.dragons.add(Dragon(id: 900, type: 'fire', level: 4));
      expect(g.metric('island'), 2);
      expect(g.metric('maxDragonLevel'), 4);
      expect(g.metric('level'), g.state.level);
    });

    test('finishing the festival track counts as a completed festival', () {
      final g = newController();
      g.state.level = g.config.events.unlockLevel;
      g.tick();
      g.setEventMode(true);
      final chain = g.config.chain(g.scheduledEvent.chain);
      final last = g.config.events.milestones.last.points;
      g.state.event!.points = last - 1;
      final i = g.board.index(2, 4);
      g.board.cells[i] = Piece.item(
        g.state.newId(),
        ItemRef(chain.id, chain.maxLevel),
      );
      g.offer(Slot.board(i));
      expect(g.metric('festivalsCompleted'), 1);
    });
  });

  group('platform game services', () {
    test('sync submits leaderboards and unlocks achievements', () async {
      final g = newController();
      final online = FakeOnline();
      final sync = OnlineSync(g, online);
      g.state.addStat('merges', 150);
      g.state.addStat('hatches');
      await sync.start();
      expect(online.scores['merges'], 150);
      expect(online.scores['level'], g.state.level);
      expect(online.unlocked, containsAll(['merge_100', 'first_hatch']));
      expect(online.unlocked, isNot(contains('merge_1000')));
      sync.dispose();
    });

    test('a cloud save further along is offered and can be loaded', () async {
      final ahead = newController();
      ahead.state.level = 12;
      final online = FakeOnline()..cloud = ahead.exportBackup();
      final g = newController();
      final sync = OnlineSync(g, online);
      await sync.start();
      expect(sync.cloudOffer.value, isNotNull);
      await sync.acceptCloud();
      expect(g.state.level, 12);
      sync.dispose();
    });

    test('an older cloud save is not offered; pausing uploads', () async {
      final behind = newController();
      final online = FakeOnline()..cloud = behind.exportBackup();
      final g = newController();
      g.state.level = 9;
      final sync = OnlineSync(g, online);
      await sync.start();
      expect(sync.cloudOffer.value, isNull);
      await sync.onPause();
      expect(g.parseBackup(online.cloud!)!.level, 9);
      sync.dispose();
    });

    test('services are off unless configured', () {
      final c = loadConfig();
      expect(PlatformGames.enabledFor(c.services), isFalse);
      expect(NoOnlineGames().available, isFalse);
    });
  });

  test('HTTP dates parse for the time check', () {
    expect(
      TimeSync.parseHttpDate('Sun, 28 Sep 2026 17:45:12 GMT'),
      DateTime.utc(2026, 9, 28, 17, 45, 12),
    );
    expect(TimeSync.parseHttpDate('garbage'), isNull);
  });
}
