import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_puzzle/app/theme.dart';
import 'package:prism_puzzle/core/services/services.dart';
import 'package:prism_puzzle/features/game/application/game_cubit.dart';
import 'package:prism_puzzle/features/game/domain/game_rules.dart';
import 'package:prism_puzzle/features/game/presentation/first_play_onboarding.dart';
import 'package:prism_puzzle/features/game/presentation/cartoon_game_shell.dart';
import 'package:prism_puzzle/features/game/presentation/cartoon_home_screen.dart';
import 'widget_test.dart' show WidgetMemoryStorage;

class OnboardingStorage extends WidgetMemoryStorage {
  AppPreferences preferences = const AppPreferences();
  @override
  Future<AppPreferences> loadPreferences() async => preferences;
  @override
  Future<void> savePreferences(AppPreferences value) async {
    preferences = AppPreferences.fromJson(value.toJson());
  }
}

void main() {
  final captureKey = GlobalKey();
  Widget app(Widget child, {bool reducedMotion = false}) => RepaintBoundary(
    key: captureKey,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: prismTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
        child: child!,
      ),
      home: child,
    ),
  );

  Future<void> dragIntoGap(WidgetTester tester) async {
    final source = tester.getCenter(
      find.byKey(const ValueKey('tutorial-piece')),
    );
    final target = tester.getCenter(
      find.byKey(const ValueKey('tutorial-target')),
    );
    final gesture = await tester.startGesture(source);
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    expect(find.byKey(const ValueKey('tutorial-hand')), findsNothing);
    await gesture.moveTo(target + const Offset(0, 52));
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  test('completion preference survives storage and settings changes', () {
    expect(AppPreferences.fromJson({}).hasCompletedOnboarding, isFalse);
    final saved = const AppPreferences(
      hasCompletedOnboarding: true,
    ).copyWith(sound: false);
    final restored = AppPreferences.fromJson(saved.toJson());
    expect(restored.hasCompletedOnboarding, isTrue);
    expect(restored.sound, isFalse);
  });

  test('tutorial has two squares and filling the gap clears three rows', () {
    expect(DragTutorialScreen.initialBoard.filledCount, 18);
    expect(detectCompletedLines(DragTutorialScreen.initialBoard).count, 0);
    final placement = evaluatePlacement(
      DragTutorialScreen.initialBoard,
      DragTutorialScreen.piece,
      DragTutorialScreen.target,
    );
    expect(placement.valid, isTrue);
    final board = DragTutorialScreen.initialBoard.place(
      DragTutorialScreen.piece,
      DragTutorialScreen.target,
    );
    expect(detectCompletedLines(board).rows, [2, 3, 4]);
  });

  testWidgets('Play opens the tutorial and leaving keeps it incomplete', (
    tester,
  ) async {
    final storage = OnboardingStorage();
    final cubit = GameCubit(storage: storage);
    await cubit.initialize();
    addTearDown(cubit.close);
    await tester.pumpWidget(app(CartoonHomeScreen(cubit: cubit)));
    await tester.tap(find.text('PLAY'));
    await tester.pump();
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(DragTutorialScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(DragTutorialScreen), findsNothing);
    expect(storage.preferences.hasCompletedOnboarding, isFalse);
    await tester.tap(find.text('PLAY'));
    await tester.pump();
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(DragTutorialScreen), findsOneWidget);
  });

  testWidgets('hand demonstrates a drag and invalid drops restart the hint', (
    tester,
  ) async {
    var completions = 0;
    await tester.pumpWidget(
      app(DragTutorialScreen(onCompleted: () async => completions++)),
    );
    await tester.pump(const Duration(milliseconds: 700));
    final start = tester.getTopLeft(
      find.byKey(const ValueKey('tutorial-hand')),
    );
    await tester.pump(const Duration(milliseconds: 1100));
    final end = tester.getTopLeft(find.byKey(const ValueKey('tutorial-hand')));
    expect((end - start).distance, greaterThan(30));
    final source = tester.getCenter(
      find.byKey(const ValueKey('tutorial-piece')),
    );
    final gesture = await tester.startGesture(source);
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.moveTo(const Offset(20, 100));
    await gesture.up();
    await tester.pump();
    expect(find.text('Try the highlighted space'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(const ValueKey('tutorial-hand')), findsOneWidget);
    expect(completions, 0);
  });

  testWidgets('first successful drag clears rows and saves completion once', (
    tester,
  ) async {
    final storage = OnboardingStorage();
    final cubit = GameCubit(storage: storage);
    await cubit.initialize();
    addTearDown(cubit.close);
    await tester.pumpWidget(app(FirstPlayGame(cubit: cubit)));
    expect(find.byType(DragTutorialScreen), findsOneWidget);
    await dragIntoGap(tester);
    expect(find.text('Perfect! You cleared 3 rows.'), findsOneWidget);
    expect(storage.preferences.hasCompletedOnboarding, isFalse);
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(storage.preferences.hasCompletedOnboarding, isTrue);
    expect(find.byType(DragTutorialScreen), findsNothing);
    expect(find.byType(CartoonGameShell), findsOneWidget);
    expect(cubit.state.score, 0);
    expect(cubit.state.board.filledCount, 0);
    await tester.pumpWidget(const SizedBox());
    final nextCubit = GameCubit(storage: storage);
    await nextCubit.initialize();
    addTearDown(nextCubit.close);
    await tester.pumpWidget(app(FirstPlayGame(cubit: nextCubit)));
    expect(find.byType(DragTutorialScreen), findsNothing);
    expect(find.byType(CartoonGameShell), findsOneWidget);
  });

  testWidgets(
    'tutorial fits small phones, tablets and landscape and cancels safely',
    (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var completed = false;
      for (final size in [
        const Size(320, 480),
        const Size(390, 844),
        const Size(568, 240),
        const Size(844, 390),
        const Size(768, 1024),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          app(
            DragTutorialScreen(
              key: ValueKey(size),
              onCompleted: () async => completed = true,
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        final source = tester.getRect(
          find.byKey(const ValueKey('tutorial-piece')),
        );
        expect(source.bottom, lessThanOrEqualTo(size.height));
        expect(source.left, greaterThanOrEqualTo(0));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
      expect(completed, isFalse);
    },
  );

  testWidgets('reduced motion keeps a static hand and still teaches the drop', (
    tester,
  ) async {
    var completed = false;
    await tester.pumpWidget(
      app(
        DragTutorialScreen(onCompleted: () async => completed = true),
        reducedMotion: true,
      ),
    );
    final before = tester.getTopLeft(
      find.byKey(const ValueKey('tutorial-hand')),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('tutorial-hand'))),
      before,
    );
    await dragIntoGap(tester);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 700));
    expect(completed, isTrue);
  });

  testWidgets('capture tutorial animation when requested', (tester) async {
    const path = String.fromEnvironment('ONBOARDING_CAPTURES');
    if (path.isEmpty) return;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      await (FontLoader('Arial')..addFont(
            File(
              '/System/Library/Fonts/Supplemental/Arial.ttf',
            ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
          ))
          .load();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    });
    await tester.pumpWidget(app(DragTutorialScreen(onCompleted: () async {})));
    await tester.pump(const Duration(milliseconds: 1));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 80));
      await tester.runAsync(() async {
        final boundary =
            captureKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(path).create(recursive: true);
        await File(
          '$path/frame_${i.toString().padLeft(2, '0')}.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
  });
}
