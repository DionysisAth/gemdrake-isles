import 'package:audioplayers_platform_interface/audioplayers_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gemdrake_isles/services/sound_service.dart';

/// Mimics the Android native player: play() is ignored while the native
/// side still thinks it's playing, and only stop()/pause() reset that.
class FakeNativeAudio extends AudioplayersPlatformInterface {
  final playing = <String, bool>{};
  final starts = <String, int>{};
  final calls = <String>[];

  int get totalStarts => starts.values.fold(0, (a, b) => a + b);

  @override
  Future<void> create(String playerId) async {}

  @override
  Stream<AudioEvent> getEventStream(String playerId) => const Stream.empty();

  @override
  Future<void> resume(String playerId) async {
    calls.add(playerId == 'music' ? 'resume:music' : 'resume');
    if (playing[playerId] != true) {
      playing[playerId] = true;
      starts[playerId] = (starts[playerId] ?? 0) + 1;
    }
  }

  @override
  Future<void> stop(String playerId) async {
    calls.add('stop');
    playing[playerId] = false;
  }

  @override
  Future<void> pause(String playerId) async {
    calls.add('pause:$playerId');
    playing[playerId] = false;
  }

  @override
  Future<void> setVolume(String playerId, double volume) async {}

  @override
  Future<int?> getCurrentPosition(String playerId) async => 0;

  @override
  Future<int?> getDuration(String playerId) async => 100;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

class FakeGlobalAudio extends GlobalAudioplayersPlatformInterface {
  @override
  Stream<GlobalAudioEvent> getGlobalEventStream() => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<void>.value();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeNativeAudio native;

  setUp(() {
    native = FakeNativeAudio();
    AudioplayersPlatformInterface.instance = native;
    GlobalAudioplayersPlatformInterface.instance = FakeGlobalAudio();
  });

  test('every play restarts the sound, even after many plays', () async {
    final channel = SoundChannel('audio/pop.wav', 2)..debugMarkReady();
    for (var i = 0; i < 50; i++) {
      await channel.play(1, 0);
    }
    // Regression: stop() and resume() used to race, the stop was dropped,
    // and after the first play on each player every later play was silent.
    expect(native.totalStarts, 50);
    expect(native.playing.values.where((p) => p), isNotEmpty);
  });

  test('stop is sent before every resume', () async {
    final channel = SoundChannel('audio/pop.wav', 1)..debugMarkReady();
    await channel.play(1, 0);
    await channel.play(1, 0);
    expect(native.calls, ['stop', 'resume', 'stop', 'resume']);
  });

  test('stopAll silences every player', () async {
    final channel = SoundChannel('audio/pop.wav', 2)..debugMarkReady();
    await channel.play(1, 0);
    await channel.play(1, 0);
    await channel.stopAll();
    expect(native.playing.values.every((p) => !p), isTrue);
  });

  test('rapid repeats within the gap are skipped', () async {
    final channel = SoundChannel('audio/pop.wav', 2)..debugMarkReady();
    await channel.play(1, 10000);
    await channel.play(1, 10000);
    expect(native.totalStarts, 1);
  });

  test('music pauses while an ad is showing and comes back after', () async {
    final sound = SoundService();
    sound.startMusic(); // first start loads + plays the track
    await pumpEventQueue();
    native.calls.clear();

    sound.setSuppressed(true);
    await pumpEventQueue();
    expect(native.calls, contains('pause:music'));

    // Coming back to the app mid-ad must not restart the music.
    sound.startMusic();
    await pumpEventQueue();
    expect(native.calls, isNot(contains('resume:music')));

    sound.setSuppressed(false);
    await pumpEventQueue();
    expect(native.calls, contains('resume:music'));
  });
}
