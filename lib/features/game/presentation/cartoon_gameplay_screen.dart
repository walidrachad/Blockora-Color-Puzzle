import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/cartoon_ui.dart';
import '../../../app/theme.dart';
import '../../../core/game_feel_config.dart';
import '../../../core/services/services.dart';
import '../application/game_cubit.dart';
import '../domain/game_rules.dart';
import '../domain/models.dart';
import 'game_screen.dart';
import 'painters/block_skin.dart';
import 'painters/board_painters.dart';
import 'painters/game_painters.dart';

class CartoonGameplayScreen extends StatefulWidget {
  const CartoonGameplayScreen({super.key, this.onExit});

  final VoidCallback? onExit;

  @override
  State<CartoonGameplayScreen> createState() => _CartoonGameplayScreenState();
}

class _CartoonGameplayScreenState extends State<CartoonGameplayScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _stackKey = GlobalKey();
  final _boardKey = GlobalKey();

  late final AnimationController _clearController;
  late final AnimationController _pickupController;
  late final ValueNotifier<_CartoonDrag?> _drag;
  late final ValueNotifier<int> _boardPreviewVersion;
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
    _drag = ValueNotifier<_CartoonDrag?>(null);
    _boardPreviewVersion = ValueNotifier<int>(0);
    _clearController = AnimationController(
      vsync: this,
      duration: GameFeelConfig.clearTotal,
    );
    _pickupController = AnimationController(
      vsync: this,
      duration: GameFeelConfig.pickup,
    );
    _boardRepaint = Listenable.merge([
      _boardPreviewVersion,
      _clearController,
    ]);
    _clearController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        context.read<GameCubit>().finishClear();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _handleTurn(context.read<GameCubit>().state);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearController.dispose();
    _pickupController.dispose();
    _drag.dispose();
    _boardPreviewVersion.dispose();
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

  Future<void> _leaveGame() async {
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
    final geometry = _geometry;
    if (stack == null || board == null || geometry == null) return;

    _stackBox = stack;
    _boardBox = board;
    _dragBoard = state.board;
    _drag.value = _CartoonDrag(
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
    _boardPreviewVersion.value++;
  }

  void _endDrag() {
    final drag = _drag.value;
    _drag.value = null;
    _boardPreviewVersion.value++;
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
            if (!didPop) unawaited(_leaveGame());
          },
          child: Scaffold(
            backgroundColor: CartoonColors.paper,
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final landscape =
                      constraints.maxWidth > constraints.maxHeight &&
                      constraints.maxHeight < 600;
                  final contentWidth = math.min(constraints.maxWidth, 610.0);
                  final trayHeight = landscape ? 82.0 : 108.0;
                  final headerHeight = landscape ? 62.0 : 78.0;
                  final boardBudget = landscape
                      ? constraints.maxHeight - 28
                      : constraints.maxHeight - headerHeight - trayHeight - 96;
                  final boardSize = landscape
                      ? math.min(
                          constraints.maxHeight - 22,
                          constraints.maxWidth * .52,
                        )
                      : math.min(
                          contentWidth - 34,
                          math.max(180.0, boardBudget),
                        );
                  final innerSize = boardSize - BoardGeometry.contentInset * 2;
                  if (_geometry == null || _geometry!.size != innerSize) {
                    _geometry = BoardGeometry.fromSize(innerSize);
                  }
                  final geometry = _geometry!;

                  return Stack(
                    key: _stackKey,
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: CartoonColors.paper,
                          ),
                          child: const _GameplayPaperPattern(),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: contentWidth,
                          child: landscape
                              ? Row(
                                  children: [
                                    Expanded(
                                      flex: 6,
                                      child: Center(
                                        child: _CartoonBoardArea(
                                          state: state,
                                          boardKey: _boardKey,
                                          boardSize: boardSize,
                                          geometry: geometry,
                                          drag: _drag,
                                          boardRepaint: _boardRepaint,
                                          clearController: _clearController,
                                          particles: _particles,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 5,
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          6,
                                          8,
                                          14,
                                          8,
                                        ),
                                        child: Column(
                                          children: [
                                            _GameHud(
                                              state: state,
                                              onBack: _leaveGame,
                                              onSettings: _showSettings,
                                            ),
                                            const Spacer(),
                                            _CartoonTray(
                                              pieces: state.pieces,
                                              disabled: state.isInputLocked,
                                              height: trayHeight,
                                              onStart: _startDrag,
                                              onUpdate: _updateDrag,
                                              onEnd: _endDrag,
                                            ),
                                            const Spacer(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Column(
                                  children: [
                                    SizedBox(
                                      height: headerHeight,
                                      child: _GameHud(
                                        state: state,
                                        onBack: _leaveGame,
                                        onSettings: _showSettings,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    _CartoonBoardArea(
                                      state: state,
                                      boardKey: _boardKey,
                                      boardSize: boardSize,
                                      geometry: geometry,
                                      drag: _drag,
                                      boardRepaint: _boardRepaint,
                                      clearController: _clearController,
                                      particles: _particles,
                                    ),
                                    const Spacer(),
                                    _CartoonTray(
                                      pieces: state.pieces,
                                      disabled: state.isInputLocked,
                                      height: trayHeight,
                                      onStart: _startDrag,
                                      onUpdate: _updateDrag,
                                      onEnd: _endDrag,
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                ),
                        ),
                      ),
                      ValueListenableBuilder<_CartoonDrag?>(
                        valueListenable: _drag,
                        builder: (context, drag, child) {
                          if (drag == null) return const SizedBox.shrink();
                          return AnimatedBuilder(
                            animation: _pickupController,
                            builder: (context, child) => Positioned(
                              left:
                                  drag.position.dx -
                                  drag.piece.width * geometry.cellSize / 2,
                              top:
                                  drag.position.dy -
                                  90 -
                                  drag.piece.height * geometry.cellSize / 2,
                              child: IgnorePointer(
                                child: Transform.scale(
                                  scale:
                                      1 +
                                      Curves.easeOut.transform(
                                            _pickupController.value,
                                          ) *
                                          .06,
                                  child: SizedBox(
                                    width:
                                        drag.piece.width * geometry.cellSize,
                                    height:
                                        drag.piece.height * geometry.cellSize,
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
                      ),
                      if (state.status == GameStatus.continuePrompt ||
                          state.status == GameStatus.adLoading ||
                          state.status == GameStatus.reviving)
                        ContinueOverlay(state: state),
                      if (state.status == GameStatus.results)
                        ResultsOverlay(state: state, onExit: widget.onExit),
                      if (state.status == GameStatus.modeSuccess ||
                          state.status == GameStatus.modeFailure)
                        ModeResultOverlay(
                          state: state,
                          onExit: widget.onExit,
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GameHud extends StatelessWidget {
  const _GameHud({
    required this.state,
    required this.onBack,
    required this.onSettings,
  });

  final GameState state;
  final VoidCallback onBack;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(10, 7, 10, 0),
    child: Row(
      children: [
        RoundGameButton(
          icon: Icons.home_rounded,
          onTap: onBack,
          tooltip: 'Home',
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 15),
                padding: const EdgeInsets.fromLTRB(16, 19, 16, 9),
                decoration: BoxDecoration(
                  color: CartoonColors.paperWarm,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: CartoonColors.outline,
                    width: 3,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 5,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: CartoonColors.yellow,
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        '${state.score}',
                        key: ValueKey(state.score),
                        style: const TextStyle(
                          color: CartoonColors.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (state.combo > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: CartoonColors.pink,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'x${state.combo}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const CartoonRibbon(
                text: 'SCORE',
                width: 150,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        RoundGameButton(
          icon: Icons.settings_rounded,
          onTap: onSettings,
          tooltip: 'Settings',
          blue: true,
        ),
      ],
    ),
  );
}

class _CartoonBoardArea extends StatelessWidget {
  const _CartoonBoardArea({
    required this.state,
    required this.boardKey,
    required this.boardSize,
    required this.geometry,
    required this.drag,
    required this.boardRepaint,
    required this.clearController,
    required this.particles,
  });

  final GameState state;
  final GlobalKey boardKey;
  final double boardSize;
  final BoardGeometry geometry;
  final ValueListenable<_CartoonDrag?> drag;
  final Listenable boardRepaint;
  final AnimationController clearController;
  final List<ClearParticle> particles;

  @override
  Widget build(BuildContext context) {
    final turn = state.turn;
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final turnDrawData = turn == null || state.status != GameStatus.clearing
        ? null
        : TurnDrawData(
            clearCells: turn.clearCells,
            rows: _rows(turn.clearCells),
            columns: _columns(turn.clearCells),
          );

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
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
                color: Color(0x44000000),
                blurRadius: 8,
                offset: Offset(6, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _CartoonBoardPainter(
                    board: state.board,
                    geometry: geometry,
                    hiddenCells: state.status == GameStatus.clearing
                        ? turn?.clearCells ?? const {}
                        : const {},
                  ),
                ),
                AnimatedBuilder(
                  animation: boardRepaint,
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
                        turn: turnDrawData,
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
        Positioned(
          top: -14,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xfff85ba7), Color(0xffdb287f)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: .42)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 4,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              turn?.praise ?? 'MAKE SPACE',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
        if (turn != null && turn.points > 0)
          Positioned(
            bottom: 12,
            child: _PointBubble(points: turn.points),
          ),
      ],
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

class _CartoonBoardPainter extends CustomPainter {
  _CartoonBoardPainter({
    required this.board,
    required this.geometry,
    this.hiddenCells = const {},
  }) : super(repaint: BlockSkin.instance);

  final Board board;
  final BoardGeometry geometry;
  final Set<GridPoint> hiddenCells;

  @override
  void paint(Canvas canvas, Size size) {
    final empty = Paint()..color = const Color(0xffffd9a9);
    final emptyEdge = Paint()
      ..color = const Color(0xffedbf86)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (var row = 0; row < Board.size; row++) {
      for (var col = 0; col < Board.size; col++) {
        final point = GridPoint(row, col);
        final rect = geometry.blockRect(point);
        canvas.drawRRect(rect, empty);
        canvas.drawRRect(rect, emptyEdge);
        final value = board.cells[row][col];
        if (value == null || hiddenCells.contains(point)) continue;
        BlockSkin.instance.paint(canvas, geometry.cellRect(point), value);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CartoonBoardPainter oldDelegate) =>
      oldDelegate.board != board ||
      oldDelegate.geometry != geometry ||
      oldDelegate.hiddenCells != hiddenCells;
}

class _PointBubble extends StatelessWidget {
  const _PointBubble({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(
      color: CartoonColors.yellow,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 4,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Text(
      '+$points',
      style: const TextStyle(
        color: CartoonColors.text,
        fontSize: 17,
        fontWeight: FontWeight.w900,
      ),
    ),
  );
}

class _CartoonTray extends StatelessWidget {
  const _CartoonTray({
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
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          height: height,
          padding: const EdgeInsets.fromLTRB(10, 17, 10, 9),
          decoration: BoxDecoration(
            color: CartoonColors.paperWarm,
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: CartoonColors.outline, width: 4),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 6,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var index = 0; index < pieces.length; index++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _CartoonPieceSlot(
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
        Positioned(
          top: -13,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xffaee62e), Color(0xff75b816)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: .45)),
            ),
            child: const Text(
              'YOUR SHAPES',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _CartoonPieceSlot extends StatelessWidget {
  const _CartoonPieceSlot({
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
        color: const Color(0xffffefd7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xffe6bd91), width: 2),
      ),
      alignment: Alignment.center,
      child: piece == null
          ? const Icon(
              Icons.check_rounded,
              color: CartoonColors.green,
              size: 28,
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final cell = math.min(
                  (constraints.maxWidth - 16) / piece!.width,
                  (constraints.maxHeight - 16) / piece!.height,
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

class _GameplayPaperPattern extends StatelessWidget {
  const _GameplayPaperPattern();

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _DotsPainter(),
  );
}

class _DotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xffe8c7ba).withValues(alpha: .22);
    for (double y = 12; y < size.height; y += 30) {
      for (double x = 12; x < size.width; x += 30) {
        canvas.drawCircle(Offset(x, y), 1.4, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

@immutable
class _CartoonDrag {
  const _CartoonDrag({
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

  _CartoonDrag copyWith({
    Offset? position,
    GridPoint? origin,
    bool? valid,
  }) =>
      _CartoonDrag(
        index: index,
        piece: piece,
        position: position ?? this.position,
        origin: origin ?? this.origin,
        valid: valid ?? this.valid,
      );
}
