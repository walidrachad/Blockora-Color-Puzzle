import 'dart:convert';

import 'game_modes.dart';
import 'models.dart';

/// Locally-defined Journey content. Keeping the catalog as immutable data makes
/// the engine deterministic and avoids a network dependency for level play.
List<JourneyLevel> journeyLevels = List.unmodifiable(
  List<JourneyLevel>.generate(30, _buildLevel),
);

JourneyLevel journeyLevelById(String id) => journeyLevels.firstWhere(
  (level) => level.id == id,
  orElse: () => journeyLevels.first,
);

JourneyLevel _buildLevel(int index) {
  final number = index + 1;
  final type = switch (index % 3) {
    0 => JourneyObjectiveType.score,
    1 => JourneyObjectiveType.lines,
    _ => JourneyObjectiveType.coloredCells,
  };
  final target = switch (type) {
    JourneyObjectiveType.score => 12 + index * 8,
    JourneyObjectiveType.lines => 1 + index ~/ 12,
    JourneyObjectiveType.coloredCells => 8 + index * 2,
  };
  final objective = JourneyObjective(type: type, targetValue: target);
  final thresholds = switch (type) {
    JourneyObjectiveType.score => JourneyStarThresholds(
      one: target,
      two: target + 10 + index,
      three: target + 24 + index * 2,
    ),
    JourneyObjectiveType.lines => JourneyStarThresholds(
      one: target,
      two: target + 1,
      three: target + 2,
    ),
    JourneyObjectiveType.coloredCells => JourneyStarThresholds(
      one: target,
      two: target + 4,
      three: target + 8,
    ),
  };
  final rules = switch (type) {
    JourneyObjectiveType.score => const ['dot', 'duo_h', 'duo_v', 'trio_h'],
    JourneyObjectiveType.lines => const ['dot'],
    JourneyObjectiveType.coloredCells => const [
      'duo_h',
      'duo_v',
      'trio_h',
      'trio_v',
      'quad_h',
    ],
  };
  return JourneyLevel(
    id: 'journey_${number.toString().padLeft(2, '0')}',
    levelNumber: number,
    initialBoard: _initialBoard(type, index),
    randomSeed: 9301 + index * 7919,
    objective: objective,
    moveLimit: index % 4 == 0 ? 6 + index ~/ 4 : null,
    availablePieceRules: rules,
    starThresholds: thresholds,
    reward: index % 5 == 4 ? 'New color palette' : 'Star cache +${number * 5}',
  );
}

Board _initialBoard(JourneyObjectiveType type, int index) {
  final cells = List.generate(
    Board.size,
    (row) => List<int?>.filled(Board.size, null),
  );
  if (type == JourneyObjectiveType.lines) {
    for (var col = 0; col < Board.size - 1; col++) {
      cells[index % 2][col] = (index + col) % 7;
    }
  } else if (index >= 9) {
    final count = (index % 5) + 2;
    for (var i = 0; i < count; i++) {
      cells[Board.size - 1][i] = (index + i) % 7;
    }
  }
  return Board(cells);
}


// Remote Config key: blockora_levels_json. The fallback is intentionally playable offline.
// Only score targets are accepted remotely; shape rules remain the canonical library.
const defaultLevelTargets = <int>[500, 1000, 1800, 2800, 4000, 5500, 7500, 10000, 13000, 17000];

List<JourneyLevel> _scoreLevels(List<int> targets) => List.unmodifiable(
  List.generate(targets.length, (index) {
    final number = index + 1;
    final target = targets[index];
    return JourneyLevel(
      id: 'journey_${number.toString().padLeft(2, '0')}',
      levelNumber: number,
      initialBoard: Board(),
      randomSeed: 20261019 + index * 7919,
      objective: JourneyObjective(type: JourneyObjectiveType.score, targetValue: target),
      moveLimit: null,
      availablePieceRules: PieceLibrary.byId.keys.toList(growable: false),
      starThresholds: JourneyStarThresholds(one: target, two: target, three: target),
      reward: 'Level completed',
    );
  }),
);

/// Returns false for malformed, duplicate, non-increasing or unsafe remote targets.
bool applyLevelsJson(String raw) {
  try {
    final payload = jsonDecode(raw);
    if (payload is! Map || payload['levels'] is! List) return false;
    final entries = payload['levels'] as List;
    if (entries.isEmpty || entries.length > 100) return false;
    final targets = <int>[];
    for (var i = 0; i < entries.length; i++) {
      final item = entries[i];
      if (item is! Map || item['level'] != i + 1 || item['target'] is! int) return false;
      final value = item['target'] as int;
      if (value < 1 || value > 100000000 || (targets.isNotEmpty && value <= targets.last)) {
        return false;
      }
      targets.add(value);
    }
    journeyLevels = _scoreLevels(targets);
    return true;
  } catch (_) {
    return false;
  }
}

/// Default catalog for new Level Mode; older Journey content remains in source.
void useDefaultScoreLevels() {
  journeyLevels = _scoreLevels(defaultLevelTargets);
}
