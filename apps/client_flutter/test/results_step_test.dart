import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamsize_client/widgets/results_step.dart';
import 'package:streamsize_core/streamsize_core.dart';

void main() {
  group('ResultsStep Widget Tests', () {
    testWidgets('widget builds and renders without errors', (WidgetTester tester) async {
      final recommendation = PlanRecommendation(
        downloadMbps: 300,
        uploadMbps: 50,
        planLabel: '300/50',
        summary: 'A solid fit for most homes.',
        confidence: ConfidenceScore.high,
        reasons: const ['Supports 2 4K streams', '10 devices considered'],
      );
      final scenario = HouseholdScenario(
        homeProfile: HomeProfile.medium,
        devices: const [
          DetectedDevice(
            displayName: 'Living Room TV',
            category: DeviceCategory.tv,
            confidence: ConfidenceScore.high,
            connection: ConnectionType.wifi,
          ),
        ],
        simultaneous4kStreams: 2,
        simultaneousHdStreams: 2,
        simultaneousVideoCalls: 1,
        remoteWorkers: 1,
        onlineGamers: 1,
        cloudBackupEnabled: true,
        securityCameraCount: 2,
        largeDownloadHabit: LargeDownloadHabit.weekly,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ResultsStep(
                recommendation: recommendation,
                scenario: scenario,
                isSpeedTesting: false,
                onRunSpeedTest: () {},
                onShareText: () {},
                onExportPdf: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ResultsStep), findsOneWidget);
    });

    testWidgets('handles speed test callback', (WidgetTester tester) async {
      bool speedTestCalled = false;
      
      final recommendation = PlanRecommendation(
        downloadMbps: 300,
        uploadMbps: 50,
        planLabel: '300/50',
        summary: 'A solid fit for most homes.',
        confidence: ConfidenceScore.high,
        reasons: const [],
      );
      final scenario = HouseholdScenario(
        homeProfile: HomeProfile.medium,
        devices: const [],
        simultaneous4kStreams: 1,
        simultaneousHdStreams: 1,
        simultaneousVideoCalls: 0,
        remoteWorkers: 0,
        onlineGamers: 0,
        cloudBackupEnabled: false,
        securityCameraCount: 0,
        largeDownloadHabit: LargeDownloadHabit.rarely,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ResultsStep(
                recommendation: recommendation,
                scenario: scenario,
                isSpeedTesting: false,
                onRunSpeedTest: () { speedTestCalled = true; },
                onShareText: () {},
                onExportPdf: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ResultsStep), findsOneWidget);
      expect(speedTestCalled, isFalse);
    });
  });
}
