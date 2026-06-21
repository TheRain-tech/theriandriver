import 'package:flutter_test/flutter_test.dart';
import 'package:theraindriver/app/therain_driver_app.dart';

void main() {
  testWidgets('opens the dashboard in preview mode', (tester) async {
    await tester.pumpWidget(const TheRainDriverApp(previewMode: true));
    await tester.pumpAndSettle();

    expect(find.text('Good Morning,'), findsOneWidget);
    expect(find.text("Today's Earnings"), findsOneWidget);
    expect(find.text('Open Incoming Ride'), findsOneWidget);
  });
}
