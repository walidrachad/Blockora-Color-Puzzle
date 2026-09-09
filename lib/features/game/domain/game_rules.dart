import 'models.dart';
import 'package:equatable/equatable.dart';

class PlacementResult {
  const PlacementResult({required this.valid, this.cells = const []});

  final bool valid;
  final List<GridPoint> cells;
}

PlacementResult evaluatePlacement(Board board, Piece piece, GridPoint origin) {
  final placed = <GridPoint>[];
  for (final cell in piece.cells) {
    final target = origin.translate(cell.row, cell.col);
    if (!board.inBounds(target) || board[target] != null) {
      return const PlacementResult(valid: false);
    }
    placed.add(target);
  }
  return PlacementResult(valid: true, cells: placed);
}

bool canPlace(Board board, Piece piece) => anyPlacement(board, piece) != null;

GridPoint? anyPlacement(Board board, Piece piece) {
  for (var row = 0; row < Board.size; row++) {
    for (var col = 0; col < Board.size; col++) {
      final origin = GridPoint(row, col);
      if (evaluatePlacement(board, piece, origin).valid) return origin;
    }
  }
  return null;
}

LineSet detectCompletedLines(Board board) {
  final rows = <int>[];
  final columns = <int>[];
  for (var row = 0; row < Board.size; row++) {
    if (board.cells[row].every((cell) => cell != null)) rows.add(row);
  }
  for (var col = 0; col < Board.size; col++) {
    if ([
      for (var row = 0; row < Board.size; row++) board.cells[row][col],
    ].every((cell) => cell != null)) {
      columns.add(col);
    }
  }
  return LineSet(rows: rows, columns: columns);
}

Set<GridPoint> uniqueClearedCells(LineSet lines) => lines.uniqueCells;

class TurnScore extends Equatable {
  const TurnScore({
    required this.points,
    required this.lines,
    required this.clearedCells,
  });

  final int points;
  final int lines;
  final int clearedCells;

  @override
  List<Object?> get props => [points, lines, clearedCells];
}

/// Score policy:
/// - one point per placed cell;
/// - 100 points per line, with a 40 point bonus for every line after the first;
/// - 10 points per intersection (a cell shared by a cleared row and column);
/// - a combo multiplier of 1 + (combo - 1) * 0.25, capped at 2x.
TurnScore scoreTurn({
  required Piece piece,
  required LineSet lines,
  required int combo,
}) {
  final cleared = lines.uniqueCells.length;
  final intersections = lines.rows.length * lines.columns.length;
  final base =
      piece.size +
      (lines.count * 100) +
      ((lines.count - 1).clamp(0, 99) * 40) +
      intersections * 10;
  final multiplier = lines.count == 0
      ? 1.0
      : (1 + ((combo - 1).clamp(0, 4) * 0.25));
  return TurnScore(
    points: (base * multiplier).round(),
    lines: lines.count,
    clearedCells: cleared,
  );
}

int nextCombo({required int current, required bool clearedLine}) =>
    clearedLine ? current + 1 : 0;

bool hasAnyMove(Board board, Iterable<Piece?> pieces) =>
    pieces.whereType<Piece>().any((piece) => canPlace(board, piece));

bool isGameOver(Board board, Iterable<Piece?> pieces) =>
    pieces.whereType<Piece>().isNotEmpty && !hasAnyMove(board, pieces);

String praiseFor({required int lines, required int combo, required int score}) {
  if (combo >= 4 || lines >= 4 || score >= 1000) return 'Perfect!';
  if (combo >= 3 || lines >= 3) return 'Amazing!';
  if (lines == 2 || combo == 2) return 'Nice Move!';
  if (lines == 1) return 'Great!';
  return 'Keep going';
}
