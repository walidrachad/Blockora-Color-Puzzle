import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import '../services/services.dart';
import 'line_clear_audio.dart';

/// Small preloaded pools for the three clear tiers. Gameplay only schedules a
/// sound and never waits for an audio asset or platform channel.
class LocalGameAudioService implements GameFeedbackAudioService {
  static const _gameOverAsset =
      'audio/mixkit-player-losing-or-failing-2042.wav';

  static const _assets = <ClearAudioTier, String>{
    ClearAudioTier.one: 'audio/mixkit-video-game-treasure-2066.wav',
    ClearAudioTier.two: 'audio/mixkit-player-recharging-in-video-game-2041.wav',
    ClearAudioTier.three: 'mixkit-game-level-completed-2059.wav',
  };

  final Map<ClearAudioTier, AudioPool> _pools = {};
  AudioPool? _gameOverPool;
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _interactionPlayer = AudioPlayer();
  Future<void>? _preloadFuture;
  Future<void>? _musicStartFuture;
  bool _soundEnabled = true;
  bool _musicEnabled = true;
  bool _musicPlaying = false;
  bool _ducked = false;
  bool _disposed = false;

  @override
  Future<void> preload() {
    return _preloadFuture ??= _loadPools();
  }

  Future<void> _loadPools() async {
    for (final entry in _assets.entries) {
      if (_disposed) return;
      try {
        final pool = await AudioPool.createFromAsset(
          path: entry.value,
          maxPlayers: 2,
          minPlayers: 1,
          // mediaPlayer lets the pool reclaim a player after the short cue.
          // It is more reliable across desktop, simulator, and mobile than
          // lowLatency, while still keeping all players preloaded.
          playerMode: PlayerMode.mediaPlayer,
        );
        if (_disposed) {
          await pool.dispose();
          return;
        }
        _pools[entry.key] = pool;
      } catch (_) {
        // Audio is an enhancement. A missing codec/platform backend must not
        // prevent the board from starting.
      }
    }
    try {
      final pool = await AudioPool.createFromAsset(
        path: _gameOverAsset,
        maxPlayers: 1,
        minPlayers: 1,
        playerMode: PlayerMode.mediaPlayer,
      );
      if (_disposed) {
        await pool.dispose();
        return;
      }
      _gameOverPool = pool;
    } catch (_) {
      // Game-over feedback is enhancement-only and must not block startup.
    }
    if (_musicEnabled) unawaited(_startMusic());
  }

  @override
  void play(String cue, {double intensity = 1}) {
    if (cue == 'game_over') {
      unawaited(_startGameOver());
      return;
    }
    if (cue == 'pickup') {
      // Audio 4: a short rising cue when a piece leaves the tray.
      unawaited(_playInteraction(_pickupAudio4));
      return;
    }
    if (cue == 'invalid_drop') {
      // Audio 3: a short falling cue when the piece returns to the tray.
      unawaited(_playInteraction(_returnAudio3));
      return;
    }
    if (cue == 'clear_1' || cue == 'clear_2' || cue == 'clear_3') {
      final count = cue == 'clear_1'
          ? 1
          : cue == 'clear_2'
          ? 2
          : 3;
      playClearLines(count);
    }
  }

  Future<void> _startGameOver() async {
    await preload();
    if (_disposed || !_soundEnabled) return;
    final pool = _gameOverPool;
    if (pool == null) return;
    try {
      await pool.start(volume: _ducked ? .22 : .82);
    } catch (_) {
      // A platform audio error should never affect the results screen.
    }
  }

  Future<void> _playInteraction(Uint8List bytes) async {
    if (!_soundEnabled || _disposed) return;
    try {
      await _interactionPlayer.stop();
      await _interactionPlayer.setVolume(_ducked ? .16 : .56);
      await _interactionPlayer.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (_) {
      // Interaction feedback is enhancement-only and must never affect drag.
    }
  }

  @override
  void playClearLines(int completedLines) {
    if (!_soundEnabled || _disposed || completedLines <= 0) return;
    final tier = tierForCompletedLines(completedLines);
    unawaited(_start(tier));
  }

  Future<void> _start(ClearAudioTier tier) async {
    await preload();
    if (_disposed || !_soundEnabled) return;
    final pool = _pools[tier];
    if (pool == null) return;
    try {
      await pool.start(volume: _ducked ? .22 : .78);
    } catch (_) {
      // A platform audio error should never affect the turn state.
    }
  }

  @override
  Future<void> setAdDucking(bool ducked) async {
    _ducked = ducked;
    // New starts use the ducked volume. Existing players are intentionally not
    // touched because AudioPool exposes no stable cross-platform mixer API.
  }

  @override
  void setSoundEnabled(bool enabled) => _soundEnabled = enabled;

  @override
  void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
    if (enabled) {
      unawaited(_startMusic());
      return;
    }
    _musicPlaying = false;
    unawaited(_musicPlayer.stop());
  }

  Future<void> _startMusic() {
    if (_disposed || !_musicEnabled || _musicPlaying) {
      return Future<void>.value();
    }
    return _musicStartFuture ??= _playMusic();
  }

  Future<void> _playMusic() async {
    try {
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _musicPlayer.setVolume(.14);
      if (_disposed || !_musicEnabled) return;
      await _musicPlayer.play(BytesSource(_musicBytes, mimeType: 'audio/wav'));
      if (_disposed || !_musicEnabled) {
        await _musicPlayer.stop();
        return;
      }
      _musicPlaying = true;
    } catch (_) {
      // Music is an enhancement. Unsupported platform codecs must not affect
      // gameplay or the settings sheet.
    } finally {
      _musicStartFuture = null;
    }
  }

  static final Uint8List _musicBytes = _buildMusicWav();

  static final Uint8List _pickupAudio4 = _buildInteractionWav(
    startFrequency: 520,
    endFrequency: 820,
    duration: .12,
    volume: .16,
  );

  static final Uint8List _returnAudio3 = _buildInteractionWav(
    startFrequency: 300,
    endFrequency: 170,
    duration: .14,
    volume: .14,
  );

  static Uint8List _buildInteractionWav({
    required double startFrequency,
    required double endFrequency,
    required double duration,
    required double volume,
  }) {
    const sampleRate = 22050;
    const channels = 1;
    const bitsPerSample = 16;
    final sampleCount = (sampleRate * duration).round();
    final dataLength = sampleCount * channels * bitsPerSample ~/ 8;
    final bytes = ByteData(44 + dataLength);

    void writeAscii(int offset, String value) {
      for (var index = 0; index < value.length; index++) {
        bytes.setUint8(offset + index, value.codeUnitAt(index));
      }
    }

    writeAscii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataLength, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, channels, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(
      28,
      sampleRate * channels * bitsPerSample ~/ 8,
      Endian.little,
    );
    bytes.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    bytes.setUint16(34, bitsPerSample, Endian.little);
    writeAscii(36, 'data');
    bytes.setUint32(40, dataLength, Endian.little);

    for (var sample = 0; sample < sampleCount; sample++) {
      final progress = sample / sampleCount;
      final frequency =
          startFrequency + (endFrequency - startFrequency) * progress;
      final envelope =
          math.min(1.0, progress * 80) * math.pow(1 - progress, 1.8);
      final value =
          (math.sin(2 * math.pi * frequency * sample / sampleRate) *
                  volume *
                  envelope *
                  32767)
              .round()
              .clamp(-32768, 32767)
              .toInt();
      bytes.setInt16(44 + sample * 2, value, Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  /// A small, self-contained ambient loop keeps the Music setting functional
  /// without adding a large binary track to the game bundle.
  static Uint8List _buildMusicWav() {
    const sampleRate = 22050;
    const seconds = 8;
    const channels = 1;
    const bitsPerSample = 16;
    final sampleCount = sampleRate * seconds;
    final dataLength = sampleCount * channels * bitsPerSample ~/ 8;
    final bytes = ByteData(44 + dataLength);

    void writeAscii(int offset, String value) {
      for (var index = 0; index < value.length; index++) {
        bytes.setUint8(offset + index, value.codeUnitAt(index));
      }
    }

    writeAscii(0, 'RIFF');
    bytes.setUint32(4, 36 + dataLength, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, channels, Endian.little);
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(
      28,
      sampleRate * channels * bitsPerSample ~/ 8,
      Endian.little,
    );
    bytes.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
    bytes.setUint16(34, bitsPerSample, Endian.little);
    writeAscii(36, 'data');
    bytes.setUint32(40, dataLength, Endian.little);

    const notes = <double>[
      261.63,
      329.63,
      392.00,
      329.63,
      293.66,
      349.23,
      440.00,
      349.23,
    ];
    for (var sample = 0; sample < sampleCount; sample++) {
      final time = sample / sampleRate;
      final noteTime = time % seconds;
      final noteIndex = noteTime.floor();
      final progress = noteTime - noteIndex;
      final frequency = notes[noteIndex];
      final envelope =
          math.min(1.0, progress * 10) * math.min(1.0, (1 - progress) * 10);
      final lead = math.sin(2 * math.pi * frequency * time) * .08 * envelope;
      final pad = math.sin(2 * math.pi * frequency / 2 * time) * .025;
      final value = ((lead + pad) * 32767).round().clamp(-32768, 32767).toInt();
      bytes.setInt16(44 + sample * 2, value, Endian.little);
    }
    return bytes.buffer.asUint8List();
  }

  @override
  void dispose() {
    _disposed = true;
    _musicPlaying = false;
    unawaited(_musicPlayer.dispose());
    unawaited(_interactionPlayer.dispose());
    final gameOverPool = _gameOverPool;
    _gameOverPool = null;
    if (gameOverPool != null) unawaited(gameOverPool.dispose());
    for (final pool in _pools.values) {
      unawaited(pool.dispose());
    }
    _pools.clear();
  }
}
