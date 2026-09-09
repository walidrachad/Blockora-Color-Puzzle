import 'package:flutter_test/flutter_test.dart';
import 'package:prism_puzzle/core/services/services.dart';
import 'package:prism_puzzle/features/game/application/game_cubit.dart';
import 'package:prism_puzzle/features/game/domain/models.dart';
import 'package:prism_puzzle/features/game/domain/piece_generator.dart';

class MemoryStorage implements GameStorage {
  SavedGame? game;
  AppPreferences preferences = const AppPreferences();

  @override
  Future<void> clearGame() async => game = null;

  @override
  Future<SavedGame?> loadGame() async => game;

  @override
  Future<AppPreferences> loadPreferences() async => preferences;

  @override
  Future<void> saveGame(SavedGame value) async => game = value;

  @override
  Future<void> savePreferences(AppPreferences value) async =>
      preferences = value;
}

class ImmediateAds implements AdsService {
  ImmediateAds(this.outcome);
  AdOutcome outcome;

  @override
  Future<AdOutcome> showRewarded() async => outcome;

  @override
  void dispose() {}
}

class RecordingAudio implements AudioService {
  bool soundEnabled = true;
  bool musicEnabled = true;
  final List<String> cues = [];

  @override
  void dispose() {}

  @override
  void play(String cue, {double intensity = 1}) => cues.add(cue);

  @override
  void setMusicEnabled(bool enabled) => musicEnabled = enabled;

  @override
  void setSoundEnabled(bool enabled) => soundEnabled = enabled;
}

class RecordingHaptics implements HapticsService {
  int lightCount = 0;
  int mediumCount = 0;
  int heavyCount = 0;

  @override
  void heavy() => heavyCount++;

  @override
  void light() => lightCount++;

  @override
  void medium() => mediumCount++;
}

void main() {
  late MemoryStorage storage;
  late GameCubit cubit;
  late RecordingAudio audio;
  late RecordingHaptics haptics;

  setUp(() async {
    storage = MemoryStorage();
    audio = RecordingAudio();
    haptics = RecordingHaptics();
    cubit = GameCubit(
      storage: storage,
      generator: PieceGenerator(seed: 3),
      ads: ImmediateAds(AdOutcome.rewarded),
      audio: audio,
      haptics: haptics,
    );
    await cubit.initialize();
  });

  tearDown(() async {
    await cubit.close();
  });

  test('settings apply to feedback services and persist', () async {
    const disabled = AppPreferences(
      sound: false,
      music: false,
      vibration: false,
    );
    await cubit.updatePreferences(disabled);

    expect(cubit.state.preferences, disabled);
    expect(storage.preferences, disabled);
    expect(audio.soundEnabled, isFalse);
    expect(audio.musicEnabled, isFalse);

    cubit.pickup(0);
    expect(haptics.lightCount, 0);

    await cubit.updatePreferences(disabled.copyWith(vibration: true));
    cubit.pickup(0);
    expect(haptics.lightCount, 1);
    cubit.cancelDrag();
    expect(haptics.mediumCount, 1);
  });

  test('pickup, valid drop, and invalid drop update explicit state', () {
    final piece = cubit.state.pieces.first!;
    cubit.pickup(0);
    expect(cubit.state.dragIndex, 0);
    cubit.drop(index: 0, origin: const GridPoint(0, 0));
    expect(cubit.state.board.filledCount, piece.size);
    expect(cubit.state.pieces.first, isNull);
    cubit.pickup(1);
    cubit.drop(index: 1, origin: const GridPoint(-1, -1));
    expect(cubit.state.dragIndex, isNull);
  });

  test('drag pickup and return trigger their dedicated audio cues', () {
    cubit.pickup(0);
    cubit.cancelDrag();

    expect(audio.cues, ['pickup', 'invalid_drop']);
  });

  test('asym gameplay placement occupies exactly four board cells', () {
    final asym = PieceLibrary.byId['asym']!;
    cubit.debugSetBoard(Board(), pieces: [asym, null, null]);
    cubit.pickup(0);
    cubit.drop(index: 0, origin: const GridPoint(0, 0));

    expect(cubit.state.board.filledCount, 4);
    expect(cubit.state.board[const GridPoint(0, 0)], asym.color);
    expect(cubit.state.board[const GridPoint(0, 1)], asym.color);
    expect(cubit.state.board[const GridPoint(1, 1)], asym.color);
    expect(cubit.state.board[const GridPoint(2, 1)], asym.color);
    expect(cubit.state.board[const GridPoint(1, 2)], isNull);
  });

  test(
    'clear sequence locks input until the clear animation is completed',
    () async {
      final board = Board(
        List.generate(
          8,
          (row) => List.generate(8, (col) => row == 0 && col < 7 ? 2 : null),
        ),
      );
      cubit.debugSetBoard(
        board,
        pieces: [PieceLibrary.byId['dot'], null, null],
      );
      cubit.pickup(0);
      cubit.drop(index: 0, origin: const GridPoint(0, 7));
      expect(cubit.state.status, GameStatus.clearing);
      cubit.pickup(0);
      expect(cubit.state.dragIndex, isNull);
      cubit.finishClear();
      expect(cubit.state.status, GameStatus.playing);
      expect(cubit.state.board.cells[0].every((cell) => cell == null), isTrue);
    },
  );

  test(
    'countdown expiration enters results and clears the active save',
    () async {
      cubit.debugForceGameOver();
      expect(cubit.state.status, GameStatus.continuePrompt);
      cubit.expireContinue();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.status, GameStatus.results);
      expect(audio.cues, contains('game_over'));
      expect(storage.game, isNull);
    },
  );

  test('rewarded revive is consumed once and restores a valid move', () async {
    final board = Board(List.generate(8, (_) => List<int?>.filled(8, 3)));
    cubit.debugSetBoard(board, pieces: [PieceLibrary.byId['dot'], null, null]);
    cubit.debugForceGameOver();
    await cubit.requestRevive();
    expect(cubit.state.reviveUsed, isTrue);
    expect(cubit.state.status, GameStatus.playing);
    expect(cubit.state.board.filledCount, 63);
    expect(cubit.state.pieces.first, isNotNull);
  });

  test('dismissed reward does not revive', () async {
    final ads = ImmediateAds(AdOutcome.dismissed);
    final dismissed = GameCubit(
      storage: storage,
      generator: PieceGenerator(seed: 3),
      ads: ads,
    );
    await dismissed.initialize();
    dismissed.debugForceGameOver();
    await dismissed.requestRevive();
    expect(dismissed.state.status, GameStatus.continuePrompt);
    expect(dismissed.state.reviveUsed, isFalse);
    await dismissed.close();
  });
}
