import 'package:streamsize_core/streamsize_core.dart';
import 'package:test/test.dart';

void main() {
  test('recommends 300/50 for a typical medium household', () {
    final engine = RecommendationEngine();
    final scenario = HouseholdScenario(
      homeProfile: HomeProfile.medium,
      devices: const [
        DetectedDevice(
          displayName: 'Living Room TV',
          category: DeviceCategory.tv,
          confidence: ConfidenceScore.high,
          connection: ConnectionType.wifi,
        ),
        DetectedDevice(
          displayName: 'Work Laptop',
          category: DeviceCategory.laptop,
          confidence: ConfidenceScore.high,
          connection: ConnectionType.wifi,
        ),
        DetectedDevice(
          displayName: 'Phone',
          category: DeviceCategory.phone,
          confidence: ConfidenceScore.medium,
          connection: ConnectionType.wifi,
        ),
      ],
      simultaneous4kStreams: 2,
      simultaneousHdStreams: 1,
      simultaneousVideoCalls: 1,
      remoteWorkers: 1,
      onlineGamers: 0,
      cloudBackupEnabled: false,
      securityCameraCount: 1,
      largeDownloadHabit: LargeDownloadHabit.weekly,
    );

    final recommendation = engine.buildRecommendation(scenario);

    expect(recommendation.downloadMbps, 300);
    expect(recommendation.uploadMbps, 50);
    expect(recommendation.confidence, ConfidenceScore.medium);
  });

  test('pushes heavy households into gigabit tiers', () {
    final engine = RecommendationEngine();
    final scenario = HouseholdScenario(
      homeProfile: HomeProfile.large,
      devices: List.generate(
        8,
        (index) => const DetectedDevice(
          displayName: 'Device',
          category: DeviceCategory.tv,
          confidence: ConfidenceScore.high,
          connection: ConnectionType.ethernet,
        ),
      ),
      simultaneous4kStreams: 5,
      simultaneousHdStreams: 3,
      simultaneousVideoCalls: 3,
      remoteWorkers: 2,
      onlineGamers: 2,
      cloudBackupEnabled: true,
      securityCameraCount: 4,
      largeDownloadHabit: LargeDownloadHabit.daily,
    );

    final recommendation = engine.buildRecommendation(scenario);

    expect(recommendation.downloadMbps, 500);
    expect(recommendation.uploadMbps, 100);
    expect(recommendation.confidence, ConfidenceScore.high);
  });
}
