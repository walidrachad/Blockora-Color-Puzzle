import 'package:flutter_test/flutter_test.dart';

import 'package:prism_puzzle/core/services/services.dart';
import 'package:prism_puzzle/features/game/domain/models.dart';

void main() {
  test(
    'saved games round trip with schema, board, pieces, and settings data',
    () {
      final saved = SavedGame(
        board: Board().withCell(const GridPoint(2, 4), 6),
        pieces: [PieceLibrary.byId['t_up'], null, PieceLibrary.byId['dot']],
        score: 212,
        best: 800,
        combo: 2,
        generatorState: 1234,
        reviveUsed: true,
      );
      final restored = SavedGame.fromJson(saved.toJson());
      expect(restored.board, saved.board);
      expect(restored.pieces, saved.pieces);
      expect(restored.score, 212);
      expect(restored.reviveUsed, isTrue);
    },
  );

  test('saved asym pieces restore the four-cell domain shape', () {
    final asym = PieceLibrary.byId['asym']!;
    final saved = SavedGame(
      board: Board(),
      pieces: [asym, null, null],
      score: 4,
      best: 4,
      combo: 0,
      generatorState: 1234,
      reviveUsed: false,
    );

    final restored = SavedGame.fromJson(saved.toJson()).pieces.first!;
    expect(restored.id, 'asym');
    expect(restored.cells, asym.cells);
    expect(restored.size, 4);
    expect(restored.width, 2);
    expect(restored.height, 3);
  });

  test('placement IDs survive persistence for last-piece revive', () {
    final board = Board().place(
      PieceLibrary.byId['asym']!,
      const GridPoint(0, 0),
      placementId: 42,
    );
    final saved = SavedGame(
      board: board,
      pieces: [PieceLibrary.byId['asym'], null, null],
      score: 4,
      best: 4,
      combo: 0,
      generatorState: 9,
      reviveUsed: false,
    );
    final restored = SavedGame.fromJson(saved.toJson());
    expect(restored.board.maxPlacementId, 42);
    expect(restored.board.placementIds[0][0], 42);
    expect(restored.board.placementIds[2][1], 42);
  });

  test('legacy asym saves migrate away from the retired fifth cell', () {
    final restored = Piece.fromJson({
      'id': 'asym',
      'color': 2,
      'cells': [
        {'r': 0, 'c': 0},
        {'r': 0, 'c': 1},
        {'r': 1, 'c': 1},
        {'r': 1, 'c': 2},
        {'r': 2, 'c': 1},
      ],
    });

    expect(restored.cells, PieceLibrary.byId['asym']!.cells);
    expect(restored.size, 4);
    expect(restored.cells, isNot(contains(const GridPoint(1, 2))));
  });

  test('preferences default safely when optional values are missing', () {
    final preferences = AppPreferences.fromJson(<String, dynamic>{});
    expect(preferences.sound, isTrue);
    expect(preferences.music, isTrue);
    expect(preferences.vibration, isTrue);
  });

  test('unsupported schemas fail safely for the storage boundary', () {
    expect(
      () => SavedGame.fromJson(<String, dynamic>{'schema': 99}),
      throwsFormatException,
    );
  });
}
