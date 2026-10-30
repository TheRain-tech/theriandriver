import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/app/therain_driver_app.dart';

void main() {
  testWidgets('opens the dashboard in preview mode', (tester) async {
    await tester.pumpWidget(const TheRainDriverApp(previewMode: true));
    // Not pumpAndSettle(): the dashboard's commission-balance indicator runs a
    // legitimately-infinite pulse animation (AnimationController..repeat(reverse: true)) once a
    // wallet balance arrives, which pumpAndSettle's "wait until no more frames are scheduled"
    // loop can never satisfy - it always hits its own timeout. A few bounded pumps are enough
    // for the widget tree (and the wallet stream's single emitted value) to settle.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // The Home redesign removed the "Good Morning, {name}" greeting row entirely to match the
    // reference layout (drag handle -> swipe control directly, no header row) - "Ride Type" is a
    // static label unaffected by online/incoming-request state, making it a stable replacement
    // check that the redesigned dashboard still renders.
    expect(find.text('Ride Type'), findsOneWidget);
    expect(find.text("Today's Earnings"), findsOneWidget);
    expect(find.text('Open Incoming Ride'), findsOneWidget);
  });

  group('redesigned Home dashboard is overflow-free across device sizes', () {
    // Logical width x height, devicePixelRatio 1.0 so physicalSize == logical size directly -
    // same pattern THERAIN FLEET's widget_test.dart already uses for its dashboard. Covers a
    // small phone, a large phone and a tablet, per the Home redesign's responsive requirement.
    const sizes = <String, Size>{
      'small phone (360x740)': Size(360, 740),
      'large phone (430x932)': Size(430, 932),
      'tablet (768x1024)': Size(768, 1024),
    };

    for (final entry in sizes.entries) {
      testWidgets('${entry.key} renders Home without overflow', (
        tester,
      ) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = entry.value;

        await tester.pumpWidget(const TheRainDriverApp(previewMode: true));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        expect(find.text('Ride Type'), findsOneWidget);
        expect(find.text("Today's Earnings"), findsOneWidget);
        // The real assertion: Flutter reports RenderFlex overflow and other layout constraint
        // violations as caught exceptions during pump, not as thrown Dart exceptions - this is
        // what caught the Balance/Recharge Row overflowing at 360px width.
        expect(tester.takeException(), isNull);
      });
    }
  });
}
