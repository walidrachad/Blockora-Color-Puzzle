import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_puzzle/app/theme.dart';
import 'package:prism_puzzle/core/services/services.dart';
import 'package:prism_puzzle/features/game/application/game_cubit.dart';
import 'package:prism_puzzle/features/game/presentation/mode_screens.dart';

class ModeWidgetStorage implements GameStorage {
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
    cubit = GameCubit(storage: ModeWidgetStorage());
    await cubit.initialize();
  });

  tearDown(() async => cubit.close());

  testWidgets('mode selection exposes Classic, Journey, and Daily Challenge', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: prismTheme(),
        home: ModeSelectionScreen(cubit: cubit),
      ),
    );
    expect(find.text('Classic'), findsOneWidget);
    expect(find.text('Journey'), findsOneWidget);
    expect(find.text('Daily Challenge'), findsOneWidget);
  });

  testWidgets('Journey opens a 30-level selection screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: prismTheme(),
        home: ModeSelectionScreen(cubit: cubit),
      ),
    );
    await tester.tap(find.text('Journey'));
    await tester.pumpAndSettle();
    expect(find.text('Journey'), findsOneWidget); // AppBar title.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byTooltip('Back to mode selection'));
    await tester.pumpAndSettle();
    expect(find.text('Choose your mode'), findsOneWidget);
  });

  testWidgets('Daily opens its offline overview', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: prismTheme(),
        home: ModeSelectionScreen(cubit: cubit),
      ),
    );
    await tester.tap(find.text('Daily Challenge'));
    await tester.pumpAndSettle();
    expect(find.text('RECENT DAYS'), findsOneWidget);
    expect(find.text('START TODAY'), findsOneWidget);
  });
}
