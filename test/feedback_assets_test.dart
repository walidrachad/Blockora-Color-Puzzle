import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prism_puzzle/app/theme.dart';
import 'package:prism_puzzle/features/game/presentation/combo_overlay.dart';

void main() {
  test('all local combo animations load from the asset bundle', () async {
    for (final asset in ComboAssets.all) {
      expect(await ComboLottieCache.load(asset), isNotNull, reason: asset);
    }
  });

  testWidgets('combo overlay is centered, non-interactive, and finite', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: prismTheme(),
        home: const SizedBox(
          width: 320,
          height: 320,
          child: ComboOverlay(combo: 6, eventId: 1),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('COMBO x6'), findsNothing);
  });
}
