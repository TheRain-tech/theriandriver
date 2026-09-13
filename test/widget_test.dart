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

    expect(find.text('Good Morning,'), findsOneWidget);
    expect(find.text("Today's Earnings"), findsOneWidget);
    expect(find.text('Open Incoming Ride'), findsOneWidget);
  });
}
