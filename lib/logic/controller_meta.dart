part of 'game_controller.dart';

/// A Dragon Book reward: finishing every level of a type, or hatching one
/// of each basic type.
class BookGoal {
  BookGoal(this.key, this.title, this.gems, this.done, this.claimed);
  final String key;
  final String title;
  final int gems;
  final bool done;
  final bool claimed;
  bool get claimable => done && !claimed;
}

/// Daily tasks, login calendar, Dragon Book and the gem shop.
extension MetaSystems on GameController {
  // ---------------------------------------------------------------------
  // Calendar
  // ---------------------------------------------------------------------

  static int dayNumberOf(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  /// Local calendar day as a number. Never goes backwards, so turning the
  /// device clock back can't re-roll daily rewards.
  int get today => max(
    dayNumberOf(clock()),
    max(state.loginDay, max(state.dailyDay, state.loginClaimedDay)),
  );

  /// Monday-based week number (day 0, 1 Jan 1970, was a Thursday).
  int get weekNumber => (today + 3) ~/ 7;

  /// Local midnight when the next day starts.
  DateTime get nextDayStart {
    final d = clock();
    return DateTime(d.year, d.month, d.day + 1);
  }

  /// Rolls new daily tasks and counts the login streak on a new day, and
  /// rotates the weekly event. Returns true when anything changed.
  bool refreshDay() {
    final day = today;
    var changed = false;
    if (state.loginDay != day) {
      state.loginStreak = state.loginDay == day - 1 ? state.loginStreak + 1 : 1;
      state.loginDay = day;
      changed = true;
    }
    if (state.dailyDay != day && dailyUnlocked) {
      _rollDailyTasks(day);
      changed = true;
    }
    if (refreshEvent()) changed = true;
    return changed;
  }

  // ---------------------------------------------------------------------
  // Daily tasks
  // ---------------------------------------------------------------------

  bool get dailyUnlocked =>
      state.level >= config.meta.dailyUnlockLevel && !tutorialActive;

  void _rollDailyTasks(int day) {
    final meta = config.meta;
    final pool = [
      for (final d in meta.dailyPool)
        if (state.level >= d.minLevel) d,
    ]..shuffle(random);
    final tier = state.level ~/ 5;
    state.dailyTasks = [
      for (final d in pool.take(meta.dailyCount))
        DailyTask(
          d.id,
          d.targets[min(tier, d.targets.length - 1)],
          state.stat(d.stat),
        ),
    ];
    state.dailyDay = day;
    state.dailyBonusClaimed = false;
  }

  DailyTaskDef dailyDef(DailyTask t) => config.meta.daily(t.id);

  int dailyProgress(DailyTask t) =>
      (state.stat(dailyDef(t).stat) - t.base).clamp(0, t.target);

  bool dailyDone(DailyTask t) => dailyProgress(t) >= t.target;

  bool claimDaily(int index) {
    if (index < 0 || index >= state.dailyTasks.length) return false;
    final t = state.dailyTasks[index];
    if (t.claimed || !dailyDone(t)) return false;
    t.claimed = true;
    grantLoot([dailyDef(t).reward]);
    state.addStat('dailyClaimed');
    feedback.play(Sfx.collect);
    analytics.log('daily_claim', {'task': t.id});
    _commit();
    return true;
  }

  bool get dailyBonusReady =>
      state.dailyTasks.isNotEmpty &&
      state.dailyTasks.every((t) => t.claimed) &&
      !state.dailyBonusClaimed;

  /// Extra gems for finishing every daily task, growing with the streak.
  int get streakBonusGems {
    final table = config.meta.streakBonusGems;
    if (table.isEmpty) return 0;
    return table[(max(1, state.loginStreak) - 1).clamp(0, table.length - 1)];
  }

  List<LootEntry> get dailyBonusRewards => [
    config.meta.dailyAllDone,
    if (streakBonusGems > 0) LootEntry(weight: 1, gems: streakBonusGems),
  ];

  bool claimDailyBonus() {
    if (!dailyBonusReady) return false;
    state.dailyBonusClaimed = true;
    final rewards = dailyBonusRewards;
    grantLoot(rewards);
    feedback.play(Sfx.levelUp);
    feedback.haptic(heavy: true);
    analytics.log('daily_bonus', {'streak': state.loginStreak});
    _emit(ChestOpenedEvent('Daily bonus', rewards));
    _commit();
    return true;
  }

  /// Things waiting in the Daily panel (for the badge).
  int get dailyBadge =>
      (loginRewardReady ? 1 : 0) +
      state.dailyTasks.where((t) => !t.claimed && dailyDone(t)).length +
      (dailyBonusReady ? 1 : 0);

  // ---------------------------------------------------------------------
  // Login calendar
  // ---------------------------------------------------------------------

  /// 0-based position in the 7-day calendar for today.
  int get loginCalendarDay =>
      (max(1, state.loginStreak) - 1) % config.meta.login.length;

  LootEntry get loginReward => config.meta.login[loginCalendarDay];

  bool get loginRewardReady =>
      !tutorialActive && state.loginClaimedDay != today;

  bool claimLogin() {
    if (!loginRewardReady) return false;
    state.loginClaimedDay = today;
    grantLoot([loginReward]);
    feedback.play(Sfx.collect);
    analytics.log('login_claim', {'streak': state.loginStreak});
    _commit();
    return true;
  }

  // ---------------------------------------------------------------------
  // Dragon Book
  // ---------------------------------------------------------------------

  bool dragonSeen(String type, int level) =>
      state.discovered.contains('dragon:$type:$level');

  List<BookGoal> get bookGoals {
    final dc = config.dragons;
    return [
      if (dc.allBabiesGems > 0)
        BookGoal(
          'babies',
          'Hatch one of each: '
              '${dc.allBabiesTypes.map((t) => config.dragonType(t).name).join(', ')}',
          dc.allBabiesGems,
          dc.allBabiesTypes.every((t) => dragonSeen(t, 1)),
          state.bookClaimed.contains('babies'),
        ),
      for (final t in dc.types)
        BookGoal(
          'type:${t.id}',
          'Raise ${t.name} dragons to every level',
          dc.typeCompleteGems[t.rarity] ?? 0,
          [for (var l = 1; l <= dc.maxLevel; l++) l]
              .every((l) => dragonSeen(t.id, l)),
          state.bookClaimed.contains('type:${t.id}'),
        ),
    ];
  }

  int get bookBadge => bookGoals.where((g) => g.claimable).length;

  int get bookDiscovered => [
    for (final t in config.dragons.types)
      for (var l = 1; l <= config.dragons.maxLevel; l++)
        if (dragonSeen(t.id, l)) 1,
  ].length;

  int get bookTotal => config.dragons.types.length * config.dragons.maxLevel;

  bool claimBook(String key) {
    final goal = bookGoals.where((g) => g.key == key).firstOrNull;
    if (goal == null || !goal.claimable) return false;
    state.bookClaimed.add(key);
    state.gems += goal.gems;
    feedback.play(Sfx.levelUp);
    feedback.haptic(heavy: true);
    analytics.log('book_claim', {'goal': key});
    _commit();
    return true;
  }

  // ---------------------------------------------------------------------
  // Gem shop
  // ---------------------------------------------------------------------

  bool shopItemAvailable(ShopItemDef item) =>
      item.unlockIsland <= state.island + 1;

  bool buyShopItem(String id) {
    final item = config.meta.shopItems.where((s) => s.id == id).firstOrNull;
    if (item == null || !shopItemAvailable(item)) return false;
    if (state.gems < item.costGems) return false;
    state.gems -= item.costGems;
    final rewards = rollLoot(item.loot);
    grantLoot(rewards);
    state.addStat('shopBuys');
    feedback.play(Sfx.collect);
    feedback.haptic(heavy: true);
    analytics.log('gem_spend', {'on': 'shop:$id', 'gems': item.costGems});
    _emit(ChestOpenedEvent(item.name, rewards));
    _commit();
    return true;
  }

  /// Gem price of the next extra board row, or null when maxed.
  int? get nextBoardRowCost {
    final costs = config.meta.boardRowCosts;
    return state.extraRows < costs.length ? costs[state.extraRows] : null;
  }

  /// Adds an empty row at the bottom of the main board.
  bool buyBoardRow() {
    final cost = nextBoardRowCost;
    if (cost == null || state.gems < cost) return false;
    state.gems -= cost;
    final old = state.board;
    final grown = Board(old.cols, old.rows + 1);
    for (var i = 0; i < old.size; i++) {
      grown.cells[i] = old.cells[i];
      grown.locks[i] = old.locks[i];
    }
    state.board = grown;
    state.extraRows += 1;
    feedback.play(Sfx.unlock);
    feedback.haptic(heavy: true);
    analytics.log('gem_spend', {'on': 'board_row', 'gems': cost});
    _commit();
    return true;
  }

  HoardUpgradeDef? get nextHoardUpgrade {
    final ups = config.meta.hoardUpgrades;
    return state.hoardLevel < ups.length ? ups[state.hoardLevel] : null;
  }

  bool buyHoardUpgrade() {
    final up = nextHoardUpgrade;
    if (up == null || state.gems < up.costGems) return false;
    _accrueIdle(nowMs); // bank earnings under the old cap first
    state.gems -= up.costGems;
    state.hoardLevel += 1;
    feedback.play(Sfx.restore);
    analytics.log('gem_spend', {'on': 'hoard', 'gems': up.costGems});
    _commit();
    return true;
  }
}
