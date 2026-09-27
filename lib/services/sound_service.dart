import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'feedback.dart';

/// Plays the generated sound effects (see `tool/generate_audio.py`) and the
/// background music, plus haptics.
///
/// Every sound gets a small, fixed set of preloaded players that are reused
/// round-robin. Players are never created during play: creating one per
/// sound piles up native players and makes every later sound lag.
class SoundService implements GameFeedback {
  static const _mergeVariants = 8;

  /// How many overlapping copies of one sound can play at once.
  static const _voices = 2;

  /// Ignore repeats of the same sound closer together than this.
  static const _minGapMs = 45;

  final _channels = <String, _SoundChannel>{};
  final _music = AudioPlayer(playerId: 'music');
  double _musicVolume = .6;
  double _sfxVolume = .9;
  bool _muted = false;
  bool _haptics = true;
  bool _musicLoaded = false;

  /// Whether the app is in the foreground (no sound at all otherwise).
  bool _foreground = false;
  bool _musicPlaying = false;

  static List<String> get _files => [
    for (var l = 1; l <= _mergeVariants; l++) 'audio/merge_$l.wav',
    for (final s in Sfx.values)
      if (s != Sfx.merge) _fileFor(s, 1),
  ];

  static String _fileFor(Sfx sfx, int level) => switch (sfx) {
    Sfx.merge => 'audio/merge_${level.clamp(1, _mergeVariants)}.wav',
    Sfx.levelUp => 'audio/levelup.wav',
    _ => 'audio/${sfx.name}.wav',
  };

  Future<void> init() async {
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          // Android: "game" audio plays on the media stream, so the phone's
          // volume buttons control it (not the notification volume), and we
          // don't take audio focus, so the player's own music keeps playing.
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.game,
            contentType: AndroidContentType.music,
            audioFocus: AndroidAudioFocus.none,
          ),
          // iOS: "ambient" mixes with other audio and respects the silent
          // switch, as players expect from a casual game.
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );
      await _music.setReleaseMode(ReleaseMode.loop);
    } catch (e) {
      debugPrint('Audio init failed: $e');
    }
    // Preload every sound once (in the background, so startup isn't
    // delayed) so nothing is created mid-game.
    for (final f in _files) {
      _channels[f] = _SoundChannel(f, _voices);
    }
    unawaited(Future.wait(_channels.values.map((c) => c.load())));
  }

  @override
  void play(Sfx sfx, {int level = 1}) {
    if (_muted || _sfxVolume <= 0 || !_foreground) return;
    _channels[_fileFor(sfx, level)]?.play(_sfxVolume, _minGapMs);
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

  /// App is in the foreground.
  @override
  void startMusic() {
    _foreground = true;
    _syncMusic();
  }

  /// App went to the background: silence everything.
  @override
  void pauseMusic() {
    _foreground = false;
    _syncMusic();
    for (final c in _channels.values) {
      c.stopAll();
    }
  }

  void _syncMusic() {
    final audible = _foreground && !_muted && _musicVolume > 0;
    _music.setVolume(_musicVolume * .5).catchError((_) {});
    if (!audible) {
      if (_musicPlaying) {
        _musicPlaying = false;
        _music.pause().catchError((_) {});
      }
      return;
    }
    if (_musicPlaying) return;
    _musicPlaying = true;
    if (_musicLoaded) {
      _music.resume().catchError((_) {});
    } else {
      _musicLoaded = true;
      _music
          .play(
            AssetSource('audio/music_meadow.wav'),
            volume: _musicVolume * .5,
          )
          .then((_) {
            // If we were backgrounded while the file was still loading.
            if (!_musicPlaying) _music.pause().catchError((_) {});
          })
          .catchError((Object e) => debugPrint('Music failed: $e'));
    }
  }
}

/// A few reusable players for one sound file.
class _SoundChannel {
  _SoundChannel(this.file, int voices)
    : _players = [
        for (var i = 0; i < voices; i++) AudioPlayer(playerId: 'sfx:$file:$i'),
      ];

  final String file;
  final List<AudioPlayer> _players;
  var _next = 0;
  var _lastPlayed = 0;
  var _ready = false;

  Future<void> load() async {
    try {
      for (final p in _players) {
        await p.setPlayerMode(PlayerMode.lowLatency);
        await p.setReleaseMode(ReleaseMode.stop);
        await p.setSource(AssetSource(file));
      }
      _ready = true;
    } catch (e) {
      debugPrint('Sound $file failed to load: $e');
    }
  }

  void play(double volume, int minGapMs) {
    if (!_ready) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPlayed < minGapMs) return;
    _lastPlayed = now;
    final p = _players[_next];
    _next = (_next + 1) % _players.length;
    // Calls on one player run in order, so stop -> resume restarts it.
    p.setVolume(volume).catchError((_) {});
    p.stop().catchError((_) {});
    p.resume().catchError((_) {});
  }

  void stopAll() {
    for (final p in _players) {
      p.stop().catchError((_) {});
    }
  }
}
