import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/cartoon_ui.dart';
import '../../../core/analytics/game_analytics.dart';
import '../application/game_cubit.dart';
import '../domain/models.dart';
import 'cartoon_game_shell.dart';
import 'painters/block_skin.dart';
import 'painters/board_painters.dart';
import 'painters/game_painters.dart';

/// Tutorial progress is stored separately from the active run and its score.
class FirstPlayGame extends StatefulWidget {
  const FirstPlayGame({super.key, required this.cubit, this.onExit});
  final GameCubit cubit;
  final VoidCallback? onExit;

  @override
  State<FirstPlayGame> createState() => _FirstPlayGameState();
}

class _FirstPlayGameState extends State<FirstPlayGame> {
  late bool _needsTutorial;

  @override
  void initState() {
    super.initState();
    _needsTutorial = !widget.cubit.state.preferences.hasCompletedOnboarding;
    if (_needsTutorial) GameAnalytics.instance.event('tutorial_started');
  }

  Future<void> _complete() async {
    GameAnalytics.instance.event('tutorial_completed');
    await widget.cubit.updatePreferences(
      widget.cubit.state.preferences.copyWith(hasCompletedOnboarding: true),
    );
    if (mounted) setState(() => _needsTutorial = false);
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300),
    child: _needsTutorial
        ? DragTutorialScreen(onCompleted: _complete, onExit: widget.onExit)
        : CartoonGameShell(cubit: widget.cubit, onExit: widget.onExit),
  );
}

class DragTutorialScreen extends StatefulWidget {
  const DragTutorialScreen({super.key, required this.onCompleted, this.onExit});
  final Future<void> Function() onCompleted;
  final VoidCallback? onExit;

  static const target = GridPoint(2, 3);
  static final piece = PieceLibrary.byId['rect_tall']!;
  static final initialBoard = Board()
      .place(PieceLibrary.byId['square_3']!, const GridPoint(2, 0))
      .place(PieceLibrary.byId['square_3']!, const GridPoint(2, 5));

  @override
  State<DragTutorialScreen> createState() => _DragTutorialScreenState();
}

class _DragTutorialScreenState extends State<DragTutorialScreen>
    with TickerProviderStateMixin {
  final _sceneKey = GlobalKey();
  late final AnimationController _hint;
  late final AnimationController _clear;
  late final AnimationController _return;
  Offset? _dragCenter;
  Offset? _returnFrom;
  bool _placed = false;
  bool _retry = false;
  bool _reducedMotion = false;
  Timer? _completionTimer;

  @override
  void initState() {
    super.initState();
    unawaited(BlockSkin.instance.preload());
    _hint = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    _clear = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _return = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _return.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      setState(() => _returnFrom = null);
      if (!_reducedMotion) _hint.repeat();
    });
    _clear.addStatusListener((status) {
      if (status != AnimationStatus.completed) return;
      _completionTimer = Timer(const Duration(milliseconds: 650), () {
        if (mounted) unawaited(widget.onCompleted());
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    if (_reducedMotion) {
      _hint.stop();
      _hint.value = .12;
    } else if (!_placed && _dragCenter == null && _returnFrom == null) {
      _hint.repeat();
    }
    _clear.duration = Duration(milliseconds: _reducedMotion ? 120 : 720);
  }

  @override
  void dispose() {
    _completionTimer?.cancel();
    _hint.dispose();
    _clear.dispose();
    _return.dispose();
    super.dispose();
  }

  Offset _local(Offset global) =>
      (_sceneKey.currentContext!.findRenderObject()! as RenderBox)
          .globalToLocal(global);

  void _start(DragStartDetails details) {
    if (_placed || _returnFrom != null) return;
    _hint.stop();
    setState(
      () => _dragCenter = _local(details.globalPosition) - const Offset(0, 52),
    );
  }

  void _move(DragUpdateDetails details) {
    if (_dragCenter == null) return;
    setState(
      () => _dragCenter = _local(details.globalPosition) - const Offset(0, 52),
    );
  }

  void _drop(Rect target, double cell, {bool cancelled = false}) {
    final center = _dragCenter;
    if (center == null) return;
    final correct =
        !cancelled &&
        (center.dx - target.center.dx).abs() < cell * .6 &&
        (center.dy - target.center.dy).abs() < cell * .6;
    setState(() {
      _dragCenter = null;
      _placed = correct;
      _retry = !correct;
      _returnFrom = correct ? null : center;
    });
    if (correct) {
      unawaited(HapticFeedback.lightImpact().catchError((Object _) {}));
      _clear.forward(from: 0);
    } else {
      _hint.value = 0;
      _return.duration = Duration(milliseconds: _reducedMotion ? 0 : 220);
      _return.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: CartoonColors.paper,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > constraints.maxHeight;
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final boardSize = math.min(
            480.0,
            wide
                ? math.min(height - 40, width * .51)
                : math.min(width - 40, height - 274),
          );
          final boardRect = Rect.fromLTWH(
            wide ? 20 : (width - boardSize) / 2,
            wide ? (height - boardSize) / 2 : 96,
            boardSize,
            boardSize,
          );
          final geometry = BoardGeometry.fromSize(boardSize);
          final cell = geometry.cellSize;
          final target = Rect.fromLTWH(
            boardRect.left + 3 * cell,
            boardRect.top + 2 * cell,
            2 * cell,
            3 * cell,
          );
          final trayCell = math.min(32.0, cell);
          final sourceCenter = wide
              ? Offset(
                  boardRect.right + (width - boardRect.right) / 2,
                  height * .66,
                )
              : Offset(width / 2, boardRect.bottom + 30 + trayCell * 1.5);
          final source = Rect.fromCenter(
            center: sourceCenter,
            width: trayCell * 2,
            height: trayCell * 3,
          );
          final clearCells = <GridPoint>{
            for (var row = 2; row <= 4; row++)
              for (var col = 0; col < Board.size; col++) GridPoint(row, col),
          };
          final board = _placed
              ? DragTutorialScreen.initialBoard.place(
                  DragTutorialScreen.piece,
                  DragTutorialScreen.target,
                )
              : DragTutorialScreen.initialBoard;
          return Stack(
            key: _sceneKey,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: wide ? boardRect.right + 20 : 20,
                right: 20,
                top: wide ? 24 : 6,
                child: Row(
                  children: [
                    if (widget.onExit != null)
                      IconButton(
                        tooltip: 'Back',
                        onPressed: widget.onExit,
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: CartoonColors.text,
                        ),
                      ),
                    const Expanded(
                      child: Text(
                        'HOW TO PLAY',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: CartoonColors.textSoft,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                    if (widget.onExit != null) const SizedBox(width: 48),
                  ],
                ),
              ),
              Positioned(
                left: wide ? boardRect.right + 20 : 20,
                right: 20,
                top: wide ? 85 : 54,
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    _placed
                        ? 'Perfect! You cleared 3 rows.'
                        : _retry
                        ? 'Try the highlighted space'
                        : 'Drag the block into the gap',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _placed
                          ? const Color(0xff27845b)
                          : CartoonColors.text,
                      fontSize: wide ? 19 : 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: boardRect.inflate(2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: CartoonColors.paperWarm,
                    border: Border.all(color: CartoonColors.outline),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x16000000),
                        blurRadius: 12,
                        offset: Offset(0, 5),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: boardRect,
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: const ValueKey('tutorial-board'),
                    painter: _TutorialBoardPainter(
                      board: board,
                      geometry: geometry,
                      hint: _hint,
                      clear: _clear,
                      placed: _placed,
                      clearCells: clearCells,
                    ),
                  ),
                ),
              ),
              if (_placed)
                Positioned.fromRect(
                  rect: boardRect,
                  child: AnimatedBuilder(
                    animation: _clear,
                    builder: (context, _) => CustomPaint(
                      painter: BoardEffectsPainter(
                        geometry: geometry,
                        board: board,
                        reducedMotion: _reducedMotion,
                        turn: TurnDrawData(
                          clearCells: clearCells,
                          rows: const [2, 3, 4],
                          columns: const [],
                        ),
                        clearProgress: _clear.value,
                        particles: const [],
                      ),
                    ),
                  ),
                ),
              Positioned.fromRect(
                rect: source.inflate(12),
                child: Semantics(
                  label: 'Drag the rectangle into the highlighted gap',
                  child: GestureDetector(
                    key: const ValueKey('tutorial-piece'),
                    behavior: HitTestBehavior.opaque,
                    onPanStart: _placed ? null : _start,
                    onPanUpdate: _placed ? null : _move,
                    onPanEnd: _placed ? null : (_) => _drop(target, cell),
                    onPanCancel: () => _drop(target, cell, cancelled: true),
                    child: AnimatedOpacity(
                      opacity:
                          _placed || _dragCenter != null || _returnFrom != null
                          ? 0
                          : 1,
                      duration: const Duration(milliseconds: 100),
                      child: AnimatedBuilder(
                        animation: _hint,
                        builder: (context, child) {
                          final lift = Curves.easeInOutCubic.transform(
                            ((_hint.value - .16) / .12).clamp(0.0, 1.0),
                          );
                          final restore = ((_hint.value - .84) / .10).clamp(
                            0.0,
                            1.0,
                          );
                          return Opacity(
                            opacity: _reducedMotion
                                ? 1
                                : 1 - .75 * lift * (1 - restore),
                            child: child,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: CustomPaint(
                            painter: PiecePainter(
                              piece: DragTutorialScreen.piece,
                              cellSize: trayCell,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Transparent targets and guidance never intercept the player's drag.
              Positioned.fromRect(
                rect: target,
                child: IgnorePointer(
                  child: SizedBox(key: const ValueKey('tutorial-target')),
                ),
              ),
              if (_dragCenter != null) _ghost(_dragCenter!, cell, 1),
              if (_returnFrom != null)
                AnimatedBuilder(
                  animation: _return,
                  builder: (context, _) {
                    final t = Curves.easeOutCubic.transform(_return.value);
                    return _ghost(
                      Offset.lerp(_returnFrom!, sourceCenter, t)!,
                      cell + (trayCell - cell) * t,
                      1,
                    );
                  },
                ),
              if (!_placed && _dragCenter == null && _returnFrom == null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _hint,
                      builder: (context, _) => _guidance(
                        sourceCenter,
                        target.center,
                        trayCell,
                        cell,
                      ),
                    ),
                  ),
                ),
              if (!_placed)
                Positioned(
                  left: wide ? boardRect.right + 16 : 16,
                  right: 16,
                  top: source.bottom + 22,
                  child: const Text(
                    'Hold, move, then release',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CartoonColors.textSoft,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );

  Widget _ghost(Offset center, double cell, double opacity) => Positioned(
    left: center.dx - cell,
    top: center.dy - cell * 1.5,
    width: cell * 2,
    height: cell * 3,
    child: IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: CustomPaint(
          painter: PiecePainter(
            piece: DragTutorialScreen.piece,
            cellSize: cell,
          ),
        ),
      ),
    ),
  );

  Widget _guidance(Offset source, Offset target, double trayCell, double cell) {
    final t = _hint.value;
    double phase(double from, double to) =>
        ((t - from) / (to - from)).clamp(0.0, 1.0);
    final lift = Curves.easeInOutCubic.transform(phase(.16, .28));
    final travel = Curves.easeInOutCubic.transform(phase(.28, .68));
    final finger = Offset.lerp(source, target + const Offset(0, 52), travel)!;
    final opacity = _reducedMotion
        ? 1.0
        : phase(0, .08) * (1 - phase(.84, .94));
    final showGhost = !_reducedMotion && t >= .16 && t <= .84;
    return Stack(
      children: [
        if (_reducedMotion)
          Positioned.fill(
            child: CustomPaint(painter: _DirectionPainter(source, target)),
          ),
        if (showGhost)
          _ghost(
            finger - Offset(0, 52 * lift),
            trayCell + (cell - trayCell) * lift,
            .68 * opacity,
          ),
        Positioned(
          left: finger.dx - 14,
          top: finger.dy - 5,
          child: Opacity(
            opacity: opacity,
            child: Transform.scale(
              scale: t >= .16 && t < .28 ? .9 : 1,
              child: const Icon(
                Icons.touch_app_rounded,
                key: ValueKey('tutorial-hand'),
                color: Colors.white,
                size: 42,
                shadows: [
                  Shadow(
                    color: Color(0xcc514266),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TutorialBoardPainter extends CustomPainter {
  _TutorialBoardPainter({
    required this.board,
    required this.geometry,
    required this.hint,
    required this.clear,
    required this.placed,
    required this.clearCells,
  }) : super(repaint: Listenable.merge([hint, clear, BlockSkin.instance]));
  final Board board;
  final BoardGeometry geometry;
  final Animation<double> hint;
  final Animation<double> clear;
  final bool placed;
  final Set<GridPoint> clearCells;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0xffffd9a9);
    final edge = Paint()
      ..color = const Color(0xffedbf86)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var row = 0; row < Board.size; row++) {
      for (var col = 0; col < Board.size; col++) {
        final point = GridPoint(row, col);
        canvas.drawRRect(geometry.blockRect(point), fill);
        canvas.drawRRect(geometry.blockRect(point), edge);
        final value = board[point];
        if (value != null && !(placed && clearCells.contains(point))) {
          BlockSkin.instance.paint(canvas, geometry.cellRect(point), value);
        }
      }
    }
    if (!placed) {
      final pulse = .12 + .06 * (1 + math.sin(hint.value * math.pi * 2));
      final highlight = Paint()
        ..color = const Color(0xff37aa8a).withValues(alpha: pulse);
      final border = Paint()
        ..color = const Color(0xff278b70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      for (final cell in DragTutorialScreen.piece.cells) {
        final point = cell.translate(
          DragTutorialScreen.target.row,
          DragTutorialScreen.target.col,
        );
        final rect = geometry.cellRect(point).deflate(.5);
        canvas.drawRect(rect, highlight);
        canvas.drawRect(rect, border);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TutorialBoardPainter old) =>
      old.board != board || old.geometry != geometry || old.placed != placed;
}

class _DirectionPainter extends CustomPainter {
  _DirectionPainter(this.from, this.to);
  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    final direction = (to - from) / (to - from).distance;
    final end = to - direction * 14;
    final start = from + direction * 44;
    final paint = Paint()
      ..color = const Color(0xff278b70).withValues(alpha: .5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(start, end, paint);
    final normal = Offset(-direction.dy, direction.dx);
    canvas.drawLine(end, end - direction * 12 + normal * 6, paint);
    canvas.drawLine(end, end - direction * 12 - normal * 6, paint);
  }

  @override
  bool shouldRepaint(covariant _DirectionPainter old) =>
      old.from != from || old.to != to;
}
