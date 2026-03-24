import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:streamsize_client/main.dart';

void main() {
  testWidgets('renders smarter device scan step', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const StreamsizeApp());

    expect(find.text('Find the plan your home actually needs.'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Review your home scan'), findsOneWidget);
    expect(find.text('Scan confidence looks good'), findsOneWidget);
  });
}
