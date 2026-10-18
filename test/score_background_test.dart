import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_puzzle/app/theme.dart';
import 'package:prism_puzzle/core/services/services.dart';
import 'package:prism_puzzle/features/game/application/game_cubit.dart';
import 'package:prism_puzzle/features/game/domain/models.dart';
import 'package:prism_puzzle/features/game/presentation/cartoon_game_shell.dart';
import 'widget_test.dart' show WidgetMemoryStorage;

class ScoreBackgroundStorage extends WidgetMemoryStorage {
  ScoreBackgroundStorage(this.score);
  final int score;

  @override
  Future<SavedGame?> loadGame() async => SavedGame(
    board: Board(),
    pieces: [PieceLibrary.byId['dot'], null, null],
    score: score,
    best: score,
    combo: 0,
    generatorState: 77,
    reviveUsed: false,
  );
}

void main() {
  Future<GameCubit> mount(
    WidgetTester tester,
    int score, {
    bool reducedMotion = false,
  }) async {
    final cubit = GameCubit(storage: ScoreBackgroundStorage(score));
    await cubit.initialize();
    addTearDown(cubit.close);
    await tester.pumpWidget(
      MaterialApp(
        theme: prismTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(disableAnimations: reducedMotion),
          child: child!,
        ),
        home: CartoonGameShell(cubit: cubit),
      ),
    );
    return cubit;
  }

  AnimatedContainer background(WidgetTester tester) =>
      tester.widget(find.byKey(const ValueKey('score-background')));

  Future<void> placeDot(WidgetTester tester, GameCubit cubit) async {
    cubit.debugSetBoard(
      Board(),
      pieces: [PieceLibrary.byId['dot'], null, null],
    );
    cubit.pickup(0);
    cubit.drop(index: 0, origin: const GridPoint(0, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  for (final threshold in [1000, 2000, 3000, 7000]) {
    testWidgets('background changes on crossing $threshold points', (
      tester,
    ) async {
      final cubit = await mount(tester, threshold - 2);
      final before = background(tester).decoration;
      await placeDot(tester, cubit);
      expect(cubit.state.score, threshold - 1);
      expect(background(tester).decoration, before);
      await placeDot(tester, cubit);
      expect(cubit.state.score, threshold);
      final after = background(tester).decoration;
      expect(after, isNot(before));
      expect(background(tester).duration, const Duration(milliseconds: 650));
      await placeDot(tester, cubit);
      expect(cubit.state.score, threshold + 1);
      expect(background(tester).decoration, after);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('restored score gets a soft tint and restarting resets it', (
    tester,
  ) async {
    final cubit = await mount(tester, 2000);
    final restored = background(tester).decoration! as BoxDecoration;
    final colors = (restored.gradient! as LinearGradient).colors;
    expect(colors.every((color) => color.computeLuminance() > .7), isTrue);
    await cubit.restart();
    await tester.pump();
    expect(cubit.state.score, 0);
    expect(background(tester).decoration, isNot(restored));
    await tester.pump(const Duration(milliseconds: 700));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion switches background without animation', (
    tester,
  ) async {
    final cubit = await mount(tester, 999, reducedMotion: true);
    final before = background(tester).decoration;
    await placeDot(tester, cubit);
    expect(background(tester).decoration, isNot(before));
    expect(background(tester).duration, Duration.zero);
    expect(tester.takeException(), isNull);
  });
}
