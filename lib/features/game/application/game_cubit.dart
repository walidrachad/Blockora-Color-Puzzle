import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/ads/ads_config.dart';
import '../../../core/ads/consent.dart';
import '../../../core/game_feel_config.dart';
import '../../../core/services/services.dart';
import '../domain/game_rules.dart';
import '../domain/game_modes.dart';
import '../domain/mode_catalog.dart';
import '../domain/models.dart';
import '../domain/piece_generator.dart';
import '../domain/revive_policy.dart';

enum GameStatus {
  playing,
  clearing,
  continuePrompt,
  adLoading,
  reviving,
  results,
  modeSuccess,
  modeFailure,
}

class TurnEvent extends Equatable {
  const TurnEvent({
    required this.id,
    required this.placedCells,
    required this.points,
    required this.lines,
    required this.clearCells,
    required this.praise,
    required this.heart,
  });

  final int id;
  final List<GridPoint> placedCells;
  final int points;
  final int lines;
  final Set<GridPoint> clearCells;
  final String? praise;
  final bool heart;

  @override
  List<Object?> get props => [
    id,
    placedCells,
    points,
    lines,
    clearCells,
    praise,
    heart,
  ];
}

class GameState extends Equatable {
  const GameState({
    required this.board,
    required this.pieces,
    required this.score,
    required this.best,
    required this.combo,
    required this.status,
    required this.preferences,
    required bool reviveUsed,
    int? reviveCount,
    this.session = const GameSession.classic(),
    this.progress = const ModeProgressSnapshot(),
    this.hasSavedSession = false,
    this.adsConfig = const AdsRemoteConfig(
      adsEnabled: false,
      bannerEnabled: false,
      interstitialEnabled: false,
      rewardedEnabled: false,
      bannerAndroidAdUnitId: null,
      bannerIosAdUnitId: null,
      interstitialAndroidAdUnitId: null,
      interstitialIosAdUnitId: null,
      rewardedAndroidAdUnitId: null,
      rewardedIosAdUnitId: null,
      bannerShowOnGameplay: true,
      bannerShowOnHome: true,
      bannerShowOnResults: true,
      interstitialEveryNCompletedGames: 3,
      interstitialMinIntervalSeconds: 120,
      interstitialMaxPerSession: 3,
      rewardedReviveEnabled: true,
      rewardedReviveMaxPerGame: 1,
      rewardedReviveCountdownSeconds: 5,
      rewardedReviveStrategy: AdsReviveStrategy.clearMostFilledLine,
      adsPersonalizationEnabled: false,
    ),
    this.completedGames = 0,
    this.rewardedReady = false,
    this.dragIndex,
    this.turn,
    this.reviveCells = const [],
    this.adMessage,
  }) : reviveCount = (reviveCount ?? 0) > 0
           ? (reviveCount ?? 1)
           : (reviveUsed ? 1 : 0);

  factory GameState.newGame({
    required List<Piece> pieces,
    Board? board,
    int best = 0,
    GameSession session = const GameSession.classic(),
    ModeProgressSnapshot progress = const ModeProgressSnapshot(),
    bool hasSavedSession = false,
    AppPreferences preferences = const AppPreferences(),
    AdsRemoteConfig adsConfig = const AdsRemoteConfig(
      adsEnabled: false,
      bannerEnabled: false,
      interstitialEnabled: false,
      rewardedEnabled: false,
      bannerAndroidAdUnitId: null,
      bannerIosAdUnitId: null,
      interstitialAndroidAdUnitId: null,
      interstitialIosAdUnitId: null,
      rewardedAndroidAdUnitId: null,
      rewardedIosAdUnitId: null,
      bannerShowOnGameplay: true,
      bannerShowOnHome: true,
      bannerShowOnResults: true,
      interstitialEveryNCompletedGames: 3,
      interstitialMinIntervalSeconds: 120,
      interstitialMaxPerSession: 3,
      rewardedReviveEnabled: true,
      rewardedReviveMaxPerGame: 1,
      rewardedReviveCountdownSeconds: 5,
      rewardedReviveStrategy: AdsReviveStrategy.clearMostFilledLine,
      adsPersonalizationEnabled: false,
    ),
    int completedGames = 0,
    bool rewardedReady = false,
  }) => GameState(
    board: board ?? Board(),
    pieces: List<Piece?>.from(pieces),
    score: 0,
    best: best,
    combo: 0,
    status: GameStatus.playing,
    preferences: preferences,
    reviveUsed: false,
    session: session,
    progress: progress,
    hasSavedSession: hasSavedSession,
    adsConfig: adsConfig,
    completedGames: completedGames,
    rewardedReady: rewardedReady,
  );

  final Board board;
  final List<Piece?> pieces;
  final int score;
  final int best;
  final int combo;
  final GameStatus status;
  final AppPreferences preferences;
  final int reviveCount;
  final GameSession session;
  final ModeProgressSnapshot progress;
  final bool hasSavedSession;
  bool get reviveUsed => reviveCount > 0;
  final AdsRemoteConfig adsConfig;
  final int completedGames;
  final bool rewardedReady;
  final int? dragIndex;
  final TurnEvent? turn;
  final List<GridPoint> reviveCells;
  final String? adMessage;

  bool get isInputLocked => status != GameStatus.playing;

  GameState copyWith({
    Board? board,
    List<Piece?>? pieces,
    int? score,
    int? best,
    int? combo,
    GameStatus? status,
    AppPreferences? preferences,
    bool? reviveUsed,
    int? reviveCount,
    GameSession? session,
    ModeProgressSnapshot? progress,
    bool? hasSavedSession,
    AdsRemoteConfig? adsConfig,
    int? completedGames,
    bool? rewardedReady,
    Object? dragIndex = _unset,
    Object? turn = _unset,
    List<GridPoint>? reviveCells,
    Object? adMessage = _unset,
  }) {
    final nextReviveCount =
        reviveCount ??
        (reviveUsed == null ? this.reviveCount : (reviveUsed ? 1 : 0));
    return GameState(
      board: board ?? this.board,
      pieces: pieces ?? this.pieces,
      score: score ?? this.score,
      best: best ?? this.best,
      combo: combo ?? this.combo,
      status: status ?? this.status,
      preferences: preferences ?? this.preferences,
      reviveUsed: nextReviveCount > 0,
      reviveCount: nextReviveCount,
      session: session ?? this.session,
      progress: progress ?? this.progress,
      hasSavedSession: hasSavedSession ?? this.hasSavedSession,
      adsConfig: adsConfig ?? this.adsConfig,
      completedGames: completedGames ?? this.completedGames,
      rewardedReady: rewardedReady ?? this.rewardedReady,
      dragIndex: dragIndex == _unset ? this.dragIndex : dragIndex as int?,
      turn: turn == _unset ? this.turn : turn as TurnEvent?,
      reviveCells: reviveCells ?? this.reviveCells,
      adMessage: adMessage == _unset ? this.adMessage : adMessage as String?,
    );
  }

  @override
  List<Object?> get props => [
    board,
    pieces,
    score,
    best,
    combo,
    status,
    preferences.sound,
    preferences.music,
    preferences.vibration,
    reviveCount,
    session,
    progress,
    hasSavedSession,
    adsConfig,
    completedGames,
    rewardedReady,
    dragIndex,
    turn,
    reviveCells,
    adMessage,
  ];
}

const _unset = Object();

class GameCubit extends Cubit<GameState> {
  GameCubit({
    required GameStorage storage,
    AudioService? audio,
    HapticsService? haptics,
    AdsService? ads,
    PieceGenerator? generator,
    RevivePolicy? revivePolicy,
    AdsRemoteConfig? adsConfig,
  }) : _storage = storage,
       _audio = audio ?? SilentAudioService(),
       _haptics = haptics ?? SystemHapticsService(),
       _ads = ads ?? TestAdsService(),
       _generator = generator ?? PieceGenerator(),
       _revivePolicy = revivePolicy ?? MinimalRevivePolicy(),
       _customRevivePolicy = revivePolicy != null,
       _adsConfig = adsConfig ?? AdsRemoteConfig.defaults(),
       super(
         GameState.newGame(
           pieces: (generator ?? PieceGenerator()).nextBatch(),
           adsConfig: adsConfig ?? AdsRemoteConfig.defaults(),
           rewardedReady: ads?.rewardedReadyValue ?? false,
         ),
       ) {
    _ads.rewardedReady.addListener(_onRewardedReadyChanged);
  }

  final GameStorage _storage;
  final AudioService _audio;
  final HapticsService _haptics;
  final AdsService _ads;
  PieceGenerator _generator;
  RevivePolicy _revivePolicy;
  final bool _customRevivePolicy;
  AdsRemoteConfig _adsConfig;
  bool _reviveInFlight = false;
  bool _interstitialRequestStarted = false;
  int _turnCounter = 0;
  Future<void> _saveQueue = Future<void>.value();

  AdsService get ads => _ads;

  AdsRemoteConfig get adsConfig => _adsConfig;

  Iterable<String>? _allowedPieceIds(GameSession session) {
    if (session.mode != GameMode.journey || session.journeyLevelId == null) {
      return null;
    }
    return journeyLevelById(session.journeyLevelId!).availablePieceRules;
  }

  int? _moveLimit(GameSession session) {
    if (session.mode == GameMode.journey && session.journeyLevelId != null) {
      return journeyLevelById(session.journeyLevelId!).moveLimit;
    }
    return session.dailyChallenge?.moveLimit;
  }

  Future<void> startClassic() async {
    final preferences = state.preferences;
    final progress = state.progress;
    _generator = PieceGenerator();
    final session = const GameSession.classic();
    final pieces = _generator.nextBatch();
    _turnCounter = 0;
    emit(
      GameState.newGame(
        pieces: pieces,
        best: progress.classic.bestScore,
        preferences: preferences,
        session: session,
        progress: progress,
        hasSavedSession: true,
        adsConfig: _adsConfig,
        completedGames: state.completedGames,
        rewardedReady: _ads.rewardedReadyValue,
      ),
    );
    _interstitialRequestStarted = false;
    _schedulePersist();
  }

  Future<void> startJourneyLevel(JourneyLevel level) async {
    final preferences = state.preferences;
    final progress = state.progress;
    final board = level.initialBoard;
    _generator = PieceGenerator(seed: level.randomSeed);
    final session = GameSession(
      mode: GameMode.journey,
      journeyLevelId: level.id,
      journeyObjective: level.objective,
      reviveEnabled: level.allowRewardedRevive,
    );
    final pieces = _generator.nextBatch(
      board: board,
      allowedPieceIds: level.availablePieceRules,
    );
    _turnCounter = board.maxPlacementId;
    emit(
      GameState.newGame(
        board: board,
        pieces: pieces,
        best: progress.journey.bestScores[level.id] ?? 0,
        preferences: preferences,
        session: session,
        progress: progress,
        hasSavedSession: true,
        adsConfig: _adsConfig,
        completedGames: state.completedGames,
        rewardedReady: _ads.rewardedReadyValue,
      ),
    );
    _interstitialRequestStarted = false;
    _schedulePersist();
  }

  Future<void> startDailyChallenge(DailyChallenge challenge) async {
    final preferences = state.preferences;
    final progress = state.progress;
    final board = challenge.initialBoard;
    _generator = PieceGenerator(seed: challenge.seed);
    final session = GameSession(
      mode: GameMode.dailyChallenge,
      dailyChallenge: challenge,
      journeyObjective: challenge.objective,
      reviveEnabled: false,
    );
    final pieces = _generator.nextBatch(board: board);
    _turnCounter = board.maxPlacementId;
    emit(
      GameState.newGame(
        board: board,
        pieces: pieces,
        best: progress.daily.bestScoreFor(challenge.dateKey),
        preferences: preferences,
        session: session,
        progress: progress,
        hasSavedSession: true,
        adsConfig: _adsConfig,
        completedGames: state.completedGames,
        rewardedReady: _ads.rewardedReadyValue,
      ),
    );
    _interstitialRequestStarted = false;
    _schedulePersist();
  }

  void _onRewardedReadyChanged() {
    if (!isClosed && state.rewardedReady != _ads.rewardedReadyValue) {
      emit(state.copyWith(rewardedReady: _ads.rewardedReadyValue));
    }
  }

  Future<void> initialize() async {
    final preferences = await _storage.loadPreferences();
    _applyPreferences(preferences);
    unawaited(_audio.preload());
    final storedProgress = await _storage.loadModeProgress();
    final saved = await _storage.loadGame();
    if (saved == null || saved.pieces.length != 3) {
      emit(
        state.copyWith(
          preferences: preferences,
          progress: storedProgress,
          adsConfig: _adsConfig,
          rewardedReady: _ads.rewardedReadyValue,
        ),
      );
      await _persist();
      return;
    }
    _generator = PieceGenerator.fromState(saved.generatorState);
    _turnCounter = saved.board.maxPlacementId;
    final progress = storedProgress == const ModeProgressSnapshot()
        ? saved.progress
        : storedProgress;
    emit(
      GameState(
        board: saved.board,
        pieces: List<Piece?>.from(saved.pieces),
        score: saved.score,
        best: saved.best,
        combo: saved.combo,
        status: GameStatus.playing,
        preferences: preferences,
        reviveUsed: saved.reviveUsed,
        reviveCount: saved.reviveCount,
        session: saved.session,
        progress: progress,
        hasSavedSession: saved.hasSavedSession,
        adsConfig: _adsConfig,
        completedGames: saved.completedGames,
        rewardedReady: _ads.rewardedReadyValue,
      ),
    );
  }

  void _applyPreferences(AppPreferences preferences) {
    _audio.setSoundEnabled(preferences.sound);
    _audio.setMusicEnabled(preferences.music);
  }

  Future<void> _persist() async {
    final snapshot = SavedGame(
      board: state.board,
      pieces: state.pieces,
      score: state.score,
      best: state.best,
      combo: state.combo,
      generatorState: _generator.state,
      reviveUsed: state.reviveUsed,
      reviveCount: state.reviveCount,
      completedGames: state.completedGames,
      session: state.session,
      progress: state.progress,
      hasSavedSession: state.hasSavedSession,
    );
    await _storage.saveGame(snapshot);
    await _storage.saveModeProgress(state.progress);
  }

  /// Serializes writes so a slow storage backend cannot overlap saves from
  /// adjacent turns or let an older snapshot finish after a newer one.
  void _schedulePersist() {
    _saveQueue = _saveQueue
        .catchError((Object _) {})
        .then<void>((_) => _persist())
        .catchError((Object _) {});
  }

  void _scheduleClearGame() {
    _saveQueue = _saveQueue
        .catchError((Object _) {})
        .then<void>((_) => _storage.clearGame())
        .catchError((Object _) {});
  }

  Future<void> persistNow() async {
    if (state.status == GameStatus.results) return;
    _schedulePersist();
    await _saveQueue;
  }

  void pickup(int index) {
    if (state.status != GameStatus.playing ||
        index < 0 ||
        index >= state.pieces.length ||
        state.pieces[index] == null) {
      return;
    }
    _audio.play('pickup');
    if (state.preferences.vibration) _haptics.light();
    emit(state.copyWith(dragIndex: index, adMessage: null));
  }

  void cancelDrag() {
    if (state.dragIndex == null) return;
    if (state.preferences.vibration) _haptics.medium();
    _audio.play('invalid_drop');
    emit(state.copyWith(dragIndex: null));
  }

  void drop({required int index, required GridPoint origin}) {
    if (state.status != GameStatus.playing || state.dragIndex != index) return;
    final piece = state.pieces[index];
    if (piece == null) return;
    final allowedPieceIds = _allowedPieceIds(state.session);
    if (allowedPieceIds != null && !allowedPieceIds.contains(piece.id)) {
      cancelDrag();
      return;
    }
    final placement = evaluatePlacement(state.board, piece, origin);
    if (!placement.valid) {
      cancelDrag();
      return;
    }

    final placementId = ++_turnCounter;
    final placedBoard = state.board.place(
      piece,
      origin,
      placementId: placementId,
    );
    final lines = detectCompletedLines(placedBoard);
    final nextComboValue = nextCombo(
      current: state.combo,
      clearedLine: lines.count > 0,
    );
    final turnScore = scoreTurn(
      piece: piece,
      lines: lines,
      combo: nextComboValue,
    );
    final nextPieces = List<Piece?>.from(state.pieces)..[index] = null;
    final nextSession = state.session.copyWith(
      movesUsed: state.session.movesUsed + 1,
      linesCleared: state.session.linesCleared + lines.count,
      coloredCellsCleared:
          state.session.coloredCellsCleared + placement.cells.length,
    );
    var nextProgress = state.progress;
    final nextScore = state.score + turnScore.points;
    if (nextScore > nextProgress.classic.bestScore &&
        state.session.mode == GameMode.classic) {
      nextProgress = nextProgress.copyWith(
        classic: nextProgress.classic.copyWith(bestScore: nextScore),
      );
    }
    final event = TurnEvent(
      id: placementId,
      placedCells: placement.cells,
      points: turnScore.points,
      lines: lines.count,
      clearCells: lines.uniqueCells,
      praise: lines.count > 0
          ? praiseFor(
              lines: lines.count,
              combo: nextComboValue,
              score: state.score + turnScore.points,
            )
          : null,
      heart:
          (state.score + turnScore.points >= 500 && state.score < 500) ||
          (nextComboValue >= 3 && (state.combo < 3 || nextComboValue % 3 == 0)),
    );
    final nextStatus = lines.count > 0
        ? GameStatus.clearing
        : GameStatus.playing;
    emit(
      state.copyWith(
        board: placedBoard,
        pieces: nextPieces,
        score: nextScore,
        best: nextScore > state.best ? nextScore : state.best,
        combo: nextComboValue,
        status: nextStatus,
        dragIndex: null,
        turn: event,
        session: nextSession,
        progress: nextProgress,
        hasSavedSession: true,
        adMessage: null,
      ),
    );
    if (lines.count > 0) {
      // Exactly one tier is selected for each placement, even when both rows
      // and columns complete at once.
      _audio.playClearLines(lines.count);
    } else {
      _audio.play('placement');
    }
    if (state.preferences.vibration) _haptics.medium();
    if (lines.count > 1) {
      _audio.play('multi_line', intensity: lines.count.toDouble());
    }
    if (nextComboValue >= 2) {
      _audio.play('combo', intensity: nextComboValue.toDouble());
    }
    if (event.heart) _audio.play('heart');
    if (lines.count == 0) {
      _completeTurnWithoutClear(nextPieces);
    }
  }

  void _completeTurnWithoutClear(List<Piece?> pieces) {
    var nextPieces = pieces;
    if (nextPieces.every((piece) => piece == null)) {
      nextPieces = _generator.nextBatch(
        board: state.board,
        guaranteePlayable: true,
        allowedPieceIds: _allowedPieceIds(state.session),
      );
      emit(state.copyWith(pieces: nextPieces));
    }
    final modeStatus = _modeResult(state.board, nextPieces);
    if (modeStatus != null) {
      _emitModeResult(modeStatus);
      return;
    }
    if (isGameOver(state.board, nextPieces)) {
      emit(state.copyWith(status: GameStatus.continuePrompt));
    }
    _schedulePersist();
  }

  GameStatus? _modeResult(Board board, List<Piece?> pieces) {
    if (state.session.mode == GameMode.classic) return null;
    final objective = state.session.objective;
    if (objective != null &&
        objective.isComplete(
          score: state.score,
          lines: state.session.linesCleared,
          coloredCells: state.session.coloredCellsCleared,
        )) {
      return GameStatus.modeSuccess;
    }
    final moveLimit = _moveLimit(state.session);
    if ((moveLimit != null && state.session.movesUsed >= moveLimit) ||
        isGameOver(board, pieces)) {
      return GameStatus.modeFailure;
    }
    return null;
  }

  void _emitModeResult(GameStatus result) {
    var progress = state.progress;
    if (result == GameStatus.modeSuccess) {
      switch (state.session.mode) {
        case GameMode.journey:
          final levelId = state.session.journeyLevelId;
          if (levelId != null) {
            final level = journeyLevelById(levelId);
            progress = progress.copyWith(
              journey: progress.journey.recordCompletion(
                level,
                score: state.score,
                moves: state.session.movesUsed,
                lines: state.session.linesCleared,
                coloredCells: state.session.coloredCellsCleared,
              ),
            );
          }
        case GameMode.dailyChallenge:
          final challenge = state.session.dailyChallenge;
          if (challenge != null) {
            progress = progress.copyWith(
              daily: progress.daily.recordCompletion(
                challenge.dateKey,
                state.score,
              ),
            );
          }
        case GameMode.classic:
          break;
      }
    }
    emit(
      state.copyWith(
        status: result,
        progress: progress,
        hasSavedSession: false,
        dragIndex: null,
        reviveCells: const [],
      ),
    );
    unawaited(_storage.saveModeProgress(progress));
    _scheduleClearGame();
  }

  void finishClear() {
    if (state.status != GameStatus.clearing || state.turn == null) return;
    final clearedBoard = state.board.clear(state.turn!.clearCells);
    var nextPieces = state.pieces;
    if (nextPieces.every((piece) => piece == null)) {
      nextPieces = _generator.nextBatch(
        board: clearedBoard,
        guaranteePlayable: true,
        allowedPieceIds: _allowedPieceIds(state.session),
      );
    }
    final nextStatus = isGameOver(clearedBoard, nextPieces)
        ? GameStatus.continuePrompt
        : GameStatus.playing;
    emit(
      state.copyWith(
        board: clearedBoard,
        pieces: nextPieces,
        status: nextStatus,
        reviveCells: const [],
      ),
    );
    final modeStatus = _modeResult(clearedBoard, nextPieces);
    if (modeStatus != null) {
      _emitModeResult(modeStatus);
      return;
    }
    _audio.play('clear_finish');
    if (state.preferences.vibration) _haptics.heavy();
    _schedulePersist();
  }

  Future<void> requestRevive() async {
    if (state.status != GameStatus.continuePrompt ||
        !state.session.reviveEnabled ||
        state.reviveCount >= state.adsConfig.rewardedReviveMaxPerGame ||
        (_ads is GoogleAdsService && !state.adsConfig.canOfferRewardedRevive) ||
        (_ads is GoogleAdsService && !state.rewardedReady) ||
        _reviveInFlight) {
      return;
    }
    _reviveInFlight = true;
    unawaited(_audio.setAdDucking(true));
    emit(state.copyWith(status: GameStatus.adLoading, adMessage: null));
    AdOutcome outcome;
    try {
      outcome = await _ads.showRewarded();
    } catch (_) {
      outcome = AdOutcome.failed;
    }
    if (isClosed) {
      _reviveInFlight = false;
      return;
    }
    _reviveInFlight = false;
    unawaited(_audio.setAdDucking(false));
    if (outcome != AdOutcome.rewarded) {
      emit(
        state.copyWith(
          status: GameStatus.continuePrompt,
          adMessage: outcome == AdOutcome.dismissedWithoutReward
              ? 'reward_not_completed'
              : 'ad_unavailable',
        ),
      );
      return;
    }
    final result = _revivePolicy.rescue(state.board, state.pieces);
    emit(
      state.copyWith(
        status: GameStatus.reviving,
        reviveCount: state.reviveCount + 1,
        combo: 0,
        reviveCells: result.rescuedCells,
        adMessage: null,
      ),
    );
    _audio.play('revive_success');
    if (state.preferences.vibration) _haptics.heavy();
    await Future<void>.delayed(GameFeelConfig.reviveEssential);
    if (isClosed || state.status != GameStatus.reviving) return;
    emit(
      state.copyWith(
        board: result.board,
        status: GameStatus.playing,
        reviveCells: const [],
      ),
    );
    _schedulePersist();
  }

  void expireContinue() {
    if (state.status != GameStatus.continuePrompt) return;
    _audio.play('game_over');
    emit(
      state.copyWith(
        status: GameStatus.results,
        completedGames: state.completedGames + 1,
        adMessage: null,
      ),
    );
    _scheduleClearGame();
  }

  Future<void> restart() async {
    switch (state.session.mode) {
      case GameMode.classic:
        await startClassic();
      case GameMode.journey:
        await startJourneyLevel(
          journeyLevelById(state.session.journeyLevelId ?? 'journey_01'),
        );
      case GameMode.dailyChallenge:
        await startDailyChallenge(
          state.session.dailyChallenge ??
              dailyChallengeFor(DateTime.now().toUtc()),
        );
    }
    await _saveQueue;
  }

  Future<void> applyAdsConfiguration(
    AdsRemoteConfig config, {
    required bool canRequestAds,
  }) async {
    _adsConfig = config;
    if (!_customRevivePolicy) {
      _revivePolicy = ConfiguredRevivePolicy(
        strategy: config.rewardedReviveStrategy,
      );
    }
    emit(
      state.copyWith(adsConfig: config, rewardedReady: _ads.rewardedReadyValue),
    );
    await _ads.updateConfiguration(
      config: config,
      canRequestAds: canRequestAds,
    );
    _onRewardedReadyChanged();
  }

  Future<AdOutcome> maybeShowInterstitial() async {
    if (state.status != GameStatus.results || _interstitialRequestStarted) {
      return AdOutcome.unavailable;
    }
    if (!state.adsConfig.adsEnabled || !state.adsConfig.interstitialEnabled) {
      return AdOutcome.disabled;
    }
    _interstitialRequestStarted = true;
    await Future<void>.delayed(GameFeelConfig.gameOverInterstitialDelay);
    if (isClosed || state.status != GameStatus.results) {
      return AdOutcome.unavailable;
    }
    return _ads.showInterstitialIfEligible(
      completedGames: state.completedGames,
    );
  }

  Future<ConsentSnapshot> showPrivacyOptions() => _ads.showPrivacyOptions();

  Future<void> updatePreferences(AppPreferences preferences) async {
    _applyPreferences(preferences);
    emit(state.copyWith(preferences: preferences));
    await _storage.savePreferences(preferences);
    _schedulePersist();
  }

  void debugSetBoard(Board board, {List<Piece?>? pieces}) {
    emit(
      state.copyWith(
        board: board,
        pieces: pieces ?? state.pieces,
        status: GameStatus.playing,
      ),
    );
  }

  /// Debug-only setup for testing the line audio and combo feedback in a
  /// running build. The release UI never calls this hook.
  void debugForceLines(int lineCount, {int combo = 0}) {
    final count = lineCount.clamp(1, 3).toInt();
    final cells = List.generate(
      Board.size,
      (_) => List<int?>.filled(Board.size, null),
    );
    for (var row = 0; row < count; row++) {
      for (var col = 0; col < Board.size - 1; col++) {
        cells[row][col] = row + 1;
      }
    }
    final piece =
        PieceLibrary.byId[count == 1
            ? 'dot'
            : count == 2
            ? 'duo_v'
            : 'trio_v']!;
    debugSetBoard(Board(cells), pieces: [piece, null, null]);
    emit(state.copyWith(combo: combo, hasSavedSession: true));
  }

  /// Debug/test hook; production UI never exposes this method.
  void debugForceGameOver() {
    emit(state.copyWith(status: GameStatus.continuePrompt, dragIndex: null));
  }

  @override
  Future<void> close() {
    _ads.rewardedReady.removeListener(_onRewardedReadyChanged);
    _audio.dispose();
    _ads.dispose();
    return super.close();
  }
}
