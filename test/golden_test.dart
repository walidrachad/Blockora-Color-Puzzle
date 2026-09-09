import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:prism_puzzle/app/theme.dart';
import 'package:prism_puzzle/core/services/services.dart';
import 'package:prism_puzzle/features/game/application/game_cubit.dart';
import 'package:prism_puzzle/features/game/domain/models.dart';
import 'package:prism_puzzle/features/game/domain/piece_generator.dart';
import 'package:prism_puzzle/features/game/presentation/game_screen.dart';

class GoldenStorage implements GameStorage {
  @override
  Future<void> clearGame() async {}

  @override
  Future<SavedGame?> loadGame() async => null;

  @override
  Future<AppPreferences> loadPreferences() async => const AppPreferences();

  @override
  Future<void> saveGame(SavedGame game) async {}

  @override
  Future<void> savePreferences(AppPreferences preferences) async {}
}

void main() {
  late GameCubit cubit;

  setUp(() async {
    cubit = GameCubit(
      storage: GoldenStorage(),
      generator: PieceGenerator(seed: 100),
    );
    await cubit.initialize();
  });

  tearDown(() async => cubit.close());

  Widget app() => MaterialApp(
    theme: prismTheme(),
    home: BlocProvider.value(value: cubit, child: const GameScreen()),
  );

  testWidgets('gameplay screen golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(382, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/gameplay.png'),
    );
  });

  testWidgets('continue overlay golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(382, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    cubit.debugForceGameOver();
    await tester.pump(const Duration(milliseconds: 100));
    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/continue.png'),
    );
  });

  testWidgets('results screen golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(382, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    cubit.debugForceGameOver();
    cubit.expireContinue();
    await tester.pump();
    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/results.png'),
    );
  });

  testWidgets('rainbow clear effect golden', (tester) async {
    await tester.binding.setSurfaceSize(const Size(382, 848));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app());
    final board = Board(
      List.generate(
        Board.size,
        (row) =>
            List.generate(Board.size, (col) => row == 0 && col < 7 ? 3 : null),
      ),
    );
    cubit.debugSetBoard(board, pieces: [PieceLibrary.byId['dot'], null, null]);
    cubit.pickup(0);
    cubit.drop(index: 0, origin: const GridPoint(0, 7));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await expectLater(
      find.byType(GameScreen),
      matchesGoldenFile('goldens/clear.png'),
    );
  });
}
