import 'package:flutter_test/flutter_test.dart';

import 'package:harexaart/main.dart';

void main() {
  testWidgets('HarexaArt app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const HarexaArtApp());

    expect(find.byType(HarexaArtApp), findsOneWidget);
  });
}