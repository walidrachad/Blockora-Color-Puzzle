import '../../../core/ads/ads_config.dart';
import 'game_rules.dart';
import 'models.dart';

class ReviveResult {
  const ReviveResult({
    required this.board,
    required this.rescuedCells,
    required this.pieceId,
  });

  final Board board;
  final List<GridPoint> rescuedCells;
  final String pieceId;
}

abstract class RevivePolicy {
  ReviveResult rescue(Board board, List<Piece?> pieces);
}

/// Production revive policy. A configured strategy performs a predictable,
/// visible rescue first, then removes additional deterministic blockers only
/// when required to guarantee that at least one displayed piece can move.
class ConfiguredRevivePolicy implements RevivePolicy {
  const ConfiguredRevivePolicy({
    this.strategy = AdsReviveStrategy.clearMostFilledLine,
  });

  final AdsReviveStrategy strategy;

  @override
  ReviveResult rescue(Board board, List<Piece?> pieces) {
    var rescued = <GridPoint>{};
    var rescuedBoard = board;
    final displayedPieces = pieces.whereType<Piece>().toList(growable: false);
    String pieceId = displayedPieces.isEmpty ? '' : displayedPieces.first.id;

    if (strategy == AdsReviveStrategy.removeLastPlacedPiece) {
      final lastPlacementId = board.maxPlacementId;
      if (lastPlacementId > 0) {
        final lastPieceCells = <GridPoint>[
          for (var row = 0; row < Board.size; row++)
            for (var col = 0; col < Board.size; col++)
              if (board.placementIds[row][col] == lastPlacementId)
                GridPoint(row, col),
        ];
        rescued.addAll(lastPieceCells);
        rescuedBoard = board.clear(lastPieceCells);
      }
    }

    if (rescued.isEmpty) {
      final line = _mostFilledLine(board);
      if (line != null) {
        rescued.addAll(line.cells);
        rescuedBoard = board.clear(line.cells);
      }
    }

    final usedRows = <int>{};
    final usedColumns = <int>{};
    while (!hasAnyMove(rescuedBoard, pieces) &&
        (usedRows.length + usedColumns.length) < Board.size * 2) {
      final line = _mostFilledLine(
        rescuedBoard,
        excludedRows: usedRows,
        excludedColumns: usedColumns,
      );
      if (line == null || line.occupiedCount == 0) break;
      if (line.row != null) {
        usedRows.add(line.row!);
      } else {
        usedColumns.add(line.column!);
      }
      rescued.addAll(line.cells);
      rescuedBoard = rescuedBoard.clear(line.cells);
    }

    // Sparse or legacy boards may not have enough information for the
    // configured visual rescue. The minimal deterministic fallback guarantees
    // a legal move without inventing a piece or changing the shown tray.
    if (!hasAnyMove(rescuedBoard, pieces)) {
      final fallback = const MinimalRevivePolicy().rescue(rescuedBoard, pieces);
      rescued.addAll(fallback.rescuedCells);
      rescuedBoard = fallback.board;
      if (pieceId.isEmpty) pieceId = fallback.pieceId;
    }

    final sorted = rescued.toList()
      ..sort((a, b) => a.row != b.row ? a.row - b.row : a.col - b.col);
    return ReviveResult(
      board: rescuedBoard,
      rescuedCells: sorted,
      pieceId: pieceId,
    );
  }
}

class _RescueLine {
  const _RescueLine({this.row, this.column, required this.cells});

  final int? row;
  final int? column;
  final List<GridPoint> cells;

  int get occupiedCount => cells.length;
}

_RescueLine? _mostFilledLine(
  Board board, {
  Set<int> excludedRows = const {},
  Set<int> excludedColumns = const {},
}) {
  _RescueLine? best;
  for (var row = 0; row < Board.size; row++) {
    if (excludedRows.contains(row)) continue;
    final cells = [
      for (var col = 0; col < Board.size; col++)
        if (board[GridPoint(row, col)] != null) GridPoint(row, col),
    ];
    if (best == null || cells.length > best.occupiedCount) {
      best = _RescueLine(row: row, cells: cells);
    }
  }
  for (var col = 0; col < Board.size; col++) {
    if (excludedColumns.contains(col)) continue;
    final cells = [
      for (var row = 0; row < Board.size; row++)
        if (board[GridPoint(row, col)] != null) GridPoint(row, col),
    ];
    // Rows win ties because they are considered first. Columns are selected
    // only when they are strictly more occupied than the current best.
    if (best == null || cells.length > best.occupiedCount) {
      best = _RescueLine(column: col, cells: cells);
    }
  }
  return best;
}

/// Deterministic rescue: find the smallest set of occupied cells that blocks
/// any displayed piece at any in-bounds origin, remove only those cells, and
/// let the UI celebrate them as a special rescue clear.
class MinimalRevivePolicy implements RevivePolicy {
  const MinimalRevivePolicy();

  @override
  ReviveResult rescue(Board board, List<Piece?> pieces) {
    Set<GridPoint>? bestBlocked;
    GridPoint? bestOrigin;
    Piece? bestPiece;
    for (final piece in pieces.whereType<Piece>()) {
      for (var row = 0; row < Board.size; row++) {
        for (var col = 0; col < Board.size; col++) {
          final origin = GridPoint(row, col);
          final blockers = <GridPoint>{};
          var inBounds = true;
          for (final cell in piece.cells) {
            final point = origin.translate(cell.row, cell.col);
            if (!board.inBounds(point)) {
              inBounds = false;
              break;
            }
            if (board[point] != null) blockers.add(point);
          }
          if (!inBounds) continue;
          if (bestBlocked == null || blockers.length < bestBlocked.length) {
            bestBlocked = blockers;
            bestOrigin = origin;
            bestPiece = piece;
            if (blockers.isEmpty) break;
          }
        }
        if (bestBlocked?.isEmpty ?? false) break;
      }
      if (bestBlocked?.isEmpty ?? false) break;
    }

    if (bestBlocked == null || bestPiece == null || bestOrigin == null) {
      return ReviveResult(board: board, rescuedCells: const [], pieceId: '');
    }
    final rescued = bestBlocked.toList()
      ..sort((a, b) => a.row != b.row ? a.row - b.row : a.col - b.col);
    return ReviveResult(
      board: board.clear(rescued),
      rescuedCells: rescued,
      pieceId: bestPiece.id,
    );
  }
}
