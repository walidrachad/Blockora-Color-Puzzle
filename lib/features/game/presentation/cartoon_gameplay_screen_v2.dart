import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
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

class CartoonGameplayScreenV2 extends StatefulWidget {
  const CartoonGameplayScreenV2({super.key, this.onExit});

  final VoidCallback? onExit;

  @override
  State<CartoonGameplayScreenV2> createState() =>
      _CartoonGameplayScreenV2State();
}

class _CartoonGameplayScreenV2State extends State<CartoonGameplayScreenV2>
    with TickerProviderStateMixin, WidgetsBindingObserver {
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
    final origin = GridPoint(
      ((boardPosition.dy -
                  BoardGeometry.contentInset -
                  82 -
                  piece.height * cell / 2) /
              cell)
          .round(),
      ((boardPosition.dx -
                  BoardGeometry.contentInset -
                  piece.width * cell / 2) /
              cell)
          .round(),
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
            backgroundColor: CartoonColors.paper,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final landscape =
                      constraints.maxWidth > constraints.maxHeight &&
                      constraints.maxHeight < 600;

                  if (landscape) {
                    return _buildLandscape(context, constraints, state);
                  }
                  return _buildPortrait(context, constraints, state);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPortrait(
    BuildContext context,
    BoxConstraints constraints,
    GameState state,
  ) {
    const headerHeight = 86.0;
    const trayHeight = 118.0;
    const boardTitleHeight = 34.0;
    const gapAfterHeader = 16.0;
    const gapBeforeTray = 22.0;
    const bottomPadding = 14.0;

    final contentWidth = math.min(constraints.maxWidth, 560.0);
    final maxBoardByWidth = contentWidth - 34;
    final maxBoardByHeight =
        constraints.maxHeight -
        headerHeight -
        trayHeight -
        boardTitleHeight -
        gapAfterHeader -
        gapBeforeTray -
        bottomPadding;
    final boardSize = math.max(
      190.0,
      math.min(maxBoardByWidth, maxBoardByHeight),
    );

    _ensureGeometry(boardSize);
    final geometry = _geometry!;

    return Stack(
      key: _stackKey,
      children: [
        const Positioned.fill(child: _PaperDots()),
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: contentWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: headerHeight,
                    child: _CompactHud(
                      state: state,
                      onBack: _leave,
                      onSettings: _showSettings,
                    ),
                  ),
                  const SizedBox(height: gapAfterHeader),
                  Center(
                    child: _BoardPanel(
                      state: state,
                      boardKey: _boardKey,
                      boardSize: boardSize,
                      geometry: geometry,
                      drag: _drag,
                      repaint: _boardRepaint,
                      clearController: _clearController,
                      particles: _particles,
                    ),
                  ),
                  const SizedBox(height: gapBeforeTray),
                  _TrayPanel(
                    pieces: state.pieces,
                    disabled: state.isInputLocked,
                    height: trayHeight,
                    onStart: _startDrag,
                    onUpdate: _updateDrag,
                    onEnd: _endDrag,
                  ),
                  const SizedBox(height: bottomPadding),
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

  Widget _buildLandscape(
    BuildContext context,
    BoxConstraints constraints,
    GameState state,
  ) {
    final contentWidth = math.min(constraints.maxWidth, 900.0);
    final boardSize = math.min(
      constraints.maxHeight - 30,
      contentWidth * .53,
    );
    _ensureGeometry(boardSize);
    final geometry = _geometry!;

    return Stack(
      key: _stackKey,
      children: [
        const Positioned.fill(child: _PaperDots()),
        Center(
          child: SizedBox(
            width: contentWidth,
            child: Row(
              children: [
                Expanded(
                  flex: 6,
                  child: Center(
                    child: _BoardPanel(
                      state: state,
                      boardKey: _boardKey,
                      boardSize: boardSize,
                      geometry: geometry,
                      drag: _drag,
                      repaint: _boardRepaint,
                      clearController: _clearController,
                      particles: _particles,
                    ),
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
                        child: _CompactHud(
                          state: state,
                          onBack: _leave,
                          onSettings: _showSettings,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _TrayPanel(
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

  void _ensureGeometry(double boardSize) {
    final inner = boardSize - BoardGeometry.contentInset * 2;
    if (_geometry == null || _geometry!.size != inner) {
      _geometry = BoardGeometry.fromSize(inner);
    }
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

class _CompactHud extends StatelessWidget {
  const _CompactHud({
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
            RoundGameButton(
              icon: Icons.home_rounded,
              onTap: onBack,
              tooltip: 'Home',
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 66,
                decoration: BoxDecoration(
                  color: CartoonColors.paperWarm,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: CartoonColors.outline, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x2f000000),
                      blurRadius: 5,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      height: 25,
                      margin: const EdgeInsets.fromLTRB(34, 5, 34, 0),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xffff62ae), Color(0xffdf2d83)],
                        ),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'SCORE',
                        maxLines: 1,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: CartoonColors.yellow,
                            size: 21,
                          ),
                          const SizedBox(width: 5),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            child: Text(
                              '${state.score}',
                              key: ValueKey(state.score),
                              style: const TextStyle(
                                color: CartoonColors.text,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (state.combo > 1) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: CartoonColors.ribbon,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'x${state.combo}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
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
            RoundGameButton(
              icon: Icons.settings_rounded,
              onTap: onSettings,
              tooltip: 'Settings',
              // blue: true,
            ),
          ],
        ),
      );
}

class _BoardPanel extends StatelessWidget {
  const _BoardPanel({
    required this.state,
    required this.boardKey,
    required this.boardSize,
    required this.geometry,
    required this.drag,
    required this.repaint,
    required this.clearController,
    required this.particles,
  });

  final GameState state;
  final GlobalKey boardKey;
  final double boardSize;
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
        : TurnDrawData(
            clearCells: turn.clearCells,
            rows: _rows(turn.clearCells),
            columns: _columns(turn.clearCells),
          );

    return SizedBox(
      width: boardSize,
      child: Column(
        children: [
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xffff61ad), Color(0xffdc2d82)],
              ),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white.withValues(alpha: .45)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x30000000),
                  blurRadius: 4,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              turn?.praise ?? 'MAKE SPACE',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              Container(
                key: boardKey,
                width: boardSize,
                height: boardSize,
                padding: EdgeInsets.all(BoardGeometry.contentInset),
                decoration: BoxDecoration(
                  color: CartoonColors.paper,
                  borderRadius: BorderRadius.circular(27),
                  border: Border.all(color: CartoonColors.outline, width: 5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 8,
                      offset: Offset(5, 7),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CustomPaint(
                        painter: _CreamBoardPainter(
                          board: state.board,
                          geometry: geometry,
                          hiddenCells: state.status == GameStatus.clearing
                              ? turn?.clearCells ?? const {}
                              : const {},
                        ),
                      ),
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
              if (turn != null && turn.points > 0)
                Positioned(
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: CartoonColors.yellow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x30000000),
                          blurRadius: 4,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      '+${turn.points}',
                      style: const TextStyle(
                        color: CartoonColors.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static List<int> _rows(Set<GridPoint> cells) => [
        for (var row = 0; row < Board.size; row++)
          if ([
            for (var col = 0; col < Board.size; col++) GridPoint(row, col),
          ].every(cells.contains))
            row,
      ];

  static List<int> _columns(Set<GridPoint> cells) => [
        for (var col = 0; col < Board.size; col++)
          if ([
            for (var row = 0; row < Board.size; row++) GridPoint(row, col),
          ].every(cells.contains))
            col,
      ];
}

class _CreamBoardPainter extends CustomPainter {
  _CreamBoardPainter({
    required this.board,
    required this.geometry,
    this.hiddenCells = const {},
  }) : super(repaint: BlockSkin.instance);

  final Board board;
  final BoardGeometry geometry;
  final Set<GridPoint> hiddenCells;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0xffffd9a9);
    final edge = Paint()
      ..color = const Color(0xffedbb7f)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    for (var row = 0; row < Board.size; row++) {
      for (var col = 0; col < Board.size; col++) {
        final point = GridPoint(row, col);
        final cell = geometry.blockRect(point);
        canvas.drawRRect(cell, fill);
        canvas.drawRRect(cell, edge);
        final value = board.cells[row][col];
        if (value == null || hiddenCells.contains(point)) continue;
        BlockSkin.instance.paint(canvas, geometry.cellRect(point), value);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CreamBoardPainter oldDelegate) =>
      oldDelegate.board != board ||
      oldDelegate.geometry != geometry ||
      oldDelegate.hiddenCells != hiddenCells;
}

class _TrayPanel extends StatelessWidget {
  const _TrayPanel({
    required this.pieces,
    required this.disabled,
    required this.height,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final List<Piece?> pieces;
  final bool disabled;
  final double height;
  final void Function(int, Offset) onStart;
  final void Function(Offset) onUpdate;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: CartoonColors.paperWarm,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: CartoonColors.outline, width: 4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x30000000),
              blurRadius: 6,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 29,
              width: 190,
              transform: Matrix4.translationValues(0, -10, 0),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xffb8e62d), Color(0xff73b915)],
                ),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withValues(alpha: .45)),
              ),
              alignment: Alignment.center,
              child: const Text(
                'YOUR SHAPES',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: Row(
                  children: [
                    for (var index = 0; index < pieces.length; index++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _PieceSlot(
                            piece: pieces[index],
                            index: index,
                            disabled: disabled,
                            onStart: onStart,
                            onUpdate: onUpdate,
                            onEnd: onEnd,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _PieceSlot extends StatelessWidget {
  const _PieceSlot({
    required this.piece,
    required this.index,
    required this.disabled,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final Piece? piece;
  final int index;
  final bool disabled;
  final void Function(int, Offset) onStart;
  final void Function(Offset) onUpdate;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: disabled || piece == null
            ? null
            : (details) => onStart(index, details.globalPosition),
        onPanUpdate: disabled || piece == null
            ? null
            : (details) => onUpdate(details.globalPosition),
        onPanEnd: disabled || piece == null ? null : (_) => onEnd(),
        onPanCancel: disabled || piece == null ? null : onEnd,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xffffefd8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xffe6b987), width: 2),
          ),
          alignment: Alignment.center,
          child: piece == null
              ? const Icon(
                  Icons.check_rounded,
                  color: CartoonColors.green,
                  size: 27,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final cell = math.min(
                      (constraints.maxWidth - 14) / piece!.width,
                      (constraints.maxHeight - 14) / piece!.height,
                    );
                    return SizedBox(
                      width: piece!.width * cell,
                      height: piece!.height * cell,
                      child: CustomPaint(
                        painter: PiecePainter(piece: piece!, cellSize: cell),
                      ),
                    );
                  },
                ),
        ),
      );
}

class _PaperDots extends StatelessWidget {
  const _PaperDots();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DotsPainter());
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xffe8c7ba).withValues(alpha: .20);
    for (double y = 12; y < size.height; y += 30) {
      for (double x = 12; x < size.width; x += 30) {
        canvas.drawCircle(Offset(x, y), 1.3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

@immutable
class _DragData {
  const _DragData({
    required this.index,
    required this.piece,
    required this.position,
    this.origin,
    this.valid = false,
  });

  final int index;
  final Piece piece;
  final Offset position;
  final GridPoint? origin;
  final bool valid;

  _DragData copyWith({
    Offset? position,
    GridPoint? origin,
    bool? valid,
  }) =>
      _DragData(
        index: index,
        piece: piece,
        position: position ?? this.position,
        origin: origin ?? this.origin,
        valid: valid ?? this.valid,
      );
}
