import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'feedback.dart';

/// Plays the generated sound effects (see `tool/generate_audio.py`) and the
/// background music, plus haptics.
class SoundService implements GameFeedback {
  static const _mergeVariants = 8;

  final _pools = <String, Future<AudioPool>>{};
  final _music = AudioPlayer(playerId: 'music');
  double _musicVolume = .6;
  double _sfxVolume = .9;
  bool _muted = false;
  bool _haptics = true;
  bool _musicStarted = false;
  bool _musicWanted = false;

  Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(
          focus: AudioContextConfigFocus.mixWithOthers,
          respectSilence: true,
        ).build(),
      );
      await _music.setReleaseMode(ReleaseMode.loop);
    } catch (e) {
      debugPrint('Audio init failed: $e');
    }
  }

  String _file(Sfx sfx, int level) => switch (sfx) {
    Sfx.merge => 'audio/merge_${level.clamp(1, _mergeVariants)}.wav',
    Sfx.levelUp => 'audio/levelup.wav',
    _ => 'audio/${sfx.name}.wav',
  };

  @override
  void play(Sfx sfx, {int level = 1}) {
    if (_muted || _sfxVolume <= 0) return;
    final file = _file(sfx, level);
    final pool = _pools.putIfAbsent(
      file,
      () => AudioPool.createFromAsset(
        path: file,
        maxPlayers: 3,
        playerMode: PlayerMode.lowLatency,
      ),
    );
    pool.then((p) => p.start(volume: _sfxVolume)).catchError((Object e) {
      debugPrint('Sound $file failed: $e');
      return () async {};
    });
  }

  @override
  void haptic({bool heavy = false}) {
    if (!_haptics) return;
    heavy ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact();
  }

  @override
  void applySettings({
    required double musicVolume,
    required double sfxVolume,
    required bool muted,
    required bool haptics,
  }) {
    _musicVolume = musicVolume;
    _sfxVolume = sfxVolume;
    _muted = muted;
    _haptics = haptics;
    _syncMusic();
  }

  @override
  void startMusic() {
    _musicWanted = true;
    _syncMusic();
  }

  @override
  void pauseMusic() {
    _musicWanted = false;
    if (_musicStarted) _music.pause().catchError((_) {});
  }

  void _syncMusic() {
    final audible = _musicWanted && !_muted && _musicVolume > 0;
    _music.setVolume(_musicVolume * .5).catchError((_) {});
    if (!audible) {
      if (_musicStarted) _music.pause().catchError((_) {});
      return;
    }
    if (_musicStarted) {
      _music.resume().catchError((_) {});
    } else {
      _musicStarted = true;
      _music
          .play(
            AssetSource('audio/music_meadow.wav'),
            volume: _musicVolume * .5,
          )
          .catchError((Object e) => debugPrint('Music failed: $e'));
    }
  }
}
