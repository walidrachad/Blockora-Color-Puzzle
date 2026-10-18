import 'package:flutter_test/flutter_test.dart';
import 'package:prism_puzzle/features/game/domain/game_rules.dart';
import 'package:prism_puzzle/features/game/domain/models.dart';
import 'package:prism_puzzle/features/game/domain/piece_generator.dart';

String shapeKey(Iterable<GridPoint> cells) => Piece(
  id: 'shape',
  color: 0,
  cells: cells,
).cells.map((cell) => '${cell.row},${cell.col}').join(';');

Set<String> rotations(List<GridPoint> cells) {
  final keys = <String>{};
  for (var turn = 0; turn < 4; turn++) {
    keys.add(shapeKey(cells));
    cells = cells.map((cell) => GridPoint(cell.col, -cell.row)).toList();
  }
  return keys;
}

void main() {
  test('library contains 37 distinct IDs and occupied-cell shapes', () {
    expect(PieceLibrary.all, hasLength(37));
    expect(PieceLibrary.byId, hasLength(37));
    expect(PieceLibrary.byId, isNot(contains('asym')));
    expect(
      PieceLibrary.all.map((piece) => shapeKey(piece.cells)).toSet(),
      hasLength(37),
    );
  });

  test('large and small corners cover all four orientations', () {
    for (final prefix in ['corner_3_', 'corner_']) {
      final corners = PieceLibrary.all.where(
        (piece) =>
            piece.id.startsWith(prefix) &&
            (prefix == 'corner_3_' || !piece.id.startsWith('corner_3_')),
      );
      expect(corners, hasLength(4));
      expect(
        corners.map((piece) => shapeKey(piece.cells)).toSet(),
        rotations(corners.first.cells),
      );
    }
    for (final corner in PieceLibrary.all.where(
      (piece) => piece.id.startsWith('corner_3_'),
    )) {
      expect(corner.size, 5);
      expect(corner.width, 3);
      expect(corner.height, 3);
    }
  });

  test('new vertical stair is the horizontal reflection of stair', () {
    final stair = PieceLibrary.byId['stair']!;
    expect(
      shapeKey(PieceLibrary.byId['stair_mirror']!.cells),
      shapeKey(stair.cells.map((cell) => GridPoint(cell.row, -cell.col))),
    );
  });

  test('diagonals fit around occupied cells inside their bounding box', () {
    final diagonals = PieceLibrary.all.where(
      (piece) => piece.id.startsWith('diagonal_'),
    );
    expect(diagonals, hasLength(4));
    for (final piece in diagonals) {
      expect(piece.width, piece.size);
      expect(piece.height, piece.size);
      expect(piece.size, isIn([2, 3]));
      expect(
        piece.cells.every(
          (cell) => piece.id.endsWith('_down')
              ? cell.row == cell.col
              : cell.row + cell.col == piece.size - 1,
        ),
        isTrue,
      );
      final board = Board(
        List.generate(Board.size, (_) => List<int?>.filled(Board.size, 0)),
      ).clear(piece.cells);
      expect(
        evaluatePlacement(board, piece, const GridPoint(0, 0)).valid,
        isTrue,
      );
      expect(hasAnyMove(board, [piece]), isTrue);
      expect(
        evaluatePlacement(
          board.withCell(piece.cells.first, 0),
          piece,
          const GridPoint(0, 0),
        ).valid,
        isFalse,
      );
    }
  });

  test(
    'every piece places at board corners and rejects overflow and overlap',
    () {
      for (final piece in PieceLibrary.all) {
        for (final row in [0, Board.size - piece.height]) {
          for (final col in [0, Board.size - piece.width]) {
            final origin = GridPoint(row, col);
            expect(
              evaluatePlacement(Board(), piece, origin).valid,
              isTrue,
              reason: piece.id,
            );
            final board = Board().place(piece, origin);
            expect(board.filledCount, piece.size);
            expect(evaluatePlacement(board, piece, origin).valid, isFalse);
          }
        }
        expect(
          evaluatePlacement(
            Board(),
            piece,
            GridPoint(0, Board.size - piece.width + 1),
          ).valid,
          isFalse,
        );
        expect(
          evaluatePlacement(
            Board(),
            piece,
            GridPoint(Board.size - piece.height + 1, 0),
          ).valid,
          isFalse,
        );
        expect(Piece.fromJson(piece.toJson()), piece);
        expect(
          scoreTurn(
            piece: piece,
            lines: const LineSet(rows: [], columns: []),
            combo: 0,
          ).points,
          piece.size,
        );
      }
    },
  );

  test('production generator can deal every library piece without asym', () {
    final generator = PieceGenerator(seed: 77);
    final seen = <String>{};
    for (var batch = 0; batch < 500; batch++) {
      seen.addAll(generator.nextBatch().map((piece) => piece.id));
    }
    expect(seen, PieceLibrary.byId.keys.toSet());
  });

  test(
    'old four-cell asym save migrates to l_down and drops duplicate weight',
    () {
      final json = PieceLibrary.byId['l_down']!.toJson()
        ..['id'] = 'asym'
        ..['generationWeight'] = 5;
      final restored = Piece.fromJson(json);
      expect(restored, PieceLibrary.byId['l_down']);
      expect(restored.toJson()['id'], 'l_down');
    },
  );
}
