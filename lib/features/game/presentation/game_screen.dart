import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../app/localization.dart';
import '../../../app/theme.dart';
import '../../../core/ads/ads_config.dart';
import '../../../core/game_feel_config.dart';
import '../../../core/services/services.dart';
import '../application/game_cubit.dart';
import '../domain/game_rules.dart';
import '../domain/game_modes.dart';
import '../domain/mode_catalog.dart';
import '../domain/models.dart';
import 'combo_overlay.dart';
import 'painters/board_painters.dart';
import 'painters/game_painters.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.onExit});

  final VoidCallback? onExit;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _tabletContentMaxWidth = 620.0;
  static const _tabletBoardMaxSize = 480.0;

  final _stackKey = GlobalKey();
  final _boardKey = GlobalKey();
  late final AnimationController _clearController;
  late final AnimationController _floatController;
  late final AnimationController _messageController;
  late final AnimationController _heartController;
  late final AnimationController _pickupController;
  int _lastTurnId = 0;
  late final ValueNotifier<DragVisual?> _dragVisual;
  late final Listenable _boardRepaint;
  List<ClearParticle> _clearParticles = const [];
  BoardGeometry? _boardGeometry;
  final bool _debugCoordinates = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _dragVisual = ValueNotifier<DragVisual?>(null);
    _clearController = AnimationController(
      vsync: this,
      duration: GameFeelConfig.clearTotal,
    );
    _floatController = AnimationController(
      vsync: this,
      duration: GameFeelConfig.floatingScore,
    );
    _messageController = AnimationController(
      vsync: this,
      duration: GameFeelConfig.praise,
    );
    _heartController = AnimationController(
      vsync: this,
      duration: GameFeelConfig.heartPulse,
    );
    _pickupController = AnimationController(
      vsync: this,
      duration: GameFeelConfig.pickup,
    );
    _boardRepaint = Listenable.merge([_dragVisual, _clearController]);
    _clearController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        context.read<GameCubit>().finishClear();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearController.dispose();
    _floatController.dispose();
    _messageController.dispose();
    _heartController.dispose();
    _pickupController.dispose();
    _dragVisual.dispose();
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

  void _onStateChanged(BuildContext context, GameState state) {
    final turn = state.turn;
    if (turn == null || turn.id == _lastTurnId) {
      return;
    }
    _lastTurnId = turn.id;
    _clearParticles = turn.lines == 0
        ? const []
        : buildClearParticles(
            cells: turn.clearCells,
            seed: turn.id,
            lines: turn.lines,
          );
    _floatController.forward(from: 0);
    if (turn.praise != null) _messageController.forward(from: 0);
    if (turn.heart) _heartController.forward(from: 0);
    if (state.status == GameStatus.clearing) _clearController.forward(from: 0);
  }

  void _startDrag(int index, Offset globalPosition) {
    final state = context.read<GameCubit>().state;
    if (state.status != GameStatus.playing ||
        state.pieces[index] == null ||
        _dragVisual.value != null) {
      return;
    }
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stack == null) return;
    _dragVisual.value = DragVisual(
      index: index,
      piece: state.pieces[index]!,
      position: stack.globalToLocal(globalPosition),
    );
    _pickupController.forward(from: 0);
    context.read<GameCubit>().pickup(index);
    _updateDrag(globalPosition);
  }

  void _updateDrag(Offset globalPosition) {
    final drag = _dragVisual.value;
    if (drag == null) return;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    final board = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    final piece = drag.piece;
    final geometry = _boardGeometry;
    if (stack == null || board == null || geometry == null) return;
    final stackPosition = stack.globalToLocal(globalPosition);
    final boardPosition = board.globalToLocal(globalPosition);
    final cell = geometry.cellSize;
    // The piece hovers above the finger, matching the common thumb-safe drag
    // affordance while keeping the target center under the user's x position.
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
    _dragVisual.value = drag.copyWith(
      position: stackPosition,
      origin: origin,
      valid: evaluatePlacement(
        context.read<GameCubit>().state.board,
        piece,
        origin,
      ).valid,
    );
  }

  void _endDrag() {
    final drag = _dragVisual.value;
    if (drag != null && drag.origin != null) {
      context.read<GameCubit>().drop(index: drag.index, origin: drag.origin!);
    } else {
      context.read<GameCubit>().cancelDrag();
    }
    _dragVisual.value = null;
  }

  Future<void> _showSettings() async {
    final cubit = context.read<GameCubit>();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SettingsSheet(
        preferences: cubit.state.preferences,
        ads: cubit.ads,
        onChanged: cubit.updatePreferences,
      ),
    );
  }

  bool _backInFlight = false;

  Future<void> _handleBack() async {
    if (widget.onExit == null || _backInFlight) return;
    _backInFlight = true;
    final cubit = context.read<GameCubit>();
    try {
      if (cubit.state.status == GameStatus.playing ||
          cubit.state.status == GameStatus.clearing) {
        final leave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Leave this run?'),
            content: const Text('Your current progress will be saved.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Stay'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Leave'),
              ),
            ],
          ),
        );
        if (leave != true) return;
        await cubit.persistNow();
      }
      if (mounted) widget.onExit!();
    } finally {
      _backInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameCubit, GameState>(
      listenWhen: (previous, current) => previous.turn != current.turn,
      buildWhen: (previous, current) => previous != current,
      listener: _onStateChanged,
      builder: (context, state) {
        return PopScope(
          canPop: widget.onExit == null,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) unawaited(_handleBack());
          },
          child: Scaffold(
            body: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xff101f63),
                    Color(0xff3b1e71),
                    Color(0xff10123d),
                  ],
                  stops: [0, .52, 1],
                ),
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet =
                        constraints.maxWidth >= 600 &&
                        constraints.maxHeight >= 600;
                    final contentWidth = isTablet
                        ? math.min(constraints.maxWidth, _tabletContentMaxWidth)
                        : constraints.maxWidth;
                    final boardWidth = math.min(
                      contentWidth - 34,
                      math.min(
                        isTablet ? _tabletBoardMaxSize : 352.0,
                        constraints.maxHeight * (isTablet ? .58 : .48),
                      ),
                    );
                    final innerBoardSize =
                        boardWidth - BoardGeometry.contentInset * 2;
                    if (_boardGeometry == null ||
                        _boardGeometry!.size != innerBoardSize) {
                      _boardGeometry = BoardGeometry.fromSize(innerBoardSize);
                    }
                    final boardGeometry = _boardGeometry!;
                    return Stack(
                      key: _stackKey,
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: contentWidth,
                            child: _GameContent(
                              state: state,
                              boardKey: _boardKey,
                              boardSize: boardWidth,
                              geometry: boardGeometry,
                              debugCoordinates: _debugCoordinates,
                              onBack: () => unawaited(_handleBack()),
                              onSettings: _showSettings,
                              onDragStart: _startDrag,
                              onDragUpdate: _updateDrag,
                              onDragEnd: _endDrag,
                              dragVisual: _dragVisual,
                              boardRepaint: _boardRepaint,
                              clearController: _clearController,
                              floatController: _floatController,
                              messageController: _messageController,
                              heartController: _heartController,
                              clearParticles: _clearParticles,
                            ),
                          ),
                        ),
                        if (state.status == GameStatus.playing ||
                            state.status == GameStatus.clearing)
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: SafeArea(
                              top: false,
                              child: AdsBannerSlot(
                                ads: context.read<GameCubit>().ads,
                                placement: AdPlacement.gameplay,
                              ),
                            ),
                          ),
                        ValueListenableBuilder<DragVisual?>(
                          valueListenable: _dragVisual,
                          builder: (context, drag, child) {
                            if (drag == null) return const SizedBox.shrink();
                            return AnimatedBuilder(
                              animation: _pickupController,
                              builder: (context, child) => _DraggedPiece(
                                piece: drag.piece,
                                position: drag.position,
                                cellSize: boardGeometry.cellSize,
                                scale:
                                    1 +
                                    Curves.easeOut.transform(
                                          _pickupController.value,
                                        ) *
                                        .06,
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
          ),
        );
      },
    );
  }
}

@immutable
class DragVisual {
  const DragVisual({
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

  DragVisual copyWith({Offset? position, GridPoint? origin, bool? valid}) =>
      DragVisual(
        index: index,
        piece: piece,
        position: position ?? this.position,
        origin: origin ?? this.origin,
        valid: valid ?? this.valid,
      );
}

class _GameContent extends StatelessWidget {
  const _GameContent({
    required this.state,
    required this.boardKey,
    required this.boardSize,
    required this.geometry,
    required this.debugCoordinates,
    required this.onBack,
    required this.onSettings,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.dragVisual,
    required this.boardRepaint,
    required this.clearController,
    required this.floatController,
    required this.messageController,
    required this.heartController,
    required this.clearParticles,
  });

  final GameState state;
  final GlobalKey boardKey;
  final double boardSize;
  final BoardGeometry geometry;
  final bool debugCoordinates;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final void Function(int index, Offset globalPosition) onDragStart;
  final void Function(Offset globalPosition) onDragUpdate;
  final VoidCallback onDragEnd;
  final ValueListenable<DragVisual?> dragVisual;
  final Listenable boardRepaint;
  final AnimationController clearController;
  final AnimationController floatController;
  final AnimationController messageController;
  final AnimationController heartController;
  final List<ClearParticle> clearParticles;

  @override
  Widget build(BuildContext context) {
    final board = state.board;
    final turn = state.turn;
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          RepaintBoundary(
            child: _Header(
              state: state,
              best: state.best,
              onBack: onBack,
              onSettings: onSettings,
              onDebugGameOver: kDebugMode
                  ? () => context.read<GameCubit>().debugForceGameOver()
                  : null,
            ),
          ),
          SizedBox(
            height: 94,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (state.status == GameStatus.playing ||
                    state.status == GameStatus.clearing)
                  AnimatedBuilder(
                    animation: heartController,
                    builder: (context, child) => Opacity(
                      opacity: (heartController.value * 1.4).clamp(0, 1),
                      child: Transform.scale(
                        scale: .74 + heartController.value * .32,
                        child: const Text(
                          '',
                          style: TextStyle(
                            color: PrismColors.pink,
                            fontSize: 88,
                            shadows: [
                              Shadow(color: PrismColors.pink, blurRadius: 24),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                RepaintBoundary(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: state.score.toDouble()),
                    duration: GameFeelConfig.scoreCounter,
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) => Text(
                      value.round().toString(),
                      semanticsLabel: 'Current score ${value.round()}',
                      style: const TextStyle(
                        fontSize: 43,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1.4,
                        color: PrismColors.ink,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 3,
                  child: Text(
                    state.combo > 1 ? 'COMBO ${state.combo}' : 'SCORE',
                    style: TextStyle(
                      color: state.combo > 1
                          ? PrismColors.yellow
                          : PrismColors.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (state.session.mode != GameMode.classic)
            _ModeProgressStrip(state: state),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                RepaintBoundary(
                  key: const ValueKey('game-board'),
                  child: Container(
                    key: boardKey,
                    width: boardSize,
                    height: boardSize,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: PrismColors.midnight.withValues(alpha: .74),
                      borderRadius: BorderRadius.circular(23),
                      border: Border.all(
                        color: PrismColors.cyan.withValues(alpha: .15),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xff06091f).withValues(alpha: .66),
                          blurRadius: 28,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          RepaintBoundary(
                            child: CustomPaint(
                              painter: BoardStaticPainter(
                                board: board,
                                geometry: geometry,
                                showCoordinates: debugCoordinates,
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                          RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: boardRepaint,
                              builder: (context, child) {
                                final drag = dragVisual.value;
                                return CustomPaint(
                                  painter: BoardEffectsPainter(
                                    geometry: geometry,
                                    previewPiece: drag?.piece,
                                    previewOrigin: drag?.origin,
                                    previewValid: drag?.valid ?? false,
                                    turn: turn == null
                                        ? null
                                        : TurnDrawData(
                                            clearCells: turn.clearCells,
                                            rows: _lineRows(turn.clearCells),
                                            columns: _lineColumns(
                                              turn.clearCells,
                                            ),
                                          ),
                                    clearProgress: clearController.value,
                                    particles: clearParticles,
                                  ),
                                  child: const SizedBox.expand(),
                                );
                              },
                            ),
                          ),
                          if (turn != null &&
                              turn.lines > 0 &&
                              state.combo >= 2)
                            Positioned.fill(
                              child: ComboOverlay(
                                key: ValueKey('combo-${turn.id}'),
                                combo: state.combo,
                                eventId: turn.id,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -24,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _PraiseMessage(
                      controller: messageController,
                      text: turn?.praise,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -10,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: _FloatingPoints(
                        controller: floatController,
                        points: turn?.points ?? 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'DRAG A SHAPE TO PLAY',
            style: TextStyle(
              color: PrismColors.ink.withValues(alpha: .60),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 10),
          RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  for (var index = 0; index < state.pieces.length; index++)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: index == 0 ? 0 : 5,
                          right: index == state.pieces.length - 1 ? 0 : 5,
                        ),
                        child: _PieceSlot(
                          piece: state.pieces[index],
                          index: index,
                          disabled: state.isInputLocked,
                          onDragStart: onDragStart,
                          onDragUpdate: onDragUpdate,
                          onDragEnd: onDragEnd,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 13),
          Text(
            'Place all three to reveal new shapes',
            style: TextStyle(
              color: PrismColors.ink.withValues(alpha: .42),
              fontSize: 11,
            ),
          ),
          if (state.adsConfig.showsBannerAt(AdPlacement.gameplay))
            const SizedBox(height: 62),
        ],
      ),
    );
  }

  List<int> _lineRows(Set<GridPoint> cells) => [
    for (var row = 0; row < Board.size; row++)
      if ([
        for (var col = 0; col < Board.size; col++) GridPoint(row, col),
      ].every(cells.contains))
        row,
  ];

  List<int> _lineColumns(Set<GridPoint> cells) => [
    for (var col = 0; col < Board.size; col++)
      if ([
        for (var row = 0; row < Board.size; row++) GridPoint(row, col),
      ].every(cells.contains))
        col,
  ];
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.best,
    required this.onBack,
    required this.onSettings,
    this.onDebugGameOver,
  });

  final GameState state;
  final int best;
  final VoidCallback onBack;
  final VoidCallback onSettings;
  final VoidCallback? onDebugGameOver;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 62,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
        child: Row(
          children: [
            GestureDetector(
              onLongPress: onDebugGameOver,
              child: _GameBackButton(onTap: onBack),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    size: 17,
                    color: PrismColors.yellow,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$best',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: 'Open settings',
              child: IconButton(
                onPressed: onSettings,
                icon: const Icon(Icons.tune_rounded, color: PrismColors.ink),
                iconSize: 24,
                tooltip: 'Settings',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameBackButton extends StatefulWidget {
  const _GameBackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_GameBackButton> createState() => _GameBackButtonState();
}

class _GameBackButtonState extends State<_GameBackButton> {
  bool _pressed = false;

  void _setPressed(bool pressed) {
    if (mounted && _pressed != pressed) {
      setState(() => _pressed = pressed);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Back to mode selection',
    child: Tooltip(
      message: 'Back to mode selection',
      child: AnimatedScale(
        scale: _pressed ? .9 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(13),
          child: Ink(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [PrismColors.cyan, PrismColors.violet],
              ),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withValues(alpha: .25)),
              boxShadow: [
                BoxShadow(
                  color: PrismColors.cyan.withValues(alpha: .3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: widget.onTap,
              onHighlightChanged: _setPressed,
              splashColor: Colors.white.withValues(alpha: .25),
              highlightColor: Colors.white.withValues(alpha: .12),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: PrismColors.midnight,
                size: 23,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ModeProgressStrip extends StatelessWidget {
  const _ModeProgressStrip({required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final objective = state.session.objective;
    if (objective == null) return const SizedBox.shrink();
    final progress = objective.progress(
      score: state.score,
      lines: state.session.linesCleared,
      coloredCells: state.session.coloredCellsCleared,
    );
    final limit = state.session.mode == GameMode.journey
        ? (state.session.journeyLevelId == null
              ? null
              : journeyLevelById(state.session.journeyLevelId!).moveLimit)
        : state.session.dailyChallenge?.moveLimit;
    final modeLabel = state.session.mode == GameMode.dailyChallenge
        ? 'DAILY'
        : 'JOURNEY';
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 9),
      child: Row(
        children: [
          Text(
            modeLabel,
            style: const TextStyle(
              color: PrismColors.cyan,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 5,
                value: (progress / objective.targetValue).clamp(0, 1),
                backgroundColor: Colors.white.withValues(alpha: .12),
                color: PrismColors.yellow,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$progress/${objective.targetValue}',
            style: const TextStyle(
              color: PrismColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (limit != null) ...[
            const SizedBox(width: 10),
            Text(
              '${state.session.movesUsed}/$limit',
              style: const TextStyle(
                color: PrismColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PieceSlot extends StatelessWidget {
  static const _singleCellPreviewMaxSize = 34.0;

  const _PieceSlot({
    required this.piece,
    required this.index,
    required this.disabled,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  final Piece? piece;
  final int index;
  final bool disabled;
  final void Function(int index, Offset position) onDragStart;
  final void Function(Offset position) onDragUpdate;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: piece == null
          ? 'Empty piece slot'
          : 'Piece ${index + 1}, ${piece!.size} blocks',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: disabled || piece == null
            ? null
            : (details) => onDragStart(index, details.globalPosition),
        onPanUpdate: disabled || piece == null
            ? null
            : (details) => onDragUpdate(details.globalPosition),
        onPanEnd: disabled || piece == null ? null : (_) => onDragEnd(),
        onPanCancel: disabled || piece == null ? null : onDragEnd,
        child: Container(
          height: 108,
          decoration: BoxDecoration(
            color: PrismColors.navy.withValues(alpha: .74),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: .09)),
          ),
          alignment: Alignment.center,
          child: piece == null
              ? Icon(
                  Icons.check_rounded,
                  color: PrismColors.green.withValues(alpha: .50),
                  size: 25,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final fittedCell = math.min(
                      (constraints.maxWidth - 20) / piece!.width,
                      (constraints.maxHeight - 20) / piece!.height,
                    );
                    final cell = piece!.size == 1
                        ? math.min(fittedCell, _singleCellPreviewMaxSize)
                        : fittedCell;
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
      ),
    );
  }
}

class _DraggedPiece extends StatelessWidget {
  const _DraggedPiece({
    required this.piece,
    required this.position,
    required this.cellSize,
    required this.scale,
  });

  final Piece piece;
  final Offset position;
  final double cellSize;
  final double scale;

  @override
  Widget build(BuildContext context) => Positioned(
    left: position.dx - piece.width * cellSize / 2,
    top: position.dy - 90 - piece.height * cellSize / 2,
    child: IgnorePointer(
      child: Opacity(
        opacity: .96,
        child: Transform.scale(
          scale: scale,
          child: SizedBox(
            width: piece.width * cellSize,
            height: piece.height * cellSize,
            child: CustomPaint(
              painter: PiecePainter(piece: piece, cellSize: cellSize),
            ),
          ),
        ),
      ),
    ),
  );
}

class _FloatingPoints extends StatelessWidget {
  const _FloatingPoints({required this.controller, required this.points});

  final AnimationController controller;
  final int points;

  @override
  Widget build(BuildContext context) {
    if (points <= 0) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(controller.value);
        return Opacity(
          opacity: (1 - t * 1.1).clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, -t * 32),
            child: Transform.scale(scale: .85 + t * .25, child: child),
          ),
        );
      },
      child: Text(
        '+$points',
        style: const TextStyle(
          color: PrismColors.yellow,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: PrismColors.orange, blurRadius: 10)],
        ),
      ),
    );
  }
}

class _PraiseMessage extends StatelessWidget {
  const _PraiseMessage({required this.controller, required this.text});

  final AnimationController controller;
  final String? text;

  @override
  Widget build(BuildContext context) {
    if (text == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final entry = Curves.elasticOut.transform(
          (controller.value * 2).clamp(0, 1),
        );
        final opacity = controller.value < .76
            ? 1.0
            : ((1 - controller.value) / .24).clamp(0, 1);
        return Opacity(
          opacity: opacity.toDouble(),
          child: Transform.scale(scale: .65 + entry * .4, child: child),
        );
      },
      child: Text(
        text!,
        style: const TextStyle(
          color: PrismColors.ink,
          fontSize: 18,
          fontWeight: FontWeight.w900,
          shadows: [
            Shadow(color: PrismColors.cyan, blurRadius: 12),
            Shadow(color: PrismColors.pink, blurRadius: 8),
          ],
        ),
      ),
    );
  }
}

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({
    super.key,
    required this.preferences,
    required this.ads,
    required this.onChanged,
  });

  final AppPreferences preferences;
  final AdsService ads;
  final Future<void> Function(AppPreferences preferences) onChanged;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late AppPreferences _preferences = widget.preferences;

  Future<void> _toggle(AppPreferences next) async {
    setState(() => _preferences = next);
    await widget.onChanged(next);
  }

  Future<void> _showPrivacyOptions() async {
    await widget.ads.showPrivacyOptions();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
        decoration: const BoxDecoration(
          color: PrismColors.navy,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Text(
                  'Settings',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                const Icon(Icons.tune_rounded, color: PrismColors.cyan),
                IconButton(
                  tooltip: 'Close settings',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SettingSwitch(
              title: 'Sound effects',
              icon: Icons.volume_up_rounded,
              value: _preferences.sound,
              onChanged: (value) =>
                  _toggle(_preferences.copyWith(sound: value)),
            ),
            _SettingSwitch(
              title: 'Music',
              icon: Icons.music_note_rounded,
              value: _preferences.music,
              onChanged: (value) =>
                  _toggle(_preferences.copyWith(music: value)),
            ),
            _SettingSwitch(
              title: 'Vibration',
              icon: Icons.vibration_rounded,
              value: _preferences.vibration,
              onChanged: (value) =>
                  _toggle(_preferences.copyWith(vibration: value)),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: widget.ads.privacyOptionsRequired,
              builder: (context, required, child) {
                if (!required) return const SizedBox.shrink();
                return ListTile(
                  leading: const Icon(
                    Icons.manage_accounts_outlined,
                    color: PrismColors.muted,
                  ),
                  title: const Text('Privacy choices'),
                  subtitle: const Text('Manage ad consent'),
                  onTap: _showPrivacyOptions,
                );
              },
            ),
            const Divider(color: Colors.white12, height: 22),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({
    required this.title,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    secondary: Icon(icon, color: value ? PrismColors.cyan : PrismColors.muted),
    title: Text(title),
    value: value,
    onChanged: onChanged,
    activeThumbColor: PrismColors.cyan,
  );
}

class ContinueOverlay extends StatefulWidget {
  const ContinueOverlay({super.key, required this.state});

  final GameState state;

  @override
  State<ContinueOverlay> createState() => _ContinueOverlayState();
}

class _ContinueOverlayState extends State<ContinueOverlay>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  bool _wasRunningBeforeLifecyclePause = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: Duration(
        seconds: widget.state.adsConfig.rewardedReviveCountdownSeconds,
      ),
    )..addStatusListener(_onStatus);
    if (widget.state.status == GameStatus.continuePrompt) {
      _controller.forward();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      context.read<GameCubit>().expireContinue();
    }
  }

  @override
  void didUpdateWidget(covariant ContinueOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.adsConfig.rewardedReviveCountdownSeconds !=
        widget.state.adsConfig.rewardedReviveCountdownSeconds) {
      _controller.duration = Duration(
        seconds: widget.state.adsConfig.rewardedReviveCountdownSeconds,
      );
    }
    if (widget.state.status == GameStatus.adLoading ||
        widget.state.status == GameStatus.reviving ||
        widget.state.status == GameStatus.results) {
      _controller.stop();
    } else if (widget.state.status == GameStatus.continuePrompt &&
        oldWidget.state.status != GameStatus.continuePrompt) {
      _controller.forward(from: 0);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasRunningBeforeLifecyclePause = _controller.isAnimating;
      _controller.stop();
    } else if (state == AppLifecycleState.resumed &&
        _wasRunningBeforeLifecyclePause &&
        widget.state.status == GameStatus.continuePrompt) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = PrismLocalizations.of(context);
    final cubit = context.read<GameCubit>();
    final isGoogleAds = cubit.ads is GoogleAdsService;
    final canOfferRevive =
        !isGoogleAds ||
        (widget.state.adsConfig.canOfferRewardedRevive &&
            widget.state.adsConfig.rewardedReviveMaxPerGame >
                widget.state.reviveCount &&
            widget.state.rewardedReady);
    final showReviveButton =
        !isGoogleAds || widget.state.reviveUsed || canOfferRevive;
    final countdownSeconds =
        widget.state.adsConfig.rewardedReviveCountdownSeconds;
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: ColoredBox(
          color: const Color(0xff030617).withValues(alpha: .86),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final remaining = math.max(
                0,
                (countdownSeconds * (1 - _controller.value)).ceil(),
              );
              final loading = widget.state.status == GameStatus.adLoading;
              final reviving = widget.state.status == GameStatus.reviving;
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 30,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.continueTitle,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        reviving
                            ? l10n.restoringMove
                            : loading
                            ? l10n.loadingReward
                            : l10n.reviveDescription,
                        style: const TextStyle(
                          color: PrismColors.muted,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 204,
                        height: 204,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size.square(204),
                              painter: CountdownPainter(
                                progress: 1 - _controller.value,
                              ),
                            ),
                            Text(
                              loading || reviving ? '…' : '$remaining',
                              style: const TextStyle(
                                fontSize: 68,
                                fontWeight: FontWeight.w900,
                                color: PrismColors.ink,
                                shadows: [
                                  Shadow(
                                    color: PrismColors.cyan,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.state.adMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          l10n.adMessage(widget.state.adMessage),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: PrismColors.orange,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 26),
                      if (showReviveButton)
                        Semantics(
                          button: true,
                          label: widget.state.reviveUsed
                              ? l10n.reviveUsed
                              : l10n.watchReward,
                          child: SizedBox(
                            width: 244,
                            height: 58,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient:
                                    widget.state.reviveUsed ||
                                        loading ||
                                        reviving
                                    ? const LinearGradient(
                                        colors: [
                                          Color(0xff506080),
                                          Color(0xff33405f),
                                        ],
                                      )
                                    : const LinearGradient(
                                        colors: [
                                          Color(0xff58eaa0),
                                          Color(0xff20b979),
                                        ],
                                      ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  if (!widget.state.reviveUsed &&
                                      !loading &&
                                      !reviving)
                                    BoxShadow(
                                      color: PrismColors.green.withValues(
                                        alpha: .35,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed:
                                    widget.state.reviveUsed ||
                                        loading ||
                                        reviving
                                    ? null
                                    : () => context
                                          .read<GameCubit>()
                                          .requestRevive(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  disabledBackgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  foregroundColor: PrismColors.midnight,
                                  disabledForegroundColor: Colors.white54,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                ),
                                icon: Icon(
                                  loading || reviving
                                      ? Icons.hourglass_top_rounded
                                      : Icons.ondemand_video_rounded,
                                  size: 23,
                                ),
                                label: Text(
                                  widget.state.reviveUsed
                                      ? l10n.reviveUsedButton
                                      : loading
                                      ? l10n.loading
                                      : reviving
                                      ? l10n.reviving
                                      : l10n.revive,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.8,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                      else ...[
                        Text(
                          l10n.videoUnavailable,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: PrismColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      if (widget.state.status == GameStatus.continuePrompt)
                        TextButton(
                          onPressed: () =>
                              context.read<GameCubit>().expireContinue(),
                          child: Text(l10n.noThanks),
                        ),
                      const SizedBox(height: 15),
                      Text(
                        widget.state.reviveUsed
                            ? l10n.reviveUsedDescription
                            : l10n.oneRevivePerRun,
                        style: TextStyle(
                          color: PrismColors.ink.withValues(alpha: .45),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class ResultsOverlay extends StatefulWidget {
  const ResultsOverlay({super.key, required this.state, this.onExit});

  final GameState state;
  final VoidCallback? onExit;

  @override
  State<ResultsOverlay> createState() => _ResultsOverlayState();
}

class _ResultsOverlayState extends State<ResultsOverlay> {
  GameState get state => widget.state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<GameCubit>().maybeShowInterstitial());
    });
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Material(
      color: const Color(0xff030617).withValues(alpha: .90),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Container(
            width: 340,
            padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
            decoration: prismPanel(radius: 28).copyWith(
              border: Border.all(
                color: PrismColors.cyan.withValues(alpha: .22),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: PrismColors.yellow,
                  size: 26,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Game Over',
                  style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'That was a brilliant run.',
                  style: TextStyle(color: PrismColors.muted),
                ),
                const SizedBox(height: 26),
                Text(
                  '${state.score}',
                  style: const TextStyle(
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                    color: PrismColors.ink,
                  ),
                ),
                const Text(
                  'FINAL SCORE',
                  style: TextStyle(
                    color: PrismColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: PrismColors.yellow.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.emoji_events_rounded,
                        color: PrismColors.yellow,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'BEST  ${state.best}',
                        style: const TextStyle(
                          color: PrismColors.yellow,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                if (state.score == state.best && state.score > 0) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'NEW BEST!',
                    style: TextStyle(
                      color: PrismColors.pink,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      shadows: [Shadow(color: PrismColors.pink, blurRadius: 9)],
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () => context.read<GameCubit>().restart(),
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text(
                      'PLAY AGAIN',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PrismColors.cyan,
                      foregroundColor: PrismColors.midnight,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: widget.onExit ?? context.read<GameCubit>().restart,
                  icon: const Icon(Icons.home_rounded, size: 19),
                  label: const Text('Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class ModeResultOverlay extends StatelessWidget {
  const ModeResultOverlay({super.key, required this.state, this.onExit});

  final GameState state;
  final VoidCallback? onExit;

  void _leave(BuildContext context) {
    if (onExit != null) {
      onExit!();
    } else {
      Navigator.maybePop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final success = state.status == GameStatus.modeSuccess;
    final isDaily = state.session.mode == GameMode.dailyChallenge;
    final level = state.session.journeyLevelId == null
        ? null
        : journeyLevelById(state.session.journeyLevelId!);
    final stars = success && level != null
        ? level.starsFor(
            score: state.score,
            lines: state.session.linesCleared,
            coloredCells: state.session.coloredCellsCleared,
            moves: state.session.movesUsed,
          )
        : 0;
    final objective = state.session.objective;
    final progress = objective?.progress(
      score: state.score,
      lines: state.session.linesCleared,
      coloredCells: state.session.coloredCellsCleared,
    );
    return Positioned.fill(
      child: Material(
        color: const Color(0xff030617).withValues(alpha: .90),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: Container(
              width: 340,
              padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
              decoration: prismPanel(radius: 28).copyWith(
                border: Border.all(
                  color: success ? PrismColors.yellow : PrismColors.pink,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    success
                        ? Icons.emoji_events_rounded
                        : Icons.refresh_rounded,
                    color: success ? PrismColors.yellow : PrismColors.pink,
                    size: 34,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    success
                        ? (isDaily ? 'Daily Complete' : 'Level Complete')
                        : (isDaily ? 'Daily Challenge' : 'Keep Going'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    success
                        ? (isDaily
                              ? 'Today is safely on your streak.'
                              : 'A bright move unlocks the next level.')
                        : 'Your objective was not reached this run.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: PrismColors.muted),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    '${state.score}',
                    style: const TextStyle(
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                      color: PrismColors.ink,
                    ),
                  ),
                  if (objective != null && progress != null)
                    Text(
                      '${objective.type.label.toUpperCase()}  $progress/${objective.targetValue}',
                      style: const TextStyle(
                        color: PrismColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  if (stars > 0) ...[
                    const SizedBox(height: 16),
                    Text(
                      '${'★' * stars}${'☆' * (3 - stars)}',
                      style: const TextStyle(
                        color: PrismColors.yellow,
                        fontSize: 28,
                        letterSpacing: 5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: success
                          ? () => _leave(context)
                          : () => context.read<GameCubit>().restart(),
                      icon: Icon(
                        success
                            ? Icons.arrow_forward_rounded
                            : Icons.replay_rounded,
                      ),
                      label: Text(
                        success
                            ? (isDaily ? 'DONE' : 'NEXT LEVEL')
                            : 'TRY AGAIN',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: success
                            ? PrismColors.cyan
                            : PrismColors.pink,
                        foregroundColor: PrismColors.midnight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: success
                        ? () => context.read<GameCubit>().restart()
                        : () => _leave(context),
                    icon: Icon(
                      success ? Icons.replay_rounded : Icons.arrow_back_rounded,
                      size: 19,
                    ),
                    label: Text(success ? 'Replay' : 'Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
