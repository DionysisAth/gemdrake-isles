part of 'game_controller.dart';

/// Local reminders, achievements, leaderboard values and backup codes.
extension Extras on GameController {
  // ---------------------------------------------------------------------
  // Achievements and leaderboard values
  // ---------------------------------------------------------------------

  /// A number the game tracks: a stats counter or a derived value.
  int metric(String name) => switch (name) {
    'level' => state.level,
    'island' => state.island + 1,
    'streak' => state.loginStreak,
    'maxDragonLevel' => state.dragons.fold(0, (m, d) => max(m, d.level)),
    'bookDiscovered' => bookDiscovered,
    'dragons' => state.dragons.length,
    'eventPoints' => state.event?.points ?? 0,
    _ => state.stat(name),
  };

  int achievementProgress(AchievementDef a) => min(metric(a.metric), a.target);

  bool achievementDone(AchievementDef a) => metric(a.metric) >= a.target;

  bool achievementClaimable(AchievementDef a) =>
      achievementDone(a) && !state.achievements.contains(a.id);

  int get achievementBadge =>
      config.services.achievements.where(achievementClaimable).length;

  bool claimAchievement(String id) {
    final a = config.services.achievements.where((a) => a.id == id).firstOrNull;
    if (a == null || !achievementClaimable(a)) return false;
    state.achievements.add(a.id);
    state.gems += a.gems;
    feedback.play(Sfx.levelUp);
    feedback.haptic(heavy: true);
    analytics.log('achievement', {'id': id});
    _commit();
    return true;
  }

  // ---------------------------------------------------------------------
  // Reminders
  // ---------------------------------------------------------------------

  /// Notifications to schedule while the game is closed.
  List<Reminder> get reminders {
    if (!state.notifications || tutorialActive) return const [];
    final now = clock();
    final list = <Reminder>[];
    final full = fullEnergyIn;
    if (full != null && full > const Duration(minutes: 15)) {
      list.add(
        Reminder(
          1,
          now.add(full),
          'Energy is full!',
          'Your generators are ready. Come back and merge!',
        ),
      );
    }
    _accrueIdle(nowMs);
    final cpm = coinsPerMinute;
    final missing = idleCoinCap - state.idleCoins;
    if (cpm > 0 && missing > 0) {
      final minutes = missing / cpm;
      if (minutes > 30) {
        list.add(
          Reminder(
            2,
            now.add(Duration(seconds: (minutes * 60).round())),
            'The dragon hoard is full',
            'Your dragons collected ${formatCoins(idleCoinCap)} coins. '
                'Collect them before they stop earning!',
          ),
        );
      }
    }
    final tomorrow = nextDayStart;
    list.add(
      Reminder(
        3,
        DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 10),
        'A new day on the isles',
        'Your daily gift and new daily tasks are waiting.',
      ),
    );
    final e = state.event;
    if (e != null) {
      final end = weekEnd.subtract(const Duration(hours: 20));
      if (end.isAfter(now.add(const Duration(hours: 1)))) {
        list.add(
          Reminder(
            4,
            end,
            '${ev.event(e.id).name} ends soon',
            'Claim your festival rewards before tomorrow!',
          ),
        );
      }
    }
    return list;
  }

  /// Turns reminders on or off (asking the OS for permission when on).
  Future<void> setReminders(bool on) async {
    state.notifications = on;
    _commit();
    if (on) await notifications.requestPermission();
  }

  /// Ask for notification permission once the player is settled in.
  bool get shouldAskReminders =>
      state.notifications &&
      !tutorialActive &&
      state.level >= 3 &&
      state.stat('notifAsked') == 0;

  Future<void> askReminders() async {
    state.addStat('notifAsked');
    _commit();
    await notifications.requestPermission();
  }

  static String formatCoins(double c) =>
      c >= 10000 ? '${(c / 1000).toStringAsFixed(1)}K' : c.floor().toString();

  // ---------------------------------------------------------------------
  // Backup codes
  // ---------------------------------------------------------------------

  static const _backupPrefix = 'GDI1';

  static int _fnv1a(String s) {
    var h = 0x811c9dc5;
    for (final c in utf8.encode(s)) {
      h ^= c;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  /// The whole save as a text code the player can keep somewhere safe
  /// (there is no cloud save).
  String exportBackup() {
    final json = jsonEncode(state.toJson());
    final body = base64Url.encode(utf8.encode(json));
    final sum = _fnv1a(json).toRadixString(16).padLeft(8, '0');
    return '$_backupPrefix.$body.$sum';
  }

  /// Parses a backup code; null when it's damaged or not a backup.
  GameState? parseBackup(String code) {
    try {
      final parts = code.replaceAll(RegExp(r'\s'), '').split('.');
      if (parts.length != 3 || parts[0] != _backupPrefix) return null;
      final json = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final sum = _fnv1a(json).toRadixString(16).padLeft(8, '0');
      if (sum != parts[2].toLowerCase()) return null;
      return GameState.fromJson(jsonDecode(json) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Replaces the current game with the one in [code].
  Future<bool> importBackup(String code) async {
    final restored = parseBackup(code);
    if (restored == null) return false;
    restored.settings = state.settings;
    state = restored;
    _eventMode = false;
    _selected = null;
    _repair();
    _refillOrders();
    refreshDay();
    analytics.log('backup_restore', {'level': state.level});
    await save(immediate: true);
    _notify();
    return true;
  }
}
