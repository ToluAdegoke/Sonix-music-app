import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const SonixApp());

    // Verify that the SonixApp is present in the widget tree.
    expect(find.byType(SonixApp), findsOneWidget);
  });
}
