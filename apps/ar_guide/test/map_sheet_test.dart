import 'package:ar_guide/src/guide_params.dart';
import 'package:ar_guide/src/strings.dart';
import 'package:ar_guide/src/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _height = 700.0;

Widget _app({double? heading}) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 390,
            height: _height,
            child: Stack(
              fit: StackFit.expand,
              children: [MapSheet(s: S.of(Lang.en), params: GuideParams.demo, headingDeg: heading)],
            ),
          ),
        ),
      ),
    );

double _titleY(WidgetTester t) => t.getTopLeft(find.text('MAP')).dy;

void main() {
  testWidgets('starts collapsed, snaps open and closed when dragged', (t) async {
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    final collapsedY = _titleY(t);

    // A short drag still snaps to the expanded state.
    await t.fling(find.text('MAP'), const Offset(0, -80), 800);
    await t.pumpAndSettle();
    final expandedY = _titleY(t);
    expect(expandedY, lessThan(collapsedY - 100));

    // The sheet never covers more than its share of the area, so the card at the top stays visible.
    final screenHeight = t.view.physicalSize.height / t.view.devicePixelRatio;
    final sheetTop = expandedY - 25;
    expect(screenHeight - sheetTop, lessThanOrEqualTo(_height * MapSheet.maxExpandedShare + 1));

    await t.fling(find.text('MAP'), const Offset(0, 80), 800);
    await t.pumpAndSettle();
    expect(_titleY(t), closeTo(collapsedY, 1));
  });

  testWidgets('tapping the handle toggles the sheet', (t) async {
    await t.pumpWidget(_app());
    await t.pumpAndSettle();
    final collapsedY = _titleY(t);
    await t.tap(find.byKey(const Key('map-sheet-handle')));
    await t.pumpAndSettle();
    expect(_titleY(t), lessThan(collapsedY - 100));
    await t.tap(find.byKey(const Key('map-sheet-handle')));
    await t.pumpAndSettle();
    expect(_titleY(t), closeTo(collapsedY, 1));
  });

  test('marker repaints when the heading changes or becomes unavailable', () {
    final base = MiniMapPainter(turn: Turn.right, headingDeg: 10);
    expect(MiniMapPainter(turn: Turn.right, headingDeg: 40).shouldRepaint(base), isTrue);
    expect(MiniMapPainter(turn: Turn.right).shouldRepaint(base), isTrue);
    expect(MiniMapPainter(turn: Turn.right, headingDeg: 10).shouldRepaint(base), isFalse);
  });
}
