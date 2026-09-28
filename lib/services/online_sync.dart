import 'dart:async';

import 'package:flutter/foundation.dart';

import '../logic/game_controller.dart';
import '../model/game_state.dart';
import 'online_games.dart';

/// Keeps the platform game services in step with the game: submits
/// leaderboard values, unlocks achievements and stores a cloud save.
class OnlineSync {
  OnlineSync(this.game, this.online);

  final GameController game;
  final OnlineGames online;

  /// A cloud save that is further along than this device's game.
  final cloudOffer = ValueNotifier<String?>(null);

  final _submitted = <String, int>{};
  final _unlocked = <String>{};
  Timer? _debounce;
  bool _started = false;

  bool get available => online.available;

  Future<void> start() async {
    if (!online.available || _started) return;
    _started = true;
    game.addListener(_changed);
    if (await online.signIn()) await _afterSignIn();
  }

  Future<bool> signIn() async {
    final ok = await online.signIn();
    if (ok) await _afterSignIn();
    return ok;
  }

  Future<void> _afterSignIn() async {
    await _checkCloud();
    await push();
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 4), push);
  }

  /// Sends changed leaderboard values and newly earned achievements.
  Future<void> push() async {
    if (!online.signedIn.value) return;
    final services = game.config.services;
    for (final lb in services.leaderboards) {
      final v = game.metric(lb.metric);
      if (v <= 0 || _submitted[lb.key] == v) continue;
      _submitted[lb.key] = v;
      await online.submitScore(lb, v);
    }
    for (final a in services.achievements) {
      if (_unlocked.contains(a.id) || !game.achievementDone(a)) continue;
      _unlocked.add(a.id);
      await online.unlock(a);
    }
  }

  /// How far along a game is, to pick the newer of two saves.
  static int progress(GameState s) =>
      s.level * 100000000 + s.completedTasks.length * 100000 + s.stat('merges');

  Future<void> _checkCloud() async {
    final data = await online.cloudLoad();
    if (data == null || data.isEmpty) return;
    final cloud = game.parseBackup(data);
    if (cloud == null) return;
    if (progress(cloud) > progress(game.state)) cloudOffer.value = data;
  }

  Future<void> acceptCloud() async {
    final data = cloudOffer.value;
    cloudOffer.value = null;
    if (data != null) await game.importBackup(data);
  }

  void declineCloud() => cloudOffer.value = null;

  /// Call when the app goes to the background.
  Future<void> onPause() async {
    if (!online.signedIn.value) return;
    await push();
    await online.cloudSave(game.exportBackup());
  }

  void dispose() {
    _debounce?.cancel();
    if (_started) game.removeListener(_changed);
  }
}
