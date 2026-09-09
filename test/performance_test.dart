import 'package:flutter_test/flutter_test.dart';
import 'package:prism_puzzle/features/game/domain/models.dart';
import 'package:prism_puzzle/features/game/presentation/painters/board_painters.dart';
import 'package:prism_puzzle/features/game/presentation/painters/game_painters.dart';

void main() {
  test('clear particle generation is deterministic and bounded', () {
    final cells = {
      for (var row = 0; row < Board.size; row++)
        for (var col = 0; col < Board.size; col++) GridPoint(row, col),
    };

    final first = buildClearParticles(cells: cells, seed: 42, lines: 8);
    final second = buildClearParticles(cells: cells, seed: 42, lines: 8);

    expect(first, hasLength(120));
    expect(
      first
          .map(
            (particle) => [
              particle.x,
              particle.y,
              particle.vx,
              particle.vy,
              particle.size,
              particle.color,
              particle.square,
            ],
          )
          .toList(),
      equals(
        second
            .map(
              (particle) => [
                particle.x,
                particle.y,
                particle.vx,
                particle.vy,
                particle.size,
                particle.color,
                particle.square,
              ],
            )
            .toList(),
      ),
    );
  });

  test('board geometry exposes stable cached cell bounds', () {
    final geometry = BoardGeometry.fromSize(336);
    final first = geometry.cellRect(const GridPoint(0, 0));
    final last = geometry.cellRect(const GridPoint(7, 7));

    expect(first.left, closeTo(3.15, 0.001));
    expect(first.top, closeTo(3.15, 0.001));
    expect(last.right, lessThanOrEqualTo(336));
    expect(last.bottom, lessThanOrEqualTo(336));
    expect(geometry.blockRect(const GridPoint(0, 0)).outerRect, isNotNull);
  });
}
