import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:prism_puzzle/app/theme.dart';
import 'package:prism_puzzle/core/services/services.dart';
import 'package:prism_puzzle/features/game/application/game_cubit.dart';
import 'package:prism_puzzle/features/game/domain/models.dart';
import 'package:prism_puzzle/features/game/domain/piece_generator.dart';
import 'package:prism_puzzle/features/game/presentation/game_screen.dart';

class WidgetMemoryStorage implements GameStorage {
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
      storage: WidgetMemoryStorage(),
      generator: PieceGenerator(seed: 11),
    );
    await cubit.initialize();
  });

  tearDown(() async => cubit.close());

  Widget app() => MaterialApp(
    theme: prismTheme(),
    home: BlocProvider.value(value: cubit, child: const GameScreen()),
  );

  testWidgets(
    'responsive gameplay screen renders board, score, and three slots',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(382, 848));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app());
      expect(find.byTooltip('Back to home'), findsOneWidget);
      expect(find.text('DRAG A SHAPE TO PLAY'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.byType(AdsBannerSlot), findsOneWidget);
      expect(find.bySemanticsLabel('Open settings'), findsOneWidget);
    },
  );

  testWidgets(
    'gameplay screen scales cleanly on tablet portrait and landscape',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(768, 1024));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app());
      expect(
        tester.getSize(find.byKey(const ValueKey('game-board'))).width,
        greaterThan(352),
      );
      expect(find.text('DRAG A SHAPE TO PLAY'), findsOneWidget);

      await tester.binding.setSurfaceSize(const Size(1024, 768));
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byKey(const ValueKey('game-board'))).width,
        greaterThan(352),
      );
      expect(find.byType(AdsBannerSlot), findsOneWidget);
    },
  );

  testWidgets('game header back button confirms and invokes exit', (
    tester,
  ) async {
    var didExit = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: prismTheme(),
        home: BlocProvider.value(
          value: cubit,
          child: GameScreen(onExit: () => didExit = true),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Back to home'));
    await tester.pumpAndSettle();
    expect(find.text('Leave this run?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(didExit, isTrue);
  });

  testWidgets('tray exposes the replacement piece as four blocks', (
    tester,
  ) async {
    cubit.debugSetBoard(
      Board(),
      pieces: [PieceLibrary.byId['asym'], null, null],
    );
    await tester.pumpWidget(app());
    expect(find.bySemanticsLabel('Piece 1, 4 blocks'), findsOneWidget);
  });

  testWidgets('single-cell tray pieces stay compact inside their slot', (
    tester,
  ) async {
    cubit.debugSetBoard(
      Board(),
      pieces: [PieceLibrary.byId['dot'], null, null],
    );
    await tester.pumpWidget(app());

    final preview = find.descendant(
      of: find.bySemanticsLabel('Piece 1, 1 blocks'),
      matching: find.byType(CustomPaint),
    );
    expect(preview, findsOneWidget);
    expect(tester.getSize(preview), const Size(34, 34));
  });

  testWidgets('settings sheet is reachable and closes cleanly', (tester) async {
    await tester.pumpWidget(app());
    await tester.tap(find.bySemanticsLabel('Open settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Sound effects'), findsOneWidget);
    await tester.tap(find.byTooltip('Close settings'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app());
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('settings switches update sound, music, and vibration', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.tap(find.bySemanticsLabel('Open settings'));
    await tester.pumpAndSettle();

    final switches = find.byType(SwitchListTile);
    expect(switches, findsNWidgets(3));
    for (var index = 0; index < 3; index++) {
      await tester.tap(switches.at(index));
      await tester.pump();
    }

    expect(cubit.state.preferences.sound, isFalse);
    expect(cubit.state.preferences.music, isFalse);
    expect(cubit.state.preferences.vibration, isFalse);
  });

  testWidgets(
    'revive button exposes loading state and results screen has replay',
    (tester) async {
      await tester.pumpWidget(app());
      cubit.debugForceGameOver();
      await tester.pump();
      await tester.tap(find.text('REVIVE'));
      await tester.pump();
      expect(find.text('LOADING…'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1100));
      expect(cubit.state.status, GameStatus.playing);
      cubit.debugForceGameOver();
      await tester.pump();
      cubit.expireContinue();
      await tester.pump();
      expect(find.text('Game Over'), findsOneWidget);
      expect(find.text('PLAY AGAIN'), findsOneWidget);
    },
  );

  testWidgets('game-over overlays never mount two banner ad slots', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    expect(find.byType(AdsBannerSlot), findsOneWidget);

    cubit.debugForceGameOver();
    await tester.pump();
    expect(cubit.state.status, GameStatus.continuePrompt);
    expect(find.byType(AdsBannerSlot), findsNothing);

    cubit.expireContinue();
    await tester.pump();
    expect(cubit.state.status, GameStatus.results);
    expect(find.byType(AdsBannerSlot), findsNothing);

    await tester.tap(find.text('PLAY AGAIN'));
    await tester.pump();
    expect(cubit.state.status, GameStatus.playing);
    expect(find.byType(AdsBannerSlot), findsOneWidget);
  });

  testWidgets('gameplay can be reopened after leaving the game screen', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: prismTheme(),
        home: Navigator(
          key: navigatorKey,
          onGenerateRoute: (_) =>
              MaterialPageRoute<void>(builder: (_) => const SizedBox.shrink()),
        ),
      ),
    );
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: GameScreen(onExit: () => navigatorKey.currentState!.pop()),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(AdsBannerSlot), findsOneWidget);

    await tester.tap(find.byTooltip('Back to home'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsNothing);

    await cubit.restart();
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: GameScreen(onExit: () => navigatorKey.currentState!.pop()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(AdsBannerSlot), findsOneWidget);
  });
}
