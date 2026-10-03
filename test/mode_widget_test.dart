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

  testWidgets('mode selection exposes only Classic', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: prismTheme(),
        home: ModeSelectionScreen(cubit: cubit),
      ),
    );
    expect(find.text('Classic'), findsOneWidget);
    expect(find.text('Journey'), findsNothing);
    expect(find.text('Daily Challenge'), findsNothing);
  });
}
