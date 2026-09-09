import 'package:flutter_test/flutter_test.dart';
import 'package:prism_puzzle/core/ads/ads_config.dart';
import 'package:prism_puzzle/features/game/domain/game_rules.dart';
import 'package:prism_puzzle/features/game/domain/models.dart';
import 'package:prism_puzzle/features/game/domain/revive_policy.dart';

void main() {
  final asym = PieceLibrary.byId['asym']!;
  final dot = PieceLibrary.byId['dot']!;

  test('clear_most_filled_line clears the deterministic fullest row', () {
    var board = Board();
    for (var col = 0; col < 6; col++) {
      board = board.withCell(GridPoint(0, col), 1);
    }
    for (var col = 0; col < 4; col++) {
      board = board.withCell(GridPoint(1, col), 1);
    }
    final result = ConfiguredRevivePolicy().rescue(board, [asym]);
    expect(result.rescuedCells.length, 6);
    expect(result.rescuedCells, contains(const GridPoint(0, 5)));
    expect(hasAnyMove(result.board, [asym]), isTrue);
  });

  test(
    'remove_last_placed_piece uses placement IDs and supports partial cells',
    () {
      final board = Board().place(asym, const GridPoint(0, 0), placementId: 7);
      final result = const ConfiguredRevivePolicy(
        strategy: AdsReviveStrategy.removeLastPlacedPiece,
      ).rescue(board, [asym]);
      expect(result.rescuedCells.length, 4);
      expect(result.board.filledCount, 0);
      expect(hasAnyMove(result.board, [asym]), isTrue);
    },
  );

  test(
    'fallback clears enough deterministic lines when one line is insufficient',
    () {
      final full = Board(
        List.generate(Board.size, (_) => List<int?>.filled(Board.size, 1)),
      );
      final result = const ConfiguredRevivePolicy().rescue(full, [asym]);
      expect(hasAnyMove(result.board, [asym]), isTrue);
      expect(result.rescuedCells, isNotEmpty);
    },
  );

  test('legacy boards without placement IDs still rescue a legal dot move', () {
    final full = Board(
      List.generate(Board.size, (_) => List<int?>.filled(Board.size, 1)),
    );
    final result = const ConfiguredRevivePolicy(
      strategy: AdsReviveStrategy.removeLastPlacedPiece,
    ).rescue(full, [dot]);
    expect(result.rescuedCells.length, 8);
    expect(canPlace(result.board, dot), isTrue);
  });
}
