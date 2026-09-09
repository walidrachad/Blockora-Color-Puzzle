import 'package:equatable/equatable.dart';

import 'models.dart';

enum GameMode { classic, journey, dailyChallenge }

extension GameModePresentation on GameMode {
  String get storageKey => switch (this) {
    GameMode.classic => 'classic',
    GameMode.journey => 'journey',
    GameMode.dailyChallenge => 'daily_challenge',
  };

  String get label => switch (this) {
    GameMode.classic => 'Classic',
    GameMode.journey => 'Journey',
    GameMode.dailyChallenge => 'Daily Challenge',
  };
}

GameMode gameModeFromJson(Object? value) => switch (value) {
  'journey' => GameMode.journey,
  'daily_challenge' => GameMode.dailyChallenge,
  _ => GameMode.classic,
};

enum JourneyObjectiveType { score, lines, coloredCells }

extension JourneyObjectivePresentation on JourneyObjectiveType {
  String get storageKey => switch (this) {
    JourneyObjectiveType.score => 'score',
    JourneyObjectiveType.lines => 'lines',
    JourneyObjectiveType.coloredCells => 'colored_cells',
  };

  String get label => switch (this) {
    JourneyObjectiveType.score => 'Score',
    JourneyObjectiveType.lines => 'Lines',
    JourneyObjectiveType.coloredCells => 'Colored cells',
  };
}

JourneyObjectiveType journeyObjectiveTypeFromJson(Object? value) =>
    switch (value) {
      'lines' => JourneyObjectiveType.lines,
      'colored_cells' => JourneyObjectiveType.coloredCells,
      _ => JourneyObjectiveType.score,
    };

class JourneyObjective extends Equatable {
  const JourneyObjective({required this.type, required this.targetValue});

  final JourneyObjectiveType type;
  final int targetValue;

  int progress({
    required int score,
    required int lines,
    required int coloredCells,
  }) => switch (type) {
    JourneyObjectiveType.score => score,
    JourneyObjectiveType.lines => lines,
    JourneyObjectiveType.coloredCells => coloredCells,
  };

  bool isComplete({
    required int score,
    required int lines,
    required int coloredCells,
  }) =>
      progress(score: score, lines: lines, coloredCells: coloredCells) >=
      targetValue;

  String description({bool compact = false}) {
    final noun = switch (type) {
      JourneyObjectiveType.score => compact ? 'score' : 'Score',
      JourneyObjectiveType.lines => compact ? 'lines' : 'Lines',
      JourneyObjectiveType.coloredCells =>
        compact ? 'colored cells' : 'Colored cells',
    };
    return '$noun: $targetValue';
  }

  Map<String, dynamic> toJson() => {
    'type': type.storageKey,
    'targetValue': targetValue,
  };

  factory JourneyObjective.fromJson(Map<String, dynamic> json) =>
      JourneyObjective(
        type: journeyObjectiveTypeFromJson(json['type']),
        targetValue: (json['targetValue'] as int? ?? 1)
            .clamp(1, 999999)
            .toInt(),
      );

  @override
  List<Object?> get props => [type, targetValue];
}

class JourneyStarThresholds extends Equatable {
  const JourneyStarThresholds({
    required this.one,
    required this.two,
    required this.three,
  });

  final int one;
  final int two;
  final int three;

  Map<String, int> toJson() => {'one': one, 'two': two, 'three': three};

  factory JourneyStarThresholds.fromJson(Map<String, dynamic> json) =>
      JourneyStarThresholds(
        one: json['one'] as int? ?? 1,
        two: json['two'] as int? ?? 2,
        three: json['three'] as int? ?? 3,
      );

  @override
  List<Object?> get props => [one, two, three];
}

class JourneyLevel extends Equatable {
  const JourneyLevel({
    required this.id,
    required this.levelNumber,
    required this.initialBoard,
    required this.randomSeed,
    required this.objective,
    required this.moveLimit,
    required this.availablePieceRules,
    required this.starThresholds,
    required this.reward,
    this.allowRewardedRevive = false,
  });

  final String id;
  final int levelNumber;
  final Board initialBoard;
  final int randomSeed;
  final JourneyObjective objective;
  final int? moveLimit;
  final List<String> availablePieceRules;
  final JourneyStarThresholds starThresholds;
  final String reward;
  final bool allowRewardedRevive;

  int starsFor({
    required int score,
    required int lines,
    required int coloredCells,
    required int moves,
  }) {
    final value = objective.progress(
      score: score,
      lines: lines,
      coloredCells: coloredCells,
    );
    if (value < starThresholds.one) return 0;
    if (value >= starThresholds.three &&
        (moveLimit == null || moves <= (moveLimit! * .70).ceil())) {
      return 3;
    }
    if (value >= starThresholds.two &&
        (moveLimit == null || moves <= (moveLimit! * .85).ceil())) {
      return 2;
    }
    return 1;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'levelNumber': levelNumber,
    'initialBoard': initialBoard.toJson(),
    'randomSeed': randomSeed,
    'objective': objective.toJson(),
    'moveLimit': moveLimit,
    'availablePieceRules': availablePieceRules,
    'starThresholds': starThresholds.toJson(),
    'reward': reward,
    'allowRewardedRevive': allowRewardedRevive,
  };

  factory JourneyLevel.fromJson(Map<String, dynamic> json) => JourneyLevel(
    id: json['id'] as String,
    levelNumber: json['levelNumber'] as int,
    initialBoard: Board.fromJson(json['initialBoard'] as List<dynamic>),
    randomSeed: json['randomSeed'] as int,
    objective: JourneyObjective.fromJson(
      Map<String, dynamic>.from(json['objective'] as Map),
    ),
    moveLimit: json['moveLimit'] as int?,
    availablePieceRules: (json['availablePieceRules'] as List<dynamic>)
        .cast<String>(),
    starThresholds: JourneyStarThresholds.fromJson(
      Map<String, dynamic>.from(json['starThresholds'] as Map),
    ),
    reward: json['reward'] as String,
    allowRewardedRevive: json['allowRewardedRevive'] as bool? ?? false,
  );

  @override
  List<Object?> get props => [
    id,
    levelNumber,
    initialBoard,
    randomSeed,
    objective,
    moveLimit,
    availablePieceRules,
    starThresholds,
    reward,
    allowRewardedRevive,
  ];
}

class GameSession extends Equatable {
  const GameSession({
    required this.mode,
    this.journeyLevelId,
    this.journeyObjective,
    this.dailyChallenge,
    this.movesUsed = 0,
    this.linesCleared = 0,
    this.coloredCellsCleared = 0,
    this.reviveEnabled = false,
  });

  const GameSession.classic()
    : this(mode: GameMode.classic, reviveEnabled: true);

  final GameMode mode;
  final String? journeyLevelId;
  final JourneyObjective? journeyObjective;
  final DailyChallenge? dailyChallenge;
  final int movesUsed;
  final int linesCleared;
  final int coloredCellsCleared;
  final bool reviveEnabled;

  JourneyObjective? get objective =>
      journeyObjective ?? dailyChallenge?.objective;

  GameSession copyWith({
    GameMode? mode,
    Object? journeyLevelId = _unset,
    Object? journeyObjective = _unset,
    Object? dailyChallenge = _unset,
    int? movesUsed,
    int? linesCleared,
    int? coloredCellsCleared,
    bool? reviveEnabled,
  }) => GameSession(
    mode: mode ?? this.mode,
    journeyLevelId: journeyLevelId == _unset
        ? this.journeyLevelId
        : journeyLevelId as String?,
    journeyObjective: journeyObjective == _unset
        ? this.journeyObjective
        : journeyObjective as JourneyObjective?,
    dailyChallenge: dailyChallenge == _unset
        ? this.dailyChallenge
        : dailyChallenge as DailyChallenge?,
    movesUsed: movesUsed ?? this.movesUsed,
    linesCleared: linesCleared ?? this.linesCleared,
    coloredCellsCleared: coloredCellsCleared ?? this.coloredCellsCleared,
    reviveEnabled: reviveEnabled ?? this.reviveEnabled,
  );

  Map<String, dynamic> toJson() => {
    'mode': mode.storageKey,
    'journeyLevelId': journeyLevelId,
    'journeyObjective': journeyObjective?.toJson(),
    'dailyChallenge': dailyChallenge?.toJson(),
    'movesUsed': movesUsed,
    'linesCleared': linesCleared,
    'coloredCellsCleared': coloredCellsCleared,
    'reviveEnabled': reviveEnabled,
  };

  factory GameSession.fromJson(Map<String, dynamic> json) => GameSession(
    mode: gameModeFromJson(json['mode']),
    journeyLevelId: json['journeyLevelId'] as String?,
    journeyObjective: json['journeyObjective'] == null
        ? null
        : JourneyObjective.fromJson(
            Map<String, dynamic>.from(json['journeyObjective'] as Map),
          ),
    dailyChallenge: json['dailyChallenge'] == null
        ? null
        : DailyChallenge.fromJson(
            Map<String, dynamic>.from(json['dailyChallenge'] as Map),
          ),
    movesUsed: json['movesUsed'] as int? ?? 0,
    linesCleared: json['linesCleared'] as int? ?? 0,
    coloredCellsCleared: json['coloredCellsCleared'] as int? ?? 0,
    reviveEnabled: json['reviveEnabled'] as bool? ?? false,
  );

  @override
  List<Object?> get props => [
    mode,
    journeyLevelId,
    journeyObjective,
    dailyChallenge,
    movesUsed,
    linesCleared,
    coloredCellsCleared,
    reviveEnabled,
  ];
}

class ClassicProgress extends Equatable {
  const ClassicProgress({this.bestScore = 0});

  final int bestScore;

  ClassicProgress copyWith({int? bestScore}) =>
      ClassicProgress(bestScore: bestScore ?? this.bestScore);

  Map<String, dynamic> toJson() => {'bestScore': bestScore};

  factory ClassicProgress.fromJson(Map<String, dynamic> json) =>
      ClassicProgress(bestScore: json['bestScore'] as int? ?? 0);

  @override
  List<Object?> get props => [bestScore];
}

class JourneyProgress extends Equatable {
  const JourneyProgress({
    this.unlockedLevel = 1,
    this.stars = const {},
    this.bestScores = const {},
    this.bestMoves = const {},
  });

  final int unlockedLevel;
  final Map<String, int> stars;
  final Map<String, int> bestScores;
  final Map<String, int> bestMoves;

  bool isUnlocked(JourneyLevel level) => level.levelNumber <= unlockedLevel;

  int starsFor(String levelId) => stars[levelId] ?? 0;

  JourneyProgress recordCompletion(
    JourneyLevel level, {
    required int score,
    required int moves,
    required int lines,
    required int coloredCells,
  }) {
    final earned = level.starsFor(
      score: score,
      lines: lines,
      coloredCells: coloredCells,
      moves: moves,
    );
    final nextStars = Map<String, int>.from(stars);
    nextStars[level.id] = earned > (nextStars[level.id] ?? 0)
        ? earned
        : nextStars[level.id] ?? 0;
    final nextScores = Map<String, int>.from(bestScores);
    if (score > (nextScores[level.id] ?? 0)) nextScores[level.id] = score;
    final nextMoves = Map<String, int>.from(bestMoves);
    if (moves < (nextMoves[level.id] ?? 1 << 30)) nextMoves[level.id] = moves;
    return JourneyProgress(
      unlockedLevel: unlockedLevel < level.levelNumber + 1
          ? level.levelNumber + 1
          : unlockedLevel,
      stars: nextStars,
      bestScores: nextScores,
      bestMoves: nextMoves,
    );
  }

  Map<String, dynamic> toJson() => {
    'unlockedLevel': unlockedLevel,
    'stars': stars,
    'bestScores': bestScores,
    'bestMoves': bestMoves,
  };

  factory JourneyProgress.fromJson(Map<String, dynamic> json) =>
      JourneyProgress(
        unlockedLevel: (json['unlockedLevel'] as int? ?? 1).clamp(1, 999),
        stars: _intMap(json['stars']),
        bestScores: _intMap(json['bestScores']),
        bestMoves: _intMap(json['bestMoves']),
      );

  @override
  List<Object?> get props => [unlockedLevel, stars, bestScores, bestMoves];
}

class DailyChallenge extends Equatable {
  const DailyChallenge({
    required this.dateKey,
    required this.seed,
    required this.objective,
    required this.initialBoard,
    required this.moveLimit,
    required this.configurationVersion,
  });

  final String dateKey;
  final int seed;
  final JourneyObjective objective;
  final Board initialBoard;
  final int? moveLimit;
  final String configurationVersion;

  Map<String, dynamic> toJson() => {
    'dateKey': dateKey,
    'seed': seed,
    'objective': objective.toJson(),
    'initialBoard': initialBoard.toJson(),
    'moveLimit': moveLimit,
    'configurationVersion': configurationVersion,
  };

  factory DailyChallenge.fromJson(Map<String, dynamic> json) => DailyChallenge(
    dateKey: json['dateKey'] as String,
    seed: json['seed'] as int,
    objective: JourneyObjective.fromJson(
      Map<String, dynamic>.from(json['objective'] as Map),
    ),
    initialBoard: Board.fromJson(json['initialBoard'] as List<dynamic>),
    moveLimit: json['moveLimit'] as int?,
    configurationVersion: json['configurationVersion'] as String? ?? 'v1',
  );

  @override
  List<Object?> get props => [
    dateKey,
    seed,
    objective,
    initialBoard,
    moveLimit,
    configurationVersion,
  ];
}

class DailyProgress extends Equatable {
  const DailyProgress({
    this.completedDates = const {},
    this.bestScores = const {},
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCompletedDate,
    this.lastObservedDate,
  });

  final Set<String> completedDates;
  final Map<String, int> bestScores;
  final int currentStreak;
  final int longestStreak;
  final String? lastCompletedDate;
  final String? lastObservedDate;

  bool isCompleted(String dateKey) => completedDates.contains(dateKey);
  int bestScoreFor(String dateKey) => bestScores[dateKey] ?? 0;

  int currentStreakFor(String dateKey) {
    if (lastCompletedDate == null ||
        _dateDifference(lastCompletedDate!, dateKey) > 1) {
      return 0;
    }
    return currentStreak;
  }

  DailyProgress recordCompletion(String dateKey, int score) {
    // This is intentionally client-only protection. A user can still change a
    // clock forward, but moving backward cannot repeatedly award a streak.
    if (lastObservedDate != null && dateKey.compareTo(lastObservedDate!) < 0) {
      return this;
    }
    final nextDates = Set<String>.from(completedDates)..add(dateKey);
    final nextScores = Map<String, int>.from(bestScores);
    if (score > (nextScores[dateKey] ?? 0)) nextScores[dateKey] = score;
    if (completedDates.contains(dateKey)) {
      return DailyProgress(
        completedDates: nextDates,
        bestScores: nextScores,
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        lastCompletedDate: lastCompletedDate,
        lastObservedDate: dateKey,
      );
    }
    final consecutive =
        lastCompletedDate != null &&
        _dateDifference(lastCompletedDate!, dateKey) == 1;
    final nextStreak = consecutive ? currentStreak + 1 : 1;
    return DailyProgress(
      completedDates: nextDates,
      bestScores: nextScores,
      currentStreak: nextStreak,
      longestStreak: nextStreak > longestStreak ? nextStreak : longestStreak,
      lastCompletedDate: dateKey,
      lastObservedDate: dateKey,
    );
  }

  Map<String, dynamic> toJson() => {
    'completedDates': completedDates.toList()..sort(),
    'bestScores': bestScores,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'lastCompletedDate': lastCompletedDate,
    'lastObservedDate': lastObservedDate,
  };

  factory DailyProgress.fromJson(Map<String, dynamic> json) => DailyProgress(
    completedDates: (json['completedDates'] as List<dynamic>? ?? const [])
        .cast<String>()
        .toSet(),
    bestScores: _intMap(json['bestScores']),
    currentStreak: json['currentStreak'] as int? ?? 0,
    longestStreak: json['longestStreak'] as int? ?? 0,
    lastCompletedDate: json['lastCompletedDate'] as String?,
    lastObservedDate: json['lastObservedDate'] as String?,
  );

  @override
  List<Object?> get props => [
    completedDates,
    bestScores,
    currentStreak,
    longestStreak,
    lastCompletedDate,
    lastObservedDate,
  ];
}

class ModeProgressSnapshot extends Equatable {
  const ModeProgressSnapshot({
    this.classic = const ClassicProgress(),
    this.journey = const JourneyProgress(),
    this.daily = const DailyProgress(),
  });

  final ClassicProgress classic;
  final JourneyProgress journey;
  final DailyProgress daily;

  ModeProgressSnapshot copyWith({
    ClassicProgress? classic,
    JourneyProgress? journey,
    DailyProgress? daily,
  }) => ModeProgressSnapshot(
    classic: classic ?? this.classic,
    journey: journey ?? this.journey,
    daily: daily ?? this.daily,
  );

  Map<String, dynamic> toJson() => {
    'schema': 1,
    'classic': classic.toJson(),
    'journey': journey.toJson(),
    'daily': daily.toJson(),
  };

  factory ModeProgressSnapshot.fromJson(Map<String, dynamic> json) =>
      ModeProgressSnapshot(
        classic: ClassicProgress.fromJson(
          Map<String, dynamic>.from(json['classic'] as Map? ?? const {}),
        ),
        journey: JourneyProgress.fromJson(
          Map<String, dynamic>.from(json['journey'] as Map? ?? const {}),
        ),
        daily: DailyProgress.fromJson(
          Map<String, dynamic>.from(json['daily'] as Map? ?? const {}),
        ),
      );

  @override
  List<Object?> get props => [classic, journey, daily];
}

String utcDateKey(DateTime value) {
  final date = value.toUtc();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

DateTime utcDateFromKey(String key) {
  final parts = key.split('-').map(int.parse).toList();
  return DateTime.utc(parts[0], parts[1], parts[2]);
}

DailyChallenge dailyChallengeFor(
  DateTime utcDate, {
  String configurationVersion = 'v1',
}) {
  final key = utcDateKey(utcDate);
  var hash = 2166136261;
  for (final codeUnit in '$configurationVersion:$key'.codeUnits) {
    hash = ((hash ^ codeUnit) * 16777619) & 0x7fffffff;
  }
  final objective = switch (hash % 3) {
    0 => JourneyObjective(
      type: JourneyObjectiveType.score,
      targetValue: 35 + hash % 35,
    ),
    1 => JourneyObjective(
      type: JourneyObjectiveType.lines,
      targetValue: 1 + hash % 2,
    ),
    _ => JourneyObjective(
      type: JourneyObjectiveType.coloredCells,
      targetValue: 10 + hash % 10,
    ),
  };
  final initial = List.generate(
    Board.size,
    (row) => List<int?>.filled(Board.size, null),
  );
  if (objective.type == JourneyObjectiveType.lines) {
    for (var col = 0; col < Board.size - 1; col++) {
      initial[0][col] = (hash + col) % 7;
    }
  }
  return DailyChallenge(
    dateKey: key,
    seed: hash,
    objective: objective,
    initialBoard: Board(initial),
    moveLimit: objective.type == JourneyObjectiveType.lines ? 8 : 14,
    configurationVersion: configurationVersion,
  );
}

Map<String, int> _intMap(Object? value) => {
  for (final entry in (value as Map<Object?, Object?>? ?? const {}).entries)
    if (entry.key is String && entry.value is int)
      entry.key! as String: entry.value! as int,
};

int _dateDifference(String from, String to) =>
    utcDateFromKey(to).difference(utcDateFromKey(from)).inDays;

const _unset = Object();
