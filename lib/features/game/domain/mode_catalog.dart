import 'game_modes.dart';
import 'models.dart';

/// Locally-defined Journey content. Keeping the catalog as immutable data makes
/// the engine deterministic and avoids a network dependency for level play.
final List<JourneyLevel> journeyLevels = List.unmodifiable(
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
