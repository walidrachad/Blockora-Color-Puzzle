import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/models.dart';
import 'game_painters.dart';
import 'block_skin.dart';

const _emptyCellGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xff182459), Color(0xff111a45)],
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
    this.clearingCells = const {},
  }) : super(repaint: BlockSkin.instance);

  final Set<GridPoint> clearingCells;
  final Board board;
  final BoardGeometry geometry;
  final bool showCoordinates;

  @override
  void paint(Canvas canvas, Size size) {
    StaticBoardGridPainter(
      geometry: geometry,
      showCoordinates: showCoordinates,
    ).paint(canvas, size);
    BoardBlocksPainter(
      board: board,
      geometry: geometry,
      hiddenCells: clearingCells,
    ).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant BoardStaticPainter oldDelegate) =>
      oldDelegate.board != board ||
      oldDelegate.clearingCells != clearingCells ||
      oldDelegate.geometry != geometry ||
      oldDelegate.showCoordinates != showCoordinates;
}

class BoardBlocksPainter extends CustomPainter {
  BoardBlocksPainter({
    required this.board,
    required this.geometry,
    this.hiddenCells = const {},
  }) : super(repaint: BlockSkin.instance);

  final Board board;
  final BoardGeometry geometry;
  final Set<GridPoint> hiddenCells;

  @override
  void paint(Canvas canvas, Size size) {
    for (var row = 0; row < Board.size; row++) {
      for (var col = 0; col < Board.size; col++) {
        final value = board.cells[row][col];
        final point = GridPoint(row, col);
        if (value == null || hiddenCells.contains(point)) continue;
        BlockSkin.instance.paint(canvas, geometry.cellRect(point), value);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BoardBlocksPainter oldDelegate) =>
      oldDelegate.board != board ||
      oldDelegate.geometry != geometry ||
      oldDelegate.hiddenCells != hiddenCells;
}

class BoardEffectsPainter extends CustomPainter {
  BoardEffectsPainter({
    required this.geometry,
    this.board,
    this.reducedMotion = false,
    this.previewPiece,
    this.previewOrigin,
    this.previewValid = false,
    this.turn,
    this.particles = const [],
    this.clearProgress = 0,
  });

  final BoardGeometry geometry;
  final Board? board;
  final bool reducedMotion;
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

    if (turn != null && clearProgress > 0 && !reducedMotion) {
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
    final rect = geometry.cellRect(point);
    final delay = reducedMotion ? 0.0 : (point.row + point.col) * .012;
    final t = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
    final burst = ((t - .24) / .55).clamp(0.0, 1.0);
    final fade = 1 - Curves.easeIn.transform(burst);
    final colorIndex = board?[point] ?? (point.row + point.col) % 7;
    final color = PrismColors.blockColors[colorIndex % 7];
    final pulse = math.sin((t / .4).clamp(0.0, 1.0) * math.pi);
    final scale = reducedMotion ? 1.0 : (1 + pulse * .16) * (1 - burst * .94);
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.scale(scale);
    final local = Rect.fromCenter(
      center: Offset.zero,
      width: rect.width,
      height: rect.height,
    );
    BlockSkin.instance.paint(canvas, local, colorIndex, opacity: fade);
    shine.color = Colors.white.withValues(alpha: pulse * .7 * fade);
    canvas.drawRRect(
      RRect.fromRectAndRadius(local, Radius.circular(cell * .23)),
      shine,
    );
    canvas.restore();
    if (!reducedMotion && burst > 0 && burst < 1) {
      glow
        ..color = color.withValues(alpha: (1 - burst) * .65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = cell * .045
        ..maskFilter = null;
      canvas.drawCircle(rect.center, cell * (.3 + burst * .38), glow);
    }
  }

  void _paintSweep(Canvas canvas, TurnDrawData data, double progress) {
    final cell = geometry.cellSize;
    final t = (progress / .65).clamp(0.0, 1.0);
    final fade = math.sin(t * math.pi);
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: fade * .85)
      ..strokeWidth = cell * .075
      ..strokeCap = StrokeCap.round;
    final glow = Paint()
      ..color = PrismColors.cyan.withValues(alpha: fade * .35)
      ..strokeWidth = cell * .35
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * .15);
    for (final row in data.rows) {
      final y = (row + .5) * cell;
      final from = Offset(geometry.size * math.max(0, t - .35), y);
      final to = Offset(geometry.size * math.min(1, t + .15), y);
      canvas.drawLine(from, to, glow);
      canvas.drawLine(from, to, paint);
    }
    for (final col in data.columns) {
      final x = (col + .5) * cell;
      final from = Offset(x, geometry.size * math.max(0, t - .35));
      final to = Offset(x, geometry.size * math.min(1, t + .15));
      canvas.drawLine(from, to, glow);
      canvas.drawLine(from, to, paint);
    }
  }

  void _paintParticles(Canvas canvas, double progress) {
    if (progress <= .23) return;
    final cell = geometry.cellSize;
    final t = ((progress - .23) / .77).clamp(0.0, 1.0);
    final travel = Curves.easeOutCubic.transform(t);
    final paint = Paint();
    for (final particle in particles) {
      final position = Offset(
        particle.x * cell + particle.vx * cell * travel * 1.5,
        particle.y * cell +
            particle.vy * cell * travel * 1.5 +
            cell * .8 * t * t,
      );
      paint.color = particle.color.withValues(alpha: (1 - t) * .95);
      final radius = particle.size * cell * (1 - t * .65);
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(t * math.pi * (particle.square ? 1 : -1));
      if (particle.square) {
        final star = Path();
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          final r = i.isEven ? radius : radius * .3;
          if (i == 0) {
            star.moveTo(math.cos(a) * r, math.sin(a) * r);
          } else {
            star.lineTo(math.cos(a) * r, math.sin(a) * r);
          }
        }
        canvas.drawPath(star..close(), paint);
      } else {
        canvas.drawCircle(Offset.zero, radius * .48, paint);
      }
      canvas.restore();
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
      oldDelegate.board != board ||
      oldDelegate.reducedMotion != reducedMotion ||
      oldDelegate.previewPiece != previewPiece ||
      oldDelegate.previewOrigin != previewOrigin ||
      oldDelegate.previewValid != previewValid ||
      oldDelegate.turn != turn ||
      oldDelegate.particles != particles ||
      oldDelegate.clearProgress != clearProgress;
}

GridPoint _point(int index) =>
    GridPoint(index ~/ Board.size, index % Board.size);
