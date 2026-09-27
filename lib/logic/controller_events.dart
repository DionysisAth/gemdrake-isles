part of 'game_controller.dart';

/// One row of the practice league table.
class LeagueEntry {
  LeagueEntry(this.name, this.score, {this.you = false});
  final String name;
  final int score;
  final bool you;
}

class _Rival {
  _Rival(this.name, this.finalScore, this.curve);
  final String name;
  final int finalScore;
  final double curve;

  int scoreAt(double f) => (finalScore * pow(f.clamp(0.0, 1.0), curve)).round();
}

/// Weekly festival events (event board, reward track with a premium track
/// unlocked by gems) and the practice league against simulated rivals.
extension FestivalEvents on GameController {
  EventsConfig get ev => config.events;

  bool get eventUnlocked => state.level >= ev.unlockLevel && !tutorialActive;

  /// The festival scheduled for this week.
  EventDef get scheduledEvent => ev.events[weekNumber % ev.events.length];

  EventDef? get currentEventDef {
    final e = state.event;
    return e == null ? null : ev.event(e.id);
  }

  /// Local Monday midnight when this week (and its event) started / ends.
  DateTime get weekStart {
    final d = clock();
    return DateTime(d.year, d.month, d.day - (d.weekday - 1));
  }

  DateTime get weekEnd {
    final s = weekStart;
    return DateTime(s.year, s.month, s.day + 7);
  }

  Duration get eventTimeLeft {
    final left = weekEnd.difference(clock());
    return left.isNegative ? Duration.zero : left;
  }

  /// How far through the week we are (0..1).
  double get weekFraction {
    final s = weekStart.millisecondsSinceEpoch;
    final e = weekEnd.millisecondsSinceEpoch;
    return ((nowMs - s) / (e - s)).clamp(0.0, 1.0);
  }

  /// Ends last week's event (paying out anything reached) and starts this
  /// week's once events are unlocked. Returns true when anything changed.
  bool refreshEvent() {
    var changed = false;
    final e = state.event;
    if (e != null && e.week != weekNumber) {
      _finishEvent(e);
      changed = true;
    }
    if (state.event == null && eventUnlocked) {
      state.event = _newEvent(scheduledEvent, weekNumber);
      changed = true;
    }
    return changed;
  }

  EventState _newEvent(EventDef def, int week) {
    final bc = config.board;
    final b = Board(bc.cols, bc.rows);
    for (var y = 0; y < bc.rows && y < ev.boardLocks.length; y++) {
      final row = ev.boardLocks[y];
      for (var x = 0; x < bc.cols && x < row.length; x++) {
        final lt = bc.lockForSymbol(row[x]);
        if (lt != null) b.locks[b.index(x, y)] = CellLock(lt.id, lt.hits);
      }
    }
    final gen = config.generator(def.generator);
    b.cells[b.index(ev.generatorCell.x, ev.generatorCell.y)] = Piece.generator(
      state.newId(),
      gen.id,
      charges: gen.level(1).charges,
    );
    analytics.log('event_start', {'event': def.id, 'week': week});
    return EventState(id: def.id, week: week, board: b);
  }

  void _finishEvent(EventState e) {
    if (_eventMode) {
      _eventMode = false;
      _selected = null;
    }
    // Rewards the player reached but forgot to claim are sent anyway.
    final def = ev.event(e.id);
    final missed = <LootEntry>[];
    for (var i = 0; i < ev.milestones.length; i++) {
      final m = ev.milestones[i];
      if (e.points < m.points) break;
      if (!e.claimedFree.contains(i)) missed.add(_resolve(m.free, def));
      if (e.premium && !e.claimedPremium.contains(i)) {
        missed.add(_resolve(m.premium, def));
      }
    }
    grantLoot(missed);
    if (e.points > 0) {
      // Pay out a result the player never looked at before replacing it.
      claimLeagueResult();
      final standings = leagueStandingsFor(
        e.week,
        state.leagueTier,
        e.points,
        1,
      );
      final rank = standings.indexWhere((s) => s.you) + 1;
      final lc = ev.league;
      final before = state.leagueTier;
      var after = before;
      if (rank <= lc.promote) after = min(before + 1, lc.tiers.length - 1);
      if (rank > lc.size - lc.demote) after = max(before - 1, 0);
      state.leagueTier = after;
      state.leagueResult = LeagueResult(
        week: e.week,
        rank: rank,
        gems: lc.gemsForRank(rank),
        tierBefore: before,
        tierAfter: after,
      );
    }
    analytics.log('event_end', {'event': e.id, 'points': e.points});
    state.event = null;
  }

  LootEntry _resolve(LootEntry r, EventDef def) =>
      r.dragon == 'event' ? r.withDragon(def.dragon) : r;

  // ---------------------------------------------------------------------
  // Event board
  // ---------------------------------------------------------------------

  bool get eventMode => _eventMode && state.event != null;

  void setEventMode(bool on) {
    if (on) refreshEvent();
    final next = on && state.event != null;
    if (next == _eventMode) return;
    _eventMode = next;
    _selected = null;
    _notify();
  }

  /// Points for making [out] on the event board (bonus merges count each).
  void _eventMergePoints(ItemRef out, int count, int cell) {
    final e = state.event;
    if (!eventMode || e == null) return;
    final pts = ev.pointsForMerge(out.level) * count;
    if (pts > 0) _addEventPoints(pts, cell);
  }

  void _addEventPoints(int pts, int? cell) {
    final e = state.event!;
    final before = e.points;
    e.points += pts;
    state.addStat('eventPoints', pts);
    final reached = [
      for (final m in ev.milestones)
        if (m.points > before && m.points <= e.points) m,
    ];
    _emit(EventPointsEvent(pts, cell, milestone: reached.isNotEmpty));
  }

  /// Whether the item in [s] can be offered for event points.
  bool canOffer(Slot s) {
    if (!eventMode || s.storage) return false;
    final ref = pieceAt(s)?.item;
    if (ref == null || board.isLocked(s.index)) return false;
    final chain = config.chain(ref.chain);
    return chain.event && ref.level == chain.maxLevel;
  }

  bool offer(Slot s) {
    if (!canOffer(s)) return false;
    _setPiece(s, null);
    if (_selected == s) _selected = null;
    feedback.play(Sfx.order);
    feedback.haptic(heavy: true);
    _addEventPoints(ev.offerPoints, s.index);
    state.addStat('offerings');
    _commit();
    return true;
  }

  // ---------------------------------------------------------------------
  // Reward track
  // ---------------------------------------------------------------------

  bool milestoneReached(int i) =>
      state.event != null && state.event!.points >= ev.milestones[i].points;

  bool milestoneClaimable(int i, {bool premium = false}) {
    final e = state.event;
    if (e == null || !milestoneReached(i)) return false;
    if (premium) return e.premium && !e.claimedPremium.contains(i);
    return !e.claimedFree.contains(i);
  }

  LootEntry milestoneReward(int i, {bool premium = false}) {
    final m = ev.milestones[i];
    final def = currentEventDef ?? scheduledEvent;
    return _resolve(premium ? m.premium : m.free, def);
  }

  bool claimMilestone(int i, {bool premium = false}) {
    if (!milestoneClaimable(i, premium: premium)) return false;
    final e = state.event!;
    (premium ? e.claimedPremium : e.claimedFree).add(i);
    final r = milestoneReward(i, premium: premium);
    grantLoot([r]);
    feedback.play(r.dragon != null ? Sfx.hatch : Sfx.collect);
    feedback.haptic(heavy: r.dragon != null);
    analytics.log('event_claim', {'i': i, 'premium': premium});
    if (r.dragon != null) {
      final d = state.dragons.last;
      _emit(HatchEvent([d], null));
    }
    _commit();
    return true;
  }

  int get eventBadge {
    final e = state.event;
    if (e == null) return 0;
    var n = 0;
    for (var i = 0; i < ev.milestones.length; i++) {
      if (milestoneClaimable(i)) n++;
      if (milestoneClaimable(i, premium: true)) n++;
    }
    return n + (state.leagueResult != null ? 1 : 0);
  }

  bool unlockPremium() {
    final e = state.event;
    if (e == null || e.premium || state.gems < ev.premiumCostGems) {
      return false;
    }
    state.gems -= ev.premiumCostGems;
    e.premium = true;
    feedback.play(Sfx.levelUp);
    analytics.log('gem_spend', {'on': 'premium', 'gems': ev.premiumCostGems});
    _commit();
    return true;
  }

  // ---------------------------------------------------------------------
  // Practice league (simulated rivals)
  // ---------------------------------------------------------------------

  List<_Rival> _rivals(int week, int tier) {
    final lc = ev.league;
    final r = Random(week * 7919 + tier * 104729 + 13);
    final names = [...lc.names]..shuffle(r);
    final base = lc.tiers[tier.clamp(0, lc.tiers.length - 1)].rivalScore;
    return [
      for (var i = 0; i < lc.rivals; i++)
        _Rival(
          names[i % names.length],
          (base * (0.3 + r.nextDouble() * 1.4)).round(),
          0.7 + r.nextDouble() * 0.8,
        ),
    ];
  }

  /// League table for [week] at [tier] with the player on [points], with
  /// rivals' scores as they are [fraction] of the way through the week.
  List<LeagueEntry> leagueStandingsFor(
    int week,
    int tier,
    int points,
    double fraction,
  ) {
    final list = [
      for (final r in _rivals(week, tier))
        LeagueEntry(r.name, r.scoreAt(fraction)),
      LeagueEntry('You', points, you: true),
    ];
    // Ties go to the player.
    list.sort((a, b) {
      final c = b.score.compareTo(a.score);
      if (c != 0) return c;
      return a.you ? -1 : (b.you ? 1 : 0);
    });
    return list;
  }

  List<LeagueEntry> get leagueStandings => leagueStandingsFor(
    weekNumber,
    state.leagueTier,
    state.event?.points ?? 0,
    weekFraction,
  );

  int get leagueRank => leagueStandings.indexWhere((e) => e.you) + 1;

  LeagueTierDef get leagueTier =>
      ev.league.tiers[state.leagueTier.clamp(0, ev.league.tiers.length - 1)];

  /// Collects last week's league reward.
  bool claimLeagueResult() {
    final r = state.leagueResult;
    if (r == null) return false;
    state.leagueResult = null;
    state.gems += r.gems;
    analytics.log('league_claim', {'rank': r.rank, 'gems': r.gems});
    _commit();
    return true;
  }
}
