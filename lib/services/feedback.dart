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

  /// A baby dragon's chirp and a grown dragon's roar.
  chirp,
  roar,
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

  /// Background music for an island theme (meadow, volcano, lagoon...).
  void setMusicTrack(String track);

  /// Silences all game audio while something else is playing (an ad).
  void setSuppressed(bool suppressed);
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
  @override
  void setMusicTrack(String track) {}
  @override
  void setSuppressed(bool suppressed) {}
}
