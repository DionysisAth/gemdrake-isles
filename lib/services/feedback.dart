/// Sound effects the game can play. Files live in `assets/audio/`.
enum Sfx {
  pop,
  merge,
  bonus,
  hatch,
  levelUp,
  order,
  coin,
  error,
  unlock,
  restore,
  tap,
  collect,
}

/// Audio + haptic feedback, abstracted so game logic stays testable.
abstract class GameFeedback {
  void play(Sfx sfx, {int level = 1});
  void haptic({bool heavy = false});
  void applySettings({
    required double musicVolume,
    required double sfxVolume,
    required bool muted,
    required bool haptics,
  });
  void startMusic();
  void pauseMusic();
}

class SilentFeedback implements GameFeedback {
  @override
  void play(Sfx sfx, {int level = 1}) {}
  @override
  void haptic({bool heavy = false}) {}
  @override
  void applySettings({
    required double musicVolume,
    required double sfxVolume,
    required bool muted,
    required bool haptics,
  }) {}
  @override
  void startMusic() {}
  @override
  void pauseMusic() {}
}
