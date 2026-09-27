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

  final _channels = <String, SoundChannel>{};
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
      _channels[f] = SoundChannel(f, _voices);
    }
    unawaited(Future.wait(_channels.values.map((c) => c.load())));
  }

  @override
  void play(Sfx sfx, {int level = 1}) {
    if (_muted || _sfxVolume <= 0 || !_foreground) return;
    unawaited(_channels[_fileFor(sfx, level)]?.play(_sfxVolume, _minGapMs));
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
      unawaited(c.stopAll());
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
///
/// Commands to a player must run strictly one after another: audioplayers
/// tracks a "desired state", so firing stop() and resume() without awaiting
/// lets the resume cancel the stop, the native player never stops, and every
/// later play() is ignored. Each player therefore has its own serial queue.
@visibleForTesting
class SoundChannel {
  SoundChannel(this.file, int voices, {AudioPlayer Function(String id)? create})
    : _players = [
        for (var i = 0; i < voices; i++)
          (create ?? (id) => AudioPlayer(playerId: id))('sfx:$file:$i'),
      ],
      _busy = List.filled(voices, false),
      _tails = List.filled(voices, Future<void>.value());

  final String file;
  final List<AudioPlayer> _players;
  final List<bool> _busy;
  final List<Future<void>> _tails;
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

  @visibleForTesting
  void debugMarkReady() => _ready = true;

  /// Runs [op] on player [i] after everything already queued for it.
  Future<void> _enqueue(int i, Future<void> Function(AudioPlayer p) op) {
    _busy[i] = true;
    final done = _tails[i].then((_) => op(_players[i])).catchError((Object e) {
      debugPrint('Sound $file: $e');
    });
    _tails[i] = done;
    done.whenComplete(() {
      if (identical(_tails[i], done)) _busy[i] = false;
    });
    return done;
  }

  /// Restarts the sound on a free player. If every player is still busy
  /// (a slow device), the sound is skipped rather than queued, so sounds
  /// never lag behind taps.
  Future<void> play(double volume, int minGapMs) async {
    if (!_ready) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastPlayed < minGapMs) return;
    for (var k = 0; k < _players.length; k++) {
      final i = (_next + k) % _players.length;
      if (_busy[i]) continue;
      _lastPlayed = now;
      _next = (i + 1) % _players.length;
      await _enqueue(i, (p) async {
        await p.setVolume(volume);
        await p.stop();
        await p.resume();
      });
      return;
    }
  }

  Future<void> stopAll() => Future.wait([
    for (var i = 0; i < _players.length; i++) _enqueue(i, (p) => p.stop()),
  ]);
}
