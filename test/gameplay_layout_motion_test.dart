import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_puzzle/app/theme.dart';
import 'package:prism_puzzle/features/game/application/game_cubit.dart';
import 'package:prism_puzzle/features/game/domain/models.dart';
import 'package:prism_puzzle/features/game/presentation/game_screen.dart';
import 'package:prism_puzzle/features/game/presentation/painters/block_skin.dart';
import 'widget_test.dart' show WidgetMemoryStorage;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late GameCubit cubit;
  final captureKey = GlobalKey();

  setUpAll(() async {
    const fontPath = String.fromEnvironment('GAMEPLAY_CAPTURE_FONT');
    if (fontPath.isEmpty) return;
    final font = FontLoader('Arial')
      ..addFont(
        File(
          fontPath,
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    await font.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  setUp(() async {
    cubit = GameCubit(storage: WidgetMemoryStorage());
    await cubit.initialize();
  });
  tearDown(() async => cubit.close());

  Widget app({bool reducedMotion = false, double textScale = 1}) => MaterialApp(
    theme: prismTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        disableAnimations: reducedMotion,
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: RepaintBoundary(
      key: captureKey,
      child: BlocProvider.value(value: cubit, child: const GameScreen()),
    ),
  );

  Future<void> capture(WidgetTester tester, String name) async {
    const directory = String.fromEnvironment('GAMEPLAY_CAPTURES');
    if (directory.isEmpty) return;
    final boundary =
        captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory(directory).create(recursive: true);
        await File(
          '$directory/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  testWidgets(
    'board and all pieces fit without scrolling across screen sizes',
    (tester) async {
      await tester.runAsync(BlockSkin.instance.preload);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      cubit.debugSetBoard(
        Board(
          List.generate(
            8,
            (row) => List.generate(
              8,
              (col) =>
                  row >= 4 && (row + col) % 3 != 0 ? (row + col) % 7 : null,
            ),
          ),
        ),
        pieces: [
          PieceLibrary.byId['t_up'],
          PieceLibrary.byId['square_2'],
          PieceLibrary.byId['l_left'],
        ],
      );
      for (final size in [
        const Size(320, 480),
        const Size(320, 568),
        const Size(390, 844),
        const Size(568, 320),
        const Size(568, 240),
        const Size(844, 390),
        const Size(768, 1024),
        const Size(1024, 768),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$size');
        expect(find.byType(Scrollable), findsNothing);
        final board = tester.getRect(find.byKey(const ValueKey('game-board')));
        expect(board.left, greaterThanOrEqualTo(0));
        expect(board.right, lessThanOrEqualTo(size.width));
        expect(board.bottom, lessThanOrEqualTo(size.height));
        for (var index = 0; index < 3; index++) {
          final piece = tester.getRect(
            find.bySemanticsLabel('Piece ${index + 1}, 4 blocks'),
          );
          expect(piece.bottom, lessThanOrEqualTo(size.height));
          expect(piece.overlaps(board), isFalse);
        }
        if (size == const Size(390, 844)) await capture(tester, 'portrait');
        if (size == const Size(844, 390)) await capture(tester, 'landscape');
      }
      await tester.binding.setSurfaceSize(const Size(320, 568));
      await tester.pumpWidget(app(textScale: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'one and three-line bursts finish and unlock the next move, including after restart',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.runAsync(BlockSkin.instance.preload);
      await tester.pumpWidget(app());
      for (final lines in [1, 3]) {
        await cubit.startClassic();
        await tester.pump();
        cubit.debugSetBoard(
          Board(
            List.generate(
              8,
              (row) => List.generate(
                8,
                (col) => row < lines && col < 7 ? (row + col) % 7 : null,
              ),
            ),
          ),
          pieces: [
            PieceLibrary.byId[lines == 1 ? 'dot' : 'trio_v'],
            PieceLibrary.byId['square_2'],
            PieceLibrary.byId['l_left'],
          ],
        );
        cubit.pickup(0);
        cubit.drop(index: 0, origin: const GridPoint(0, 7));
        await tester.pump();
        expect(cubit.state.status, GameStatus.clearing);
        expect(cubit.state.turn!.lines, lines);
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.text('+${cubit.state.turn!.points}'), findsOneWidget);
        await capture(tester, 'clear-$lines');
        await tester.pumpAndSettle();
        expect(cubit.state.status, GameStatus.playing);
        expect(cubit.state.board.filledCount, 0);
        expect(find.text('+${cubit.state.turn!.points}'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('dragging targets the correct cell in both orientations', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [const Size(390, 844), const Size(844, 390)]) {
      await tester.binding.setSurfaceSize(size);
      cubit.debugSetBoard(
        Board(),
        pieces: [PieceLibrary.byId['dot'], null, null],
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final board = tester.getRect(find.byKey(const ValueKey('game-board')));
      final cell = (board.width - 12.4) / 8;
      final slot = find.bySemanticsLabel('Piece 1, 1 blocks');
      final drag = await tester.startGesture(tester.getCenter(slot));
      await drag.moveBy(const Offset(0, -24));
      await tester.pump();
      await drag.moveTo(
        board.topLeft + Offset(6.2 + cell * .5, 6.2 + 82 + cell * .5),
      );
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();
      expect(cubit.state.board[const GridPoint(0, 0)], isNotNull);
      expect(cubit.state.board.filledCount, 1);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('reduced motion clears quickly and can place the next piece', (
    tester,
  ) async {
    await tester.pumpWidget(app(reducedMotion: true));
    cubit.debugSetBoard(
      Board(
        List.generate(
          8,
          (row) => List.generate(8, (col) => row == 0 && col < 7 ? 2 : null),
        ),
      ),
      pieces: [PieceLibrary.byId['dot'], PieceLibrary.byId['dot'], null],
    );
    cubit.pickup(0);
    cubit.drop(index: 0, origin: const GridPoint(0, 7));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(cubit.state.status, GameStatus.playing);
    cubit.pickup(1);
    cubit.drop(index: 1, origin: const GridPoint(7, 7));
    await tester.pumpAndSettle();
    expect(cubit.state.board.filledCount, 1);
    expect(tester.takeException(), isNull);
  });
}
