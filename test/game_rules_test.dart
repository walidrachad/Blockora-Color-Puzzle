import 'package:flutter_test/flutter_test.dart';

import 'package:prism_puzzle/features/game/domain/game_rules.dart';
import 'package:prism_puzzle/features/game/domain/models.dart';
import 'package:prism_puzzle/features/game/domain/piece_generator.dart';
import 'package:prism_puzzle/features/game/domain/revive_policy.dart';

void main() {
  final dot = PieceLibrary.byId['dot']!;
  final duo = PieceLibrary.byId['duo_h']!;
  final asym = PieceLibrary.byId['asym']!;

  test('all piece shapes normalize their minimum row and column to zero', () {
    final piece = Piece(
      id: 'test',
      color: 1,
      cells: [const GridPoint(4, 8), const GridPoint(3, 7)],
    );
    expect(piece.cells, [const GridPoint(0, 0), const GridPoint(1, 1)]);
    for (final candidate in PieceLibrary.all) {
      expect(
        candidate.cells.every((cell) => cell.row >= 0 && cell.col >= 0),
        isTrue,
      );
      expect(candidate.cells.toSet().length, candidate.cells.length);
    }
  });

  test(
    'placement accepts an empty in-bounds origin and rejects edges and overlap',
    () {
      final board = Board();
      expect(
        evaluatePlacement(board, duo, const GridPoint(0, 0)).valid,
        isTrue,
      );
      expect(
        evaluatePlacement(board, duo, const GridPoint(0, 7)).valid,
        isFalse,
      );
      expect(
        evaluatePlacement(board, duo, const GridPoint(-1, 0)).valid,
        isFalse,
      );
      expect(
        evaluatePlacement(
          board.withCell(const GridPoint(0, 1), 2),
          duo,
          const GridPoint(0, 0),
        ).valid,
        isFalse,
      );
    },
  );

  test('asym is the four-cell replacement with the requested bounds', () {
    expect(asym.cells, [
      const GridPoint(0, 0),
      const GridPoint(0, 1),
      const GridPoint(1, 1),
      const GridPoint(2, 1),
    ]);
    expect(asym.cells.toSet().length, 4);
    expect(asym.size, 4);
    expect(asym.width, 2);
    expect(asym.height, 3);
    expect(asym.generationWeight, 5);
    expect(asym.cells, isNot(contains(const GridPoint(1, 2))));
  });

  test('asym placement uses exactly four cells at every boundary', () {
    final topLeft = evaluatePlacement(Board(), asym, const GridPoint(0, 0));
    expect(topLeft.valid, isTrue);
    expect(topLeft.cells, [
      const GridPoint(0, 0),
      const GridPoint(0, 1),
      const GridPoint(1, 1),
      const GridPoint(2, 1),
    ]);

    final bottomRight = evaluatePlacement(
      Board(),
      asym,
      const GridPoint(Board.size - 3, Board.size - 2),
    );
    expect(bottomRight.valid, isTrue);
    expect(bottomRight.cells, [
      const GridPoint(5, 6),
      const GridPoint(5, 7),
      const GridPoint(6, 7),
      const GridPoint(7, 7),
    ]);

    expect(
      evaluatePlacement(Board(), asym, const GridPoint(5, 7)).valid,
      isFalse,
    );
    expect(
      evaluatePlacement(Board(), asym, const GridPoint(6, 6)).valid,
      isFalse,
    );
    expect(
      evaluatePlacement(
        Board().withCell(const GridPoint(1, 1), 7),
        asym,
        const GridPoint(0, 0),
      ).valid,
      isFalse,
    );
    // The old fifth cell was (1, 2). It must not participate in validation.
    expect(
      evaluatePlacement(
        Board().withCell(const GridPoint(1, 2), 7),
        asym,
        const GridPoint(0, 0),
      ).valid,
      isTrue,
    );
  });

  test('asym drives scoring, move scans, game over, and revive', () {
    expect(
      scoreTurn(
        piece: asym,
        lines: const LineSet(rows: [], columns: []),
        combo: 1,
      ).points,
      4,
    );
    expect(hasAnyMove(Board(), [asym]), isTrue);

    final full = Board(
      List.generate(Board.size, (_) => List<int?>.filled(Board.size, 1)),
    );
    expect(isGameOver(full, [asym]), isTrue);

    final blocked = full
        .withCell(const GridPoint(5, 6), null)
        .withCell(const GridPoint(5, 7), null)
        .withCell(const GridPoint(6, 7), null)
        .withCell(const GridPoint(7, 7), null);
    expect(hasAnyMove(blocked, [asym]), isTrue);
    final revived = MinimalRevivePolicy().rescue(full, [asym]);
    expect(revived.pieceId, 'asym');
    expect(revived.rescuedCells.length, 4);
    expect(canPlace(revived.board, asym), isTrue);
  });

  test('detects rows, columns, and unique cells for an intersection', () {
    var board = Board();
    for (var i = 0; i < Board.size; i++) {
      board = board.withCell(const GridPoint(0, 0).translate(0, i), 1);
      board = board.withCell(const GridPoint(0, 0).translate(i, 0), 2);
    }
    final lines = detectCompletedLines(board);
    expect(lines.rows, [0]);
    expect(lines.columns, [0]);
    expect(uniqueClearedCells(lines).length, 15);
  });

  test(
    'scoring is deterministic and combo multiplier is applied once per turn',
    () {
      final oneLine = const LineSet(rows: [0], columns: []);
      expect(scoreTurn(piece: dot, lines: oneLine, combo: 1).points, 101);
      expect(scoreTurn(piece: dot, lines: oneLine, combo: 2).points, 126);
      expect(
        scoreTurn(
          piece: dot,
          lines: const LineSet(rows: [], columns: []),
          combo: 4,
        ).points,
        1,
      );
      expect(nextCombo(current: 2, clearedLine: true), 3);
      expect(nextCombo(current: 3, clearedLine: false), 0);
    },
  );

  test('seeded generators reproduce the same three-piece batches', () {
    final first = PieceGenerator(seed: 77);
    final second = PieceGenerator(seed: 77);
    expect(
      first.nextBatch().map((piece) => piece.id),
      second.nextBatch().map((piece) => piece.id),
    );
    expect(first.state, second.state);
  });

  test(
    'fairness mode makes a new batch playable when the board still has room',
    () {
      final board = Board(
        List.generate(Board.size, (_) => List<int?>.filled(Board.size, 4))
          ..[7][7] = null,
      );
      final batch = PieceGenerator(seed: 22).nextBatch(board: board);
      expect(hasAnyMove(board, batch), isTrue);
    },
  );

  test(
    'game over only occurs when an unused piece exists and no piece fits',
    () {
      final full = Board(
        List.generate(Board.size, (_) => List<int?>.filled(Board.size, 1)),
      );
      expect(isGameOver(full, [dot, null, null]), isTrue);
      expect(isGameOver(Board(), [null, null, null]), isFalse);
      var oneHole = full.withCell(const GridPoint(7, 7), null);
      expect(isGameOver(oneHole, [dot, duo, null]), isFalse);
      expect(hasAnyMove(oneHole, [dot]), isTrue);
    },
  );

  test(
    'minimal revive removes the fewest blockers and guarantees a displayed move',
    () {
      final full = Board(
        List.generate(Board.size, (_) => List<int?>.filled(Board.size, 1)),
      );
      final result = MinimalRevivePolicy().rescue(full, [dot, duo, null]);
      expect(result.rescuedCells.length, 1);
      expect(canPlace(result.board, dot), isTrue);
      expect(canPlace(result.board, dot), isTrue);
    },
  );
}
