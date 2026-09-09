import 'package:flutter_test/flutter_test.dart';

import 'package:prism_puzzle/core/services/services.dart';
import 'package:prism_puzzle/features/game/application/game_cubit.dart';
import 'package:prism_puzzle/features/game/domain/game_modes.dart';
import 'package:prism_puzzle/features/game/domain/mode_catalog.dart';
import 'package:prism_puzzle/features/game/domain/models.dart';

class ModeCubitStorage implements GameStorage {
  SavedGame? game;

  @override
  Future<void> clearGame() async => game = null;

  @override
  Future<SavedGame?> loadGame() async => game;

  @override
  Future<AppPreferences> loadPreferences() async => const AppPreferences();

  @override
  Future<void> saveGame(SavedGame value) async => game = value;

  @override
  Future<void> savePreferences(AppPreferences value) async {}
}

Board _lineSetup() {
  final cells = List.generate(
    Board.size,
    (_) => List<int?>.filled(Board.size, null),
  );
  for (var col = 0; col < Board.size - 1; col++) {
    cells[0][col] = 1;
  }
  return Board(cells);
}

void main() {
  late ModeCubitStorage storage;
  late GameCubit cubit;

  setUp(() async {
    storage = ModeCubitStorage();
    cubit = GameCubit(storage: storage);
    await cubit.initialize();
  });

  tearDown(() async => cubit.close());

  test('Journey starts from its data and restricts its piece rules', () async {
    final level = journeyLevels.first;
    await cubit.startJourneyLevel(level);
    expect(cubit.state.session.mode, GameMode.journey);
    expect(cubit.state.session.journeyLevelId, level.id);
    expect(cubit.state.board, level.initialBoard);
    expect(
      cubit.state.pieces.every(
        (piece) =>
            piece == null || level.availablePieceRules.contains(piece.id),
      ),
      isTrue,
    );
  });

  test('Daily line completion records progress and disables revive', () async {
    final challenge = DailyChallenge(
      dateKey: '2026-09-03',
      seed: 7,
      objective: const JourneyObjective(
        type: JourneyObjectiveType.lines,
        targetValue: 1,
      ),
      initialBoard: _lineSetup(),
      moveLimit: 8,
      configurationVersion: 'test',
    );
    await cubit.startDailyChallenge(challenge);
    cubit.debugSetBoard(
      _lineSetup(),
      pieces: [PieceLibrary.byId['dot'], null, null],
    );
    cubit.pickup(0);
    cubit.drop(index: 0, origin: const GridPoint(0, 7));
    expect(cubit.state.status, GameStatus.clearing);
    cubit.finishClear();
    expect(cubit.state.status, GameStatus.modeSuccess);
    expect(cubit.state.session.reviveEnabled, isFalse);
    expect(cubit.state.progress.daily.isCompleted('2026-09-03'), isTrue);
  });

  test('active Journey session restores from persistence', () async {
    await cubit.startJourneyLevel(journeyLevels[4]);
    await cubit.persistNow();

    final restored = GameCubit(storage: storage);
    await restored.initialize();
    expect(restored.state.hasSavedSession, isTrue);
    expect(restored.state.session.mode, GameMode.journey);
    expect(restored.state.session.journeyLevelId, 'journey_05');
    await restored.close();
  });

  test('Daily and Journey sessions reject rewarded revive', () async {
    await cubit.startJourneyLevel(journeyLevels.first);
    cubit.debugForceGameOver();
    await cubit.requestRevive();
    expect(cubit.state.status, GameStatus.continuePrompt);
  });
}
