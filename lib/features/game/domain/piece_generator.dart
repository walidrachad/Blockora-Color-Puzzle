import 'game_rules.dart';
import 'models.dart';

/// Seedable generator used by production and tests. A batch is chosen once,
/// then held until every slot is consumed. No displayed piece is mutated.
class PieceGenerator {
  PieceGenerator({int? seed})
    : _state = (seed ?? DateTime.now().microsecondsSinceEpoch) & 0x7fffffff;

  PieceGenerator.fromState(this._state);

  int _state;
  int get state => _state;

  int _next() {
    _state = (1103515245 * _state + 12345) & 0x7fffffff;
    return _state;
  }

  Piece _pick([Iterable<String>? allowedPieceIds]) {
    final allowed = allowedPieceIds == null
        ? PieceLibrary.all
        : PieceLibrary.all
              .where((piece) => allowedPieceIds.contains(piece.id))
              .toList(growable: false);
    final source = allowed.isEmpty ? PieceLibrary.all : allowed;
    final weighted = <Piece>[];
    for (final piece in source) {
      // Small pieces are common enough to keep early boards playable; large
      // pieces remain frequent enough to create meaningful planning choices.
      final weight =
          piece.generationWeight ??
          (piece.size <= 2
              ? 10
              : piece.size <= 4
              ? 8
              : piece.size <= 6
              ? 5
              : 3);
      weighted.addAll(List<Piece>.filled(weight, piece));
    }
    return weighted[_next() % weighted.length];
  }

  List<Piece> nextBatch({
    Board? board,
    bool guaranteePlayable = true,
    Iterable<String>? allowedPieceIds,
  }) {
    final batch = [
      _pick(allowedPieceIds),
      _pick(allowedPieceIds),
      _pick(allowedPieceIds),
    ];
    if (!guaranteePlayable || board == null || hasAnyMove(board, batch)) {
      return batch;
    }

    final allowed = allowedPieceIds == null
        ? PieceLibrary.all
        : PieceLibrary.all
              .where((piece) => allowedPieceIds.contains(piece.id))
              .toList(growable: false);
    final playable = (allowed.isEmpty ? PieceLibrary.all : allowed)
        .where((piece) => canPlace(board, piece))
        .toList();
    if (playable.isEmpty) return batch;
    // Fairness is guaranteed at batch creation, not by changing a piece after
    // the player sees it. A seeded pick keeps the fallback deterministic.
    batch[0] = playable[_next() % playable.length];
    return batch;
  }
}
