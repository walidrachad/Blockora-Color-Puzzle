import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/models.dart';

class TurnDrawData {
  const TurnDrawData({
    required this.clearCells,
    required this.rows,
    required this.columns,
  });

  final Set<GridPoint> clearCells;
  final List<int> rows;
  final List<int> columns;
}

class ClearParticle {
  const ClearParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.size,
    required this.color,
    required this.square,
  });

  final double x;
  final double y;
  final double vx;
  final double vy;
  final double size;
  final Color color;
  final bool square;
}

List<ClearParticle> buildClearParticles({
  required Set<GridPoint> cells,
  required int seed,
  required int lines,
}) {
  if (cells.isEmpty) return const [];
  final random = math.Random(seed);
  final count = math.min(
    120,
    math.min(28 + math.max(0, lines - 1) * 18, cells.length * 5),
  );
  final sources = cells.toList(growable: false);
  return List<ClearParticle>.generate(count, (index) {
    final source = sources[random.nextInt(sources.length)];
    final angle = random.nextDouble() * math.pi * 2;
    final speed = .45 + random.nextDouble() * 1.5;
    return ClearParticle(
      x: source.col + .5,
      y: source.row + .5,
      vx: math.cos(angle) * speed,
      vy: math.sin(angle) * speed,
      size: .08 + random.nextDouble() * .18,
      color: PrismColors.rainbow[random.nextInt(PrismColors.rainbow.length)],
      square: index.isEven,
    );
  }, growable: false);
}

class PiecePainter extends CustomPainter {
  PiecePainter({required this.piece, required this.cellSize, this.opacity = 1});

  final Piece piece;
  final double cellSize;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final color =
        PrismColors.blockColors[piece.color % PrismColors.blockColors.length];
    final paint = Paint();
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color.withValues(alpha: opacity),
        color.withValues(alpha: opacity * .68),
      ],
    );
    final shine = Paint()
      ..color = Colors.white.withValues(alpha: .25 * opacity)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final cell in piece.cells) {
      final rect = Rect.fromLTWH(
        cell.col * cellSize + 2,
        cell.row * cellSize + 2,
        cellSize - 4,
        cellSize - 4,
      );
      paint.shader = gradient.createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(cellSize * .17)),
        paint,
      );
      canvas.drawLine(
        rect.topLeft + Offset(cellSize * .12, cellSize * .13),
        rect.topRight + Offset(-cellSize * .12, cellSize * .13),
        shine,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PiecePainter oldDelegate) =>
      oldDelegate.piece != piece ||
      oldDelegate.cellSize != cellSize ||
      oldDelegate.opacity != opacity;
}

class CountdownPainter extends CustomPainter {
  CountdownPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * .39;
    final track = Paint()
      ..color = const Color(0xff27356d)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * .075
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);
    final glow = Paint()
      ..color = PrismColors.yellow.withValues(alpha: .30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * .13
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.shortestSide * .05);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      glow,
    );
    final active = Paint()
      ..shader = const SweepGradient(
        colors: [PrismColors.orange, PrismColors.yellow, PrismColors.orange],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * .075
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      active,
    );
    final border = Paint()
      ..color = PrismColors.cyan.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius + size.shortestSide * .10, border);
  }

  @override
  bool shouldRepaint(covariant CountdownPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
