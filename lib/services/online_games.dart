import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart' as gs;

import '../config/game_config.dart';

/// One row of a platform leaderboard.
class LeaderboardRow {
  LeaderboardRow(this.rank, this.name, this.score, {this.you = false});
  final int rank;
  final String name;
  final int score;
  final bool you;
}

/// Free platform game services: Google Play Games on Android, Game Center
/// on iOS. Leaderboards, achievements and cloud save, with no server of
/// our own.
abstract class OnlineGames {
  /// Configured for this platform (see `services.json`).
  bool get available;

  /// Google Play Games or Game Center.
  String get serviceName;

  ValueListenable<bool> get signedIn;
  Future<bool> signIn();
  Future<void> submitScore(LeaderboardDef board, int value);
  Future<void> unlock(AchievementDef achievement);
  Future<void> showLeaderboard(LeaderboardDef board);
  Future<void> showAchievements();
  Future<List<LeaderboardRow>?> topScores(
    LeaderboardDef board, {
    int count = 10,
  });
  Future<bool> cloudSave(String data);
  Future<String?> cloudLoad();
}

class NoOnlineGames implements OnlineGames {
  final _signedIn = ValueNotifier(false);

  @override
  bool get available => false;
  @override
  String get serviceName => '';
  @override
  ValueListenable<bool> get signedIn => _signedIn;
  @override
  Future<bool> signIn() async => false;
  @override
  Future<void> submitScore(LeaderboardDef board, int value) async {}
  @override
  Future<void> unlock(AchievementDef achievement) async {}
  @override
  Future<void> showLeaderboard(LeaderboardDef board) async {}
  @override
  Future<void> showAchievements() async {}
  @override
  Future<List<LeaderboardRow>?> topScores(
    LeaderboardDef board, {
    int count = 10,
  }) async => null;
  @override
  Future<bool> cloudSave(String data) async => false;
  @override
  Future<String?> cloudLoad() async => null;
}

class PlatformGames implements OnlineGames {
  PlatformGames(this.config);

  final ServicesConfig config;
  final _signedIn = ValueNotifier(false);
  static const _saveName = 'gemdrake-isles';

  static bool get _android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _ios =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Whether the config turns services on for this device's platform.
  static bool enabledFor(ServicesConfig c) =>
      (_android && c.playGames) || (_ios && c.gameCenter);

  @override
  bool get available => enabledFor(config);

  @override
  String get serviceName => _ios ? 'Game Center' : 'Google Play Games';

  @override
  ValueListenable<bool> get signedIn => _signedIn;

  bool _hasId(String android, String ios) =>
      (_android && android.isNotEmpty) || (_ios && ios.isNotEmpty);

  @override
  Future<bool> signIn() async {
    if (!available) return false;
    try {
      await gs.GamesServices.signIn();
      _signedIn.value = await gs.GamesServices.isSignedIn;
    } catch (e) {
      debugPrint('Game services sign-in failed: $e');
      _signedIn.value = false;
    }
    return _signedIn.value;
  }

  Future<T?> _guard<T>(Future<T> Function() f) async {
    if (!available || !_signedIn.value) return null;
    try {
      return await f();
    } catch (e) {
      debugPrint('Game services call failed: $e');
      return null;
    }
  }

  @override
  Future<void> submitScore(LeaderboardDef board, int value) async {
    if (!_hasId(board.androidId, board.iosId)) return;
    await _guard(
      () => gs.GamesServices.submitScore(
        score: gs.Score(
          androidLeaderboardID: board.androidId,
          iOSLeaderboardID: board.iosId,
          value: value,
        ),
      ),
    );
  }

  @override
  Future<void> unlock(AchievementDef a) async {
    if (!_hasId(a.androidId, a.iosId)) return;
    await _guard(
      () => gs.GamesServices.unlock(
        achievement: gs.Achievement(androidID: a.androidId, iOSID: a.iosId),
      ),
    );
  }

  @override
  Future<void> showLeaderboard(LeaderboardDef board) async {
    await _guard(
      () => gs.GamesServices.showLeaderboards(
        androidLeaderboardID: board.androidId,
        iOSLeaderboardID: board.iosId,
        timeScope: board.weekly ? gs.TimeScope.week : gs.TimeScope.allTime,
      ),
    );
  }

  @override
  Future<void> showAchievements() async {
    await _guard(gs.GamesServices.showAchievements);
  }

  @override
  Future<List<LeaderboardRow>?> topScores(
    LeaderboardDef board, {
    int count = 10,
  }) async {
    if (!_hasId(board.androidId, board.iosId)) return null;
    final me = await _guard(gs.GamesServices.getPlayerID);
    final rows = await _guard(
      () => gs.GamesServices.loadLeaderboardScores(
        androidLeaderboardID: board.androidId,
        iOSLeaderboardID: board.iosId,
        scope: gs.PlayerScope.global,
        timeScope: board.weekly ? gs.TimeScope.week : gs.TimeScope.allTime,
        maxResults: count,
      ),
    );
    if (rows == null) return null;
    return [
      for (final r in rows)
        LeaderboardRow(
          r.rank,
          r.scoreHolder.displayName,
          r.rawScore,
          you: me != null && r.scoreHolder.playerID == me,
        ),
    ];
  }

  @override
  Future<bool> cloudSave(String data) async {
    if (!config.cloudSave || !available || !_signedIn.value) return false;
    try {
      await gs.GamesServices.saveGame(data: data, name: _saveName);
      return true;
    } catch (e) {
      debugPrint('Cloud save failed: $e');
      return false;
    }
  }

  @override
  Future<String?> cloudLoad() async {
    if (!config.cloudSave) return null;
    return _guard<String?>(() => gs.GamesServices.loadGame(name: _saveName));
  }
}
