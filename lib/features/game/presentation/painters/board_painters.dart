import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/models.dart';
import 'game_painters.dart';

const _emptyCellGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xff182459), Color(0xff111a45)],
);
const _clearCellGradient = LinearGradient(
  colors: PrismColors.rainbow,
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const _sweepGradient = LinearGradient(
  colors: [Color(0x00ffffff), Color(0xa6ffffff), Color(0x00ffffff)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

/// Layout-dependent board geometry shared by all board layers and hit testing.
/// It is recreated only when the board's inner size changes.
class BoardGeometry {
  static const contentInset = 6.2;

  BoardGeometry.fromSize(this.size)
    : cellSize = size / Board.size,
      _cellRects = List<Rect>.generate(Board.size * Board.size, (index) {
        final cell = size / Board.size;
        final gap = math.max(2, cell * .075);
        final row = index ~/ Board.size;
        final col = index % Board.size;
        return Rect.fromLTWH(
          col * cell + gap,
          row * cell + gap,
          cell - gap * 2,
          cell - gap * 2,
        );
      }, growable: false),
      _blockRects = List<RRect>.generate(Board.size * Board.size, (index) {
        final cell = size / Board.size;
        final gap = math.max(2, cell * .075);
        final row = index ~/ Board.size;
        final col = index % Board.size;
        final rect = Rect.fromLTWH(
          col * cell + gap,
          row * cell + gap,
          cell - gap * 2,
          cell - gap * 2,
        );
        return RRect.fromRectAndRadius(rect, Radius.circular(cell * .18));
      }, growable: false),
      _bottomRects = List<RRect>.generate(Board.size * Board.size, (index) {
        final cell = size / Board.size;
        final gap = math.max(2, cell * .075);
        final row = index ~/ Board.size;
        final col = index % Board.size;
        final rect = Rect.fromLTWH(
          col * cell + gap,
          row * cell + gap,
          cell - gap * 2,
          cell - gap * 2,
        );
        return RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rect.left,
            rect.bottom - cell * .08,
            rect.width,
            cell * .08,
          ),
          Radius.circular(cell * .04),
        );
      }, growable: false),
      _clearGlowRects = List<RRect>.generate(Board.size * Board.size, (index) {
        final cell = size / Board.size;
        final gap = math.max(2, cell * .075);
        final row = index ~/ Board.size;
        final col = index % Board.size;
        final rect = Rect.fromLTWH(
          col * cell + gap,
          row * cell + gap,
          cell - gap * 2,
          cell - gap * 2,
        );
        return RRect.fromRectAndRadius(
          rect.inflate(cell * .05),
          Radius.circular(cell * .2),
        );
      }, growable: false),
      _clearFillRects = List<RRect>.generate(Board.size * Board.size, (index) {
        final cell = size / Board.size;
        final gap = math.max(2, cell * .075);
        final row = index ~/ Board.size;
        final col = index % Board.size;
        final rect = Rect.fromLTWH(
          col * cell + gap,
          row * cell + gap,
          cell - gap * 2,
          cell - gap * 2,
        );
        return RRect.fromRectAndRadius(
          rect.deflate(cell * .015),
          Radius.circular(cell * .2),
        );
      }, growable: false);

  final double size;
  final double cellSize;
  final List<Rect> _cellRects;
  final List<RRect> _blockRects;
  final List<RRect> _bottomRects;
  final List<RRect> _clearGlowRects;
  final List<RRect> _clearFillRects;

  int index(GridPoint point) => point.row * Board.size + point.col;

  Rect cellRect(GridPoint point) => _cellRects[index(point)];

  RRect blockRect(GridPoint point) => _blockRects[index(point)];

  RRect bottomRect(GridPoint point) => _bottomRects[index(point)];

  RRect clearGlowRect(GridPoint point) => _clearGlowRects[index(point)];

  RRect clearFillRect(GridPoint point) => _clearFillRects[index(point)];

  Rect previewRect(GridPoint point) {
    final cell = cellSize;
    return Rect.fromLTWH(
      point.col * cell + cell * .10,
      point.row * cell + cell * .10,
      cell * .80,
      cell * .80,
    );
  }
}

class StaticBoardGridPainter extends CustomPainter {
  StaticBoardGridPainter({
    required this.geometry,
    this.showCoordinates = false,
  });

  final BoardGeometry geometry;
  final bool showCoordinates;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var index = 0; index < Board.size * Board.size; index++) {
      paint.shader = _emptyCellGradient.createShader(
        geometry.cellRect(_point(index)),
      );
      canvas.drawRRect(geometry.blockRect(_point(index)), paint);
      if (showCoordinates) {
        final point = _point(index);
        final textPainter = TextPainter(
          text: TextSpan(
            text: '${point.row},${point.col}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .25),
              fontSize: geometry.cellSize * .16,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        textPainter.paint(
          canvas,
          geometry.cellRect(point).topLeft + const Offset(2, 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant StaticBoardGridPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.showCoordinates != showCoordinates;
}

/// One cached board surface for the static grid and occupied blocks. Keeping
/// these together avoids an extra compositing layer while still isolating the
/// board from the high-frequency effects surface below it.
class BoardStaticPainter extends CustomPainter {
  BoardStaticPainter({
    required this.board,
    required this.geometry,
    this.showCoordinates = false,
  });

  final Board board;
  final BoardGeometry geometry;
  final bool showCoordinates;

  @override
  void paint(Canvas canvas, Size size) {
    StaticBoardGridPainter(
      geometry: geometry,
      showCoordinates: showCoordinates,
    ).paint(canvas, size);
    BoardBlocksPainter(board: board, geometry: geometry).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant BoardStaticPainter oldDelegate) =>
      oldDelegate.board != board ||
      oldDelegate.geometry != geometry ||
      oldDelegate.showCoordinates != showCoordinates;
}

class BoardBlocksPainter extends CustomPainter {
  BoardBlocksPainter({required this.board, required this.geometry});

  final Board board;
  final BoardGeometry geometry;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final highlight = Paint()
      ..color = Colors.white.withValues(alpha: .25)
      ..strokeWidth = math.max(1.5, geometry.cellSize * .035)
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final bottom = Paint();

    for (var row = 0; row < Board.size; row++) {
      for (var col = 0; col < Board.size; col++) {
        final value = board.cells[row][col];
        if (value == null) continue;
        final point = GridPoint(row, col);
        final rect = geometry.cellRect(point);
        final color =
            PrismColors.blockColors[value % PrismColors.blockColors.length];
        paint.shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: .98), color.withValues(alpha: .72)],
        ).createShader(rect);
        canvas.drawRRect(geometry.blockRect(point), paint);
        canvas.drawLine(
          Offset(
            rect.left + geometry.cellSize * .16,
            rect.top + geometry.cellSize * .16,
          ),
          Offset(
            rect.right - geometry.cellSize * .18,
            rect.top + geometry.cellSize * .16,
          ),
          highlight,
        );
        bottom.color = color.withValues(alpha: .34);
        canvas.drawRRect(geometry.bottomRect(point), bottom);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BoardBlocksPainter oldDelegate) =>
      oldDelegate.board != board || oldDelegate.geometry != geometry;
}

class BoardEffectsPainter extends CustomPainter {
  BoardEffectsPainter({
    required this.geometry,
    this.previewPiece,
    this.previewOrigin,
    this.previewValid = false,
    this.turn,
    this.particles = const [],
    this.clearProgress = 0,
  });

  final BoardGeometry geometry;
  final Piece? previewPiece;
  final GridPoint? previewOrigin;
  final bool previewValid;
  final TurnDrawData? turn;
  final List<ClearParticle> particles;
  final double clearProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = geometry.cellSize;
    final clearGlow = Paint()
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * .18);
    final clearFill = Paint();
    final clearShine = Paint();
    for (final point in turn?.clearCells ?? const <GridPoint>{}) {
      _paintClearingCell(
        canvas,
        point,
        clearProgress,
        clearGlow,
        clearFill,
        clearShine,
      );
    }

    if (previewPiece != null && previewOrigin != null) {
      _paintPreview(canvas, previewPiece!, previewOrigin!, previewValid);
    }

    if (turn != null && clearProgress > 0) {
      _paintSweep(canvas, turn!, clearProgress);
      _paintParticles(canvas, clearProgress);
    }
  }

  void _paintClearingCell(
    Canvas canvas,
    GridPoint point,
    double progress,
    Paint glow,
    Paint fill,
    Paint shine,
  ) {
    final cell = geometry.cellSize;
    final wave =
        ((progress * 1.35 - ((point.row + point.col) % 7) * .035).clamp(
          0,
          1,
        )).toDouble();
    final fade = (1 - ((wave - .60) / .40).clamp(0, 1)).toDouble();
    final color = PrismColors
        .rainbow[(point.row * 3 + point.col * 2) % PrismColors.rainbow.length];
    glow.color = color.withValues(alpha: .33 * fade);
    canvas.drawRRect(geometry.clearGlowRect(point), glow);
    fill
      ..shader = _clearCellGradient.createShader(geometry.cellRect(point))
      ..color = color.withValues(alpha: fade);
    canvas.drawRRect(geometry.clearFillRect(point), fill);
    if (wave > .45) {
      shine.color = Colors.white.withValues(alpha: .72 * fade);
      canvas.drawCircle(
        geometry.cellRect(point).center,
        cell * .10 * math.min(1, (wave - .45) * 2.2),
        shine,
      );
    }
  }

  void _paintSweep(Canvas canvas, TurnDrawData data, double progress) {
    final cell = geometry.cellSize;
    final paint = Paint()
      ..shader = _sweepGradient.createShader(
        Rect.fromLTWH(0, 0, geometry.size, geometry.size),
      )
      ..blendMode = BlendMode.screen;
    final offset = progress * geometry.size * 1.3 - geometry.size * .25;
    for (final row in data.rows) {
      canvas.drawRect(
        Rect.fromLTWH(offset, row * cell, cell * .55, cell),
        paint,
      );
    }
    for (final col in data.columns) {
      canvas.drawRect(
        Rect.fromLTWH(col * cell, offset, cell, cell * .55),
        paint,
      );
    }
  }

  void _paintParticles(Canvas canvas, double progress) {
    final cell = geometry.cellSize;
    final paint = Paint();
    final t = ((progress - .14) / .86).clamp(0, 1).toDouble();
    final opacity = (1 - t).clamp(0, 1).toDouble();
    for (final particle in particles) {
      final position = Offset(
        particle.x * cell + particle.vx * cell * t,
        particle.y * cell + particle.vy * cell * t + cell * .78 * t * t,
      );
      paint.color = particle.color.withValues(alpha: opacity * .88);
      final particleSize = particle.size * cell * (1 - t * .35);
      if (particle.square) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: position,
              width: particleSize,
              height: particleSize,
            ),
            Radius.circular(particleSize * .22),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(position, particleSize * .5, paint);
      }
    }
  }

  void _paintPreview(Canvas canvas, Piece piece, GridPoint origin, bool valid) {
    final cell = geometry.cellSize;
    final color = valid ? PrismColors.cyan : PrismColors.orange;
    final fill = Paint()..color = color.withValues(alpha: valid ? .48 : .22);
    final edge = Paint()
      ..color = color.withValues(alpha: .88)
      ..style = PaintingStyle.stroke
      ..strokeWidth = cell * .035;
    final cross = Paint()
      ..color = PrismColors.orange.withValues(alpha: .9)
      ..strokeWidth = cell * .035;
    for (final local in piece.cells) {
      final point = GridPoint(origin.row + local.row, origin.col + local.col);
      if (point.row < 0 ||
          point.row >= Board.size ||
          point.col < 0 ||
          point.col >= Board.size) {
        continue;
      }
      final rect = geometry.previewRect(point);
      final rrect = RRect.fromRectAndRadius(rect, Radius.circular(cell * .18));
      canvas.drawRRect(rrect, fill);
      canvas.drawRRect(rrect, edge);
      if (!valid) {
        canvas.drawLine(
          rect.topLeft + Offset(cell * .17, cell * .17),
          rect.bottomRight - Offset(cell * .17, cell * .17),
          cross,
        );
        canvas.drawLine(
          rect.topRight + Offset(-cell * .17, cell * .17),
          rect.bottomLeft + Offset(cell * .17, -cell * .17),
          cross,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant BoardEffectsPainter oldDelegate) =>
      oldDelegate.geometry != geometry ||
      oldDelegate.previewPiece != previewPiece ||
      oldDelegate.previewOrigin != previewOrigin ||
      oldDelegate.previewValid != previewValid ||
      oldDelegate.turn != turn ||
      oldDelegate.particles != particles ||
      oldDelegate.clearProgress != clearProgress;
}

GridPoint _point(int index) =>
    GridPoint(index ~/ Board.size, index % Board.size);
