import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/cartoon_ui.dart';
import '../../../core/game_feel_config.dart';
import '../application/game_cubit.dart';
import '../domain/game_rules.dart';
import '../domain/models.dart';
import 'game_screen.dart';
import 'painters/block_skin.dart';
import 'painters/board_painters.dart';
import 'painters/game_painters.dart';

class CartoonGameplayScreenV3 extends StatefulWidget {
  const CartoonGameplayScreenV3({super.key, this.onExit});

  final VoidCallback? onExit;

  @override
  State<CartoonGameplayScreenV3> createState() =>
      _CartoonGameplayScreenV3State();
}

class _CartoonGameplayScreenV3State extends State<CartoonGameplayScreenV3>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _boardBorder = 5.0;
  static const _boardPadding = 6.2;
  static const _boardChrome = _boardBorder + _boardPadding;

  final _stackKey = GlobalKey();
  final _boardKey = GlobalKey();

  late final AnimationController _clearController;
  late final AnimationController _pickupController;
  late final ValueNotifier<_DragData?> _drag;
  late final ValueNotifier<int> _previewTick;
  late final Listenable _boardRepaint;

  BoardGeometry? _geometry;
  RenderBox? _stackBox;
  RenderBox? _boardBox;
  Board? _dragBoard;
  int _lastTurnId = 0;
  List<ClearParticle> _particles = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(BlockSkin.instance.preload());
    _drag = ValueNotifier<_DragData?>(null);
    _previewTick = ValueNotifier<int>(0);
    _clearController = AnimationController(
      vsync: this,
      duration: GameFeelConfig.clearTotal,
    );
    _pickupController = AnimationController(
      vsync: this,
      duration: GameFeelConfig.pickup,
    );
    _boardRepaint = Listenable.merge([_previewTick, _clearController]);
    _clearController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        context.read<GameCubit>().finishClear();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _handleTurn(context.read<GameCubit>().state);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearController.dispose();
    _pickupController.dispose();
    _drag.dispose();
    _previewTick.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      unawaited(context.read<GameCubit>().persistNow());
    }
  }

  void _handleTurn(GameState state) {
    final turn = state.turn;
    if (turn == null) {
      _lastTurnId = 0;
      _clearController.reset();
      _particles = const [];
      return;
    }
    if (turn.id == _lastTurnId) return;
    _lastTurnId = turn.id;

    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    _particles = reducedMotion || turn.lines == 0
        ? const []
        : buildClearParticles(
            cells: turn.clearCells,
            seed: turn.id,
            lines: turn.lines,
          );
    if (state.status == GameStatus.clearing) {
      _clearController.duration = reducedMotion
          ? const Duration(milliseconds: 120)
          : Duration(
              milliseconds:
                  560 + math.min(3, math.max(0, turn.lines - 1)) * 70,
            );
      _clearController.forward(from: 0);
    }
  }

  Future<void> _showSettings() async {
    final cubit = context.read<GameCubit>();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SettingsSheet(
        preferences: cubit.state.preferences,
        ads: cubit.ads,
        onChanged: cubit.updatePreferences,
      ),
    );
  }

  Future<void> _leave() async {
    final cubit = context.read<GameCubit>();
    if (cubit.state.status == GameStatus.playing ||
        cubit.state.status == GameStatus.clearing) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Leave this run?'),
          content: const Text('Your current board will be saved.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('STAY'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('LEAVE'),
            ),
          ],
        ),
      );
      if (leave != true) return;
      await cubit.persistNow();
    }
    if (mounted) widget.onExit?.call();
  }

  void _ensureGeometry(double outerBoardSize) {
    final contentSize = math.max(
      1.0,
      outerBoardSize - _boardChrome * 2,
    );
    if (_geometry == null || (_geometry!.size - contentSize).abs() > .01) {
      _geometry = BoardGeometry.fromSize(contentSize);
    }
  }

  void _startDrag(int index, Offset globalPosition) {
    final state = context.read<GameCubit>().state;
    if (state.status != GameStatus.playing ||
        index < 0 ||
        index >= state.pieces.length ||
        state.pieces[index] == null ||
        _drag.value != null) {
      return;
    }

    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final board = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null || board == null || _geometry == null) return;

    _stackBox = stack;
    _boardBox = board;
    _dragBoard = state.board;
    _drag.value = _DragData(
      index: index,
      piece: state.pieces[index]!,
      position: stack.globalToLocal(globalPosition),
    );
    _pickupController.forward(from: 0);
    context.read<GameCubit>().pickup(index);
    _updateDrag(globalPosition);
  }

  void _updateDrag(Offset globalPosition) {
    final drag = _drag.value;
    final stack = _stackBox;
    final board = _boardBox;
    final boardSnapshot = _dragBoard;
    final geometry = _geometry;
    if (drag == null ||
        stack == null ||
        board == null ||
        boardSnapshot == null ||
        geometry == null) {
      return;
    }

    final stackPosition = stack.globalToLocal(globalPosition);
    final boardPosition = board.globalToLocal(globalPosition);
    final cell = geometry.cellSize;
    final piece = drag.piece;
    final localX = boardPosition.dx - _boardChrome;
    final localY = boardPosition.dy - _boardChrome;
    final origin = GridPoint(
      ((localY - 82 - piece.height * cell / 2) / cell).round(),
      ((localX - piece.width * cell / 2) / cell).round(),
    );

    if (origin == drag.origin) {
      _drag.value = drag.copyWith(position: stackPosition);
      return;
    }

    final valid = evaluatePlacement(boardSnapshot, piece, origin).valid;
    _drag.value = drag.copyWith(
      position: stackPosition,
      origin: origin,
      valid: valid,
    );
    _previewTick.value++;
  }

  void _endDrag() {
    final drag = _drag.value;
    _drag.value = null;
    _previewTick.value++;
    _stackBox = null;
    _boardBox = null;
    _dragBoard = null;

    if (drag != null && drag.origin != null) {
      context.read<GameCubit>().drop(index: drag.index, origin: drag.origin!);
    } else {
      context.read<GameCubit>().cancelDrag();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameCubit, GameState>(
      listenWhen: (previous, current) => previous.turn != current.turn,
      listener: (_, state) => _handleTurn(state),
      builder: (context, state) {
        return PopScope(
          canPop: widget.onExit == null,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) unawaited(_leave());
          },
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final landscape =
                      constraints.maxWidth > constraints.maxHeight &&
                      constraints.maxHeight < 600;
                  return landscape
                      ? _landscape(constraints, state)
                      : _portrait(constraints, state);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _portrait(BoxConstraints constraints, GameState state) {
    const headerHeight = 86.0;
    const titleHeight = 32.0;
    const titleGap = 8.0;
    const trayHeight = 118.0;
    const headerGap = 14.0;
    const trayGap = 18.0;
    const bottom = 12.0;

    final contentWidth = math.min(constraints.maxWidth, 560.0);
    final maxBoardByWidth = contentWidth - 48;
    final maxBoardByHeight =
        constraints.maxHeight -
        headerHeight -
        headerGap -
        titleHeight -
        titleGap -
        trayGap -
        trayHeight -
        bottom;
    final outerBoardSize = math.max(
      190.0,
      math.min(maxBoardByWidth, maxBoardByHeight),
    );
    _ensureGeometry(outerBoardSize);
    final geometry = _geometry!;

    return Stack(
      key: _stackKey,
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: contentWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  SizedBox(
                    height: headerHeight,
                    child: _Hud(
                      state: state,
                      onBack: _leave,
                      onSettings: _showSettings,
                    ),
                  ),
                  const SizedBox(height: headerGap),
                  _BoardTitle(text: state.turn?.praise ?? 'MAKE SPACE'),
                  const SizedBox(height: titleGap),
                  _BoardSurface(
                    state: state,
                    boardKey: _boardKey,
                    outerSize: outerBoardSize,
                    geometry: geometry,
                    drag: _drag,
                    repaint: _boardRepaint,
                    clearController: _clearController,
                    particles: _particles,
                  ),
                  const SizedBox(height: trayGap),
                  _Tray(
                    pieces: state.pieces,
                    disabled: state.isInputLocked,
                    height: trayHeight,
                    onStart: _startDrag,
                    onUpdate: _updateDrag,
                    onEnd: _endDrag,
                  ),
                  const SizedBox(height: bottom),
                ],
              ),
            ),
          ),
        ),
        _dragLayer(geometry),
        ..._overlays(state),
      ],
    );
  }

  Widget _landscape(BoxConstraints constraints, GameState state) {
    final contentWidth = math.min(constraints.maxWidth, 900.0);
    final outerBoardSize = math.min(
      constraints.maxHeight - 54,
      contentWidth * .51,
    );
    _ensureGeometry(outerBoardSize);
    final geometry = _geometry!;

    return Stack(
      key: _stackKey,
      children: [
        Center(
          child: SizedBox(
            width: contentWidth,
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _BoardTitle(text: state.turn?.praise ?? 'MAKE SPACE'),
                      const SizedBox(height: 8),
                      _BoardSurface(
                        state: state,
                        boardKey: _boardKey,
                        outerSize: outerBoardSize,
                        geometry: geometry,
                        drag: _drag,
                        repaint: _boardRepaint,
                        clearController: _clearController,
                        particles: _particles,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 86,
                        child: _Hud(
                          state: state,
                          onBack: _leave,
                          onSettings: _showSettings,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _Tray(
                        pieces: state.pieces,
                        disabled: state.isInputLocked,
                        height: 118,
                        onStart: _startDrag,
                        onUpdate: _updateDrag,
                        onEnd: _endDrag,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _dragLayer(geometry),
        ..._overlays(state),
      ],
    );
  }

  Widget _dragLayer(BoardGeometry geometry) =>
      ValueListenableBuilder<_DragData?>(
        valueListenable: _drag,
        builder: (context, drag, child) {
          if (drag == null) return const SizedBox.shrink();
          return AnimatedBuilder(
            animation: _pickupController,
            builder: (context, child) => Positioned(
              left: drag.position.dx - drag.piece.width * geometry.cellSize / 2,
              top:
                  drag.position.dy -
                  90 -
                  drag.piece.height * geometry.cellSize / 2,
              child: IgnorePointer(
                child: Transform.scale(
                  scale:
                      1 +
                      Curves.easeOut.transform(_pickupController.value) * .06,
                  child: SizedBox(
                    width: drag.piece.width * geometry.cellSize,
                    height: drag.piece.height * geometry.cellSize,
                    child: CustomPaint(
                      painter: PiecePainter(
                        piece: drag.piece,
                        cellSize: geometry.cellSize,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );

  List<Widget> _overlays(GameState state) => [
        if (state.status == GameStatus.continuePrompt ||
            state.status == GameStatus.adLoading ||
            state.status == GameStatus.reviving)
          ContinueOverlay(state: state),
        if (state.status == GameStatus.results)
          ResultsOverlay(state: state, onExit: widget.onExit),
        if (state.status == GameStatus.modeSuccess ||
            state.status == GameStatus.modeFailure)
          ModeResultOverlay(state: state, onExit: widget.onExit),
      ];
}

class _Hud extends StatelessWidget {
  const _Hud({
    required this.state,
    required this.onBack,
    required this.onSettings,
  });

  final GameState state;
  final VoidCallback onBack;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 0),
        child: Row(
          children: [
            RoundGameButton(icon: Icons.home_rounded, onTap: onBack, tooltip: 'Home'),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 66,
                decoration: BoxDecoration(
                  color: CartoonColors.paperWarm,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: CartoonColors.outline, width: 3),
                  boxShadow: const [BoxShadow(color: Color(0x2f000000), blurRadius: 5, offset: Offset(0, 5))],
                ),
                child: Column(
                  children: [
                    Container(
                      height: 25,
                      margin: const EdgeInsets.fromLTRB(34, 5, 34, 0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xffff62ae), Color(0xffdf2d83)]),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: Alignment.center,
                      child: const Text('SCORE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.star_rounded, color: CartoonColors.yellow, size: 21),
                          const SizedBox(width: 5),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Text('${state.score}', key: ValueKey(state.score), style: const TextStyle(color: CartoonColors.text, fontSize: 22, fontWeight: FontWeight.w900)),
                          ),
                          if (state.combo > 1) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(color: CartoonColors.ribbon, borderRadius: BorderRadius.circular(10)),
                              child: Text('x${state.combo}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            RoundGameButton(icon: Icons.settings_rounded, onTap: onSettings, tooltip: 'Settings'),
          ],
        ),
      );
}

class _BoardTitle extends StatelessWidget {
  const _BoardTitle({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xffff61ad), Color(0xffdc2d82)]),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white.withValues(alpha: .45)),
          boxShadow: const [BoxShadow(color: Color(0x30000000), blurRadius: 4, offset: Offset(0, 4))],
        ),
        alignment: Alignment.center,
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
      );
}

class _BoardSurface extends StatelessWidget {
  const _BoardSurface({required this.state, required this.boardKey, required this.outerSize, required this.geometry, required this.drag, required this.repaint, required this.clearController, required this.particles});
  final GameState state;
  final GlobalKey boardKey;
  final double outerSize;
  final BoardGeometry geometry;
  final ValueListenable<_DragData?> drag;
  final Listenable repaint;
  final AnimationController clearController;
  final List<ClearParticle> particles;

  @override
  Widget build(BuildContext context) {
    final turn = state.turn;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final drawData = turn == null || state.status != GameStatus.clearing
        ? null
        : TurnDrawData(clearCells: turn.clearCells, rows: _rows(turn.clearCells), columns: _columns(turn.clearCells));
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Container(
          key: boardKey,
          width: outerSize,
          height: outerSize,
          padding: const EdgeInsets.all(6.2),
          decoration: BoxDecoration(
            color: CartoonColors.paper,
            borderRadius: BorderRadius.circular(27),
            border: Border.all(color: CartoonColors.outline, width: 5),
            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(5, 7))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: SizedBox.expand(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _CreamBoardPainter(board: state.board, geometry: geometry, hiddenCells: state.status == GameStatus.clearing ? turn?.clearCells ?? const {} : const {})),
                  AnimatedBuilder(
                    animation: repaint,
                    builder: (context, child) {
                      final activeDrag = drag.value;
                      return CustomPaint(
                        painter: BoardEffectsPainter(
                          geometry: geometry,
                          board: state.board,
                          reducedMotion: reducedMotion,
                          previewPiece: activeDrag?.piece,
                          previewOrigin: activeDrag?.origin,
                          previewValid: activeDrag?.valid ?? false,
                          turn: drawData,
                          clearProgress: clearController.value,
                          particles: particles,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        if (turn != null && turn.points > 0)
          Positioned(
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: CartoonColors.yellow, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white, width: 2), boxShadow: const [BoxShadow(color: Color(0x30000000), blurRadius: 4, offset: Offset(0, 4))]),
              child: Text('+${turn.points}', style: const TextStyle(color: CartoonColors.text, fontSize: 16, fontWeight: FontWeight.w900)),
            ),
          ),
      ],
    );
  }

  static List<int> _rows(Set<GridPoint> cells) => [for (var row = 0; row < Board.size; row++) if ([for (var col = 0; col < Board.size; col++) GridPoint(row, col)].every(cells.contains)) row];
  static List<int> _columns(Set<GridPoint> cells) => [for (var col = 0; col < Board.size; col++) if ([for (var row = 0; row < Board.size; row++) GridPoint(row, col)].every(cells.contains)) col];
}

class _CreamBoardPainter extends CustomPainter {
  _CreamBoardPainter({required this.board, required this.geometry, this.hiddenCells = const {}}) : super(repaint: BlockSkin.instance);
  final Board board;
  final BoardGeometry geometry;
  final Set<GridPoint> hiddenCells;
  @override
  void paint(Canvas canvas, Size size) {
    final empty = Paint()..color = const Color(0xffffd9a9);
    final edge = Paint()..color = const Color(0xffedbf86)..style = PaintingStyle.stroke..strokeWidth = 1.4;
    for (var row = 0; row < Board.size; row++) {
      for (var col = 0; col < Board.size; col++) {
        final point = GridPoint(row, col);
        final rect = geometry.blockRect(point);
        canvas.drawRRect(rect, empty);
        canvas.drawRRect(rect, edge);
        final value = board.cells[row][col];
        if (value == null || hiddenCells.contains(point)) continue;
        BlockSkin.instance.paint(canvas, geometry.cellRect(point), value);
      }
    }
  }
  @override
  bool shouldRepaint(covariant _CreamBoardPainter oldDelegate) => oldDelegate.board != board || oldDelegate.geometry != geometry || oldDelegate.hiddenCells != hiddenCells;
}

class _Tray extends StatelessWidget {
  const _Tray({required this.pieces, required this.disabled, required this.height, required this.onStart, required this.onUpdate, required this.onEnd});
  final List<Piece?> pieces;
  final bool disabled;
  final double height;
  final void Function(int, Offset) onStart;
  final void Function(Offset) onUpdate;
  final VoidCallback onEnd;
  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.fromLTRB(10, 25, 10, 9),
            decoration: BoxDecoration(color: CartoonColors.paperWarm, borderRadius: BorderRadius.circular(23), border: Border.all(color: CartoonColors.outline, width: 4), boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 6, offset: Offset(0, 6))]),
            child: Row(children: [for (var index = 0; index < pieces.length; index++) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _PieceSlot(piece: pieces[index], index: index, disabled: disabled, onStart: onStart, onUpdate: onUpdate, onEnd: onEnd)))]),
          ),
          Positioned(
            top: -12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xffb7e928), Color(0xff76bc14)]), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: .45))),
              child: const Text('YOUR SHAPES', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
            ),
          ),
        ],
      );
}

class _PieceSlot extends StatelessWidget {
  const _PieceSlot({required this.piece, required this.index, required this.disabled, required this.onStart, required this.onUpdate, required this.onEnd});
  final Piece? piece;
  final int index;
  final bool disabled;
  final void Function(int, Offset) onStart;
  final void Function(Offset) onUpdate;
  final VoidCallback onEnd;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: disabled || piece == null ? null : (details) => onStart(index, details.globalPosition),
        onPanUpdate: disabled || piece == null ? null : (details) => onUpdate(details.globalPosition),
        onPanEnd: disabled || piece == null ? null : (_) => onEnd(),
        onPanCancel: disabled || piece == null ? null : onEnd,
        child: Container(
          decoration: BoxDecoration(color: const Color(0xffffefd7), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xffe6bd91), width: 2)),
          alignment: Alignment.center,
          child: piece == null
              ? const Icon(Icons.check_rounded, color: CartoonColors.green, size: 28)
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final cell = math.min((constraints.maxWidth - 16) / piece!.width, (constraints.maxHeight - 16) / piece!.height);
                    return SizedBox(width: piece!.width * cell, height: piece!.height * cell, child: CustomPaint(painter: PiecePainter(piece: piece!, cellSize: cell)));
                  },
                ),
        ),
      );
}

@immutable
class _DragData {
  const _DragData({required this.index, required this.piece, required this.position, this.origin, this.valid = false});
  final int index;
  final Piece piece;
  final Offset position;
  final GridPoint? origin;
  final bool valid;
  _DragData copyWith({Offset? position, GridPoint? origin, bool? valid}) => _DragData(index: index, piece: piece, position: position ?? this.position, origin: origin ?? this.origin, valid: valid ?? this.valid);
}
