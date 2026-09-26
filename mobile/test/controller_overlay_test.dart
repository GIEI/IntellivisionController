import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intellivision_controller/main.dart';

void main() {
  final png = Uint8List.fromList(
    File(
      '../FreeIntv-master/Assets/default_keypad_image.png',
    ).readAsBytesSync(),
  );

  testWidgets('card retains its ratio and all twelve keys stay interactive', (
    tester,
  ) async {
    final down = <int>[];
    final up = <int>[];
    Widget panel(bool visible) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: ControllerKeypadPanel(
            image: png,
            imageSize: const Size(370, 600),
            overlayVisible: visible,
            selectedKey: null,
            onDown: (pointer, index) => down.add(index),
            onUp: up.add,
          ),
        ),
      ),
    );

    await tester.pumpWidget(panel(false));
    final originalRects = List.generate(
      12,
      (index) => tester.getRect(find.byKey(ValueKey('controller-key-$index'))),
    );
    // Physical keypad buttons are square rather than wide rectangles.
    for (final rect in originalRects) {
      expect(rect.width / rect.height, closeTo(1, .03));
    }

    await tester.pumpWidget(panel(true));
    await tester.pumpAndSettle();
    final card = tester.getRect(
      find.byKey(const ValueKey('overlay-card-image')),
    );
    expect(card.width / card.height, closeTo(370 / 600, .001));
    for (var index = 0; index < 12; index++) {
      final key = find.byKey(ValueKey('controller-key-$index'));
      expect(tester.getRect(key), originalRects[index]);
      await tester.tap(key);
    }
    expect(down, List.generate(12, (index) => index));
    expect(up.length, 12);

    down.clear();
    await tester.tapAt(Offset(card.center.dx, card.top + card.height * .1));
    expect(down, isEmpty); // The title is outside the keypad touch regions.
    expect(tester.takeException(), isNull);
  });

  testWidgets('BurgerTime first row aligns with the printed 1 2 3', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: ControllerKeypadPanel(
            imageSize: const Size(335, 540),
            overlayVisible: false,
            selectedKey: null,
            onDown: (_, _) {},
            onUp: (_) {},
          ),
        ),
      ),
    );
    final card = tester.getRect(
      find.byKey(const ValueKey('controller-card-slot')),
    );
    final printedPositions = [
      const Offset(74, 200),
      const Offset(166, 200),
      const Offset(255, 200),
    ];
    for (var index = 0; index < 3; index++) {
      final keyCenter = tester.getCenter(
        find.byKey(ValueKey('controller-key-$index')),
      );
      final printedCenter =
          card.topLeft +
          Offset(
            printedPositions[index].dx / 335 * card.width,
            printedPositions[index].dy / 540 * card.height,
          );
      expect((keyCenter - printedCenter).distance, lessThan(5));
    }
  });
}
