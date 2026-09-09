import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/game/domain/game_modes.dart';
import '../../features/game/domain/models.dart';

export '../ads/ads_service.dart';

abstract class AudioService {
  void play(String cue, {double intensity = 1});
  void setSoundEnabled(bool enabled);
  void setMusicEnabled(bool enabled);
  void dispose();
}

abstract interface class GameFeedbackAudioService implements AudioService {
  void playClearLines(int completedLines);
  Future<void> preload();
  Future<void> setAdDucking(bool ducked);
}

extension AudioServiceFeedback on AudioService {
  /// Backwards-compatible adapter for existing test and platform fakes.
  void playClearLines(int completedLines) {
    if (this is GameFeedbackAudioService) {
      (this as GameFeedbackAudioService).playClearLines(completedLines);
      return;
    }
    if (completedLines <= 0) return;
    play(
      completedLines == 1
          ? 'clear_1'
          : completedLines == 2
          ? 'clear_2'
          : 'clear_3',
      intensity: completedLines.toDouble(),
    );
  }

  Future<void> preload() => this is GameFeedbackAudioService
      ? (this as GameFeedbackAudioService).preload()
      : Future<void>.value();

  Future<void> setAdDucking(bool ducked) => this is GameFeedbackAudioService
      ? (this as GameFeedbackAudioService).setAdDucking(ducked)
      : Future<void>.value();
}

class SilentAudioService implements AudioService {
  @override
  void play(String cue, {double intensity = 1}) {
    // Deliberately silent in this source distribution. Production can inject
    // audioplayers/Flame Audio without coupling the game rules to an SDK.
  }

  @override
  void setMusicEnabled(bool enabled) {}

  @override
  void setSoundEnabled(bool enabled) {}

  @override
  void dispose() {}
}

abstract class HapticsService {
  void light();
  void medium();
  void heavy();
}

class SilentHapticsService implements HapticsService {
  @override
  void heavy() {}

  @override
  void light() {}

  @override
  void medium() {}
}

/// Uses the platform's native light, medium, and heavy haptic feedback.
///
/// Haptics are enhancement-only. A platform that does not expose a haptics
/// channel must never interrupt a game turn, so channel failures are ignored.
class SystemHapticsService implements HapticsService {
  void _safe(Future<void> feedback) {
    unawaited(feedback.catchError((Object _) {}));
  }

  @override
  void heavy() => _safe(HapticFeedback.heavyImpact());

  @override
  void light() => _safe(HapticFeedback.lightImpact());

  @override
  void medium() => _safe(HapticFeedback.mediumImpact());
}

class AppPreferences {
  const AppPreferences({
    this.sound = true,
    this.music = true,
    this.vibration = true,
  });

  final bool sound;
  final bool music;
  final bool vibration;

  AppPreferences copyWith({bool? sound, bool? music, bool? vibration}) =>
      AppPreferences(
        sound: sound ?? this.sound,
        music: music ?? this.music,
        vibration: vibration ?? this.vibration,
      );

  Map<String, dynamic> toJson() => {
    'sound': sound,
    'music': music,
    'vibration': vibration,
  };

  factory AppPreferences.fromJson(Map<String, dynamic> json) => AppPreferences(
    sound: json['sound'] as bool? ?? true,
    music: json['music'] as bool? ?? true,
    vibration: json['vibration'] as bool? ?? true,
  );
}

class SavedGame {
  const SavedGame({
    required this.board,
    required this.pieces,
    required this.score,
    required this.best,
    required this.combo,
    required this.generatorState,
    required this.reviveUsed,
    int? reviveCount,
    this.completedGames = 0,
    this.session = const GameSession.classic(),
    this.progress = const ModeProgressSnapshot(),
    this.hasSavedSession = false,
  }) : reviveCount = (reviveCount ?? 0) > 0
           ? (reviveCount ?? 1)
           : (reviveUsed ? 1 : 0);

  final Board board;
  final List<Piece?> pieces;
  final int score;
  final int best;
  final int combo;
  final int generatorState;
  final bool reviveUsed;
  final int reviveCount;
  final int completedGames;
  final GameSession session;
  final ModeProgressSnapshot progress;
  final bool hasSavedSession;

  Map<String, dynamic> toJson() => {
    'schema': 2,
    'board': board.toJson(),
    'pieces': pieces.map((piece) => piece?.toJson()).toList(),
    'score': score,
    'best': best,
    'combo': combo,
    'generatorState': generatorState,
    'reviveUsed': reviveUsed,
    'reviveCount': reviveCount,
    'completedGames': completedGames,
    'placementIds': board.placementIdsToJson(),
    'session': session.toJson(),
    'progress': progress.toJson(),
    'hasSavedSession': hasSavedSession,
  };

  factory SavedGame.fromJson(Map<String, dynamic> json) {
    final schema = json['schema'] as int? ?? 1;
    if (schema != 1 && schema != 2) {
      throw const FormatException('Unsupported save schema.');
    }
    return SavedGame(
      board: Board.fromJson(
        json['board'] as List<dynamic>,
        placementIds: json['placementIds'] as List<dynamic>?,
      ),
      pieces: (json['pieces'] as List<dynamic>)
          .map(
            (piece) => piece == null
                ? null
                : Piece.fromJson(Map<String, dynamic>.from(piece as Map)),
          )
          .toList(),
      score: json['score'] as int,
      best: json['best'] as int,
      combo: json['combo'] as int,
      generatorState: json['generatorState'] as int,
      reviveUsed: json['reviveUsed'] as bool,
      reviveCount: json['reviveCount'] as int?,
      completedGames: json['completedGames'] as int? ?? 0,
      session: schema < 2 || json['session'] == null
          ? const GameSession.classic()
          : GameSession.fromJson(
              Map<String, dynamic>.from(json['session'] as Map),
            ),
      progress: schema < 2 || json['progress'] == null
          ? const ModeProgressSnapshot()
          : ModeProgressSnapshot.fromJson(
              Map<String, dynamic>.from(json['progress'] as Map),
            ),
      hasSavedSession: schema < 2
          ? true
          : json['hasSavedSession'] as bool? ?? true,
    );
  }
}

abstract class GameStorage {
  Future<SavedGame?> loadGame();
  Future<void> saveGame(SavedGame game);
  Future<void> clearGame();
  Future<AppPreferences> loadPreferences();
  Future<void> savePreferences(AppPreferences preferences);
}

abstract interface class ModeProgressStorage {
  Future<ModeProgressSnapshot> loadModeProgress();
  Future<void> saveModeProgress(ModeProgressSnapshot progress);
}

extension GameStorageProgress on GameStorage {
  /// Separate progress survives clearing an active game at results time.
  Future<ModeProgressSnapshot> loadModeProgress() => this is ModeProgressStorage
      ? (this as ModeProgressStorage).loadModeProgress()
      : Future<ModeProgressSnapshot>.value(const ModeProgressSnapshot());

  Future<void> saveModeProgress(ModeProgressSnapshot progress) =>
      this is ModeProgressStorage
      ? (this as ModeProgressStorage).saveModeProgress(progress)
      : Future<void>.value();
}

class SharedPreferencesStorage implements GameStorage, ModeProgressStorage {
  SharedPreferencesStorage(this._preferences);

  final SharedPreferences _preferences;
  static const _gameKey = 'prism_pop_active_game';
  static const _preferencesKey = 'prism_pop_preferences';
  static const _modeProgressKey = 'blockora_mode_progress';

  @override
  Future<void> clearGame() async => _preferences.remove(_gameKey);

  @override
  Future<SavedGame?> loadGame() async {
    final raw = _preferences.getString(_gameKey);
    if (raw == null) return null;
    try {
      return SavedGame.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      await clearGame();
      return null;
    }
  }

  @override
  Future<AppPreferences> loadPreferences() async {
    final raw = _preferences.getString(_preferencesKey);
    if (raw == null) return const AppPreferences();
    try {
      return AppPreferences.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const AppPreferences();
    }
  }

  @override
  Future<void> saveGame(SavedGame game) async =>
      _preferences.setString(_gameKey, jsonEncode(game.toJson()));

  @override
  Future<void> savePreferences(AppPreferences preferences) async =>
      _preferences.setString(_preferencesKey, jsonEncode(preferences.toJson()));

  @override
  Future<ModeProgressSnapshot> loadModeProgress() async {
    final raw = _preferences.getString(_modeProgressKey);
    if (raw == null) return const ModeProgressSnapshot();
    try {
      return ModeProgressSnapshot.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return const ModeProgressSnapshot();
    }
  }

  @override
  Future<void> saveModeProgress(ModeProgressSnapshot progress) async =>
      _preferences.setString(_modeProgressKey, jsonEncode(progress.toJson()));
}
