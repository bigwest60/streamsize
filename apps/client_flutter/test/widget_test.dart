import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamsize_client/main.dart';
import 'package:streamsize_platform_discovery/streamsize_platform_discovery.dart';

void main() {
  testWidgets('renders smarter device scan step', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: RecommendationFlowPage(discovery: MockDiscoveryService()),
      ),
    );

    expect(find.text('Find the plan your home actually needs.'), findsOneWidget);

    // Wait for async discovery to complete so the Continue button is enabled.
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Review your home scan'), findsOneWidget);
  });
}
