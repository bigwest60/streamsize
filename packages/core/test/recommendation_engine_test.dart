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

    expect(recommendation.downloadMbps, 1000);
    expect(recommendation.uploadMbps, 200);
    expect(recommendation.confidence, ConfidenceScore.high);
  });

  test('uses minMbps when device confidence is low', () {
    final engine = RecommendationEngine();
    final scenario = HouseholdScenario(
      homeProfile: HomeProfile.small,
      devices: const [
        DetectedDevice(
          displayName: 'Unknown TV',
          category: DeviceCategory.tv,
          confidence: ConfidenceScore.low,
          connection: ConnectionType.wifi,
        ),
      ],
      simultaneous4kStreams: 0,
      simultaneousHdStreams: 0,
      simultaneousVideoCalls: 0,
      remoteWorkers: 0,
      onlineGamers: 0,
      cloudBackupEnabled: false,
      securityCameraCount: 0,
      largeDownloadHabit: LargeDownloadHabit.rarely,
    );

    final recommendation = engine.buildRecommendation(scenario);

    // TV minMbps=5, home profile small=10, total=15, headroom=1.3x=20, normalize to 100
    expect(recommendation.downloadMbps, 100);
    // With 1 device (even low confidence), totalDevices >= 1 → medium
    expect(recommendation.confidence, ConfidenceScore.medium);
  });

  test('returns low confidence when no devices and no usage data', () {
    final engine = RecommendationEngine();
    final scenario = HouseholdScenario(
      homeProfile: HomeProfile.small,
      devices: const [],
      simultaneous4kStreams: 0,
      simultaneousHdStreams: 0,
      simultaneousVideoCalls: 0,
      remoteWorkers: 0,
      onlineGamers: 0,
      cloudBackupEnabled: false,
      securityCameraCount: 0,
      largeDownloadHabit: LargeDownloadHabit.rarely,
    );

    final recommendation = engine.buildRecommendation(scenario);
    expect(recommendation.confidence, ConfidenceScore.low);
  });

  test('DeviceBandwidthProfile mbpsForConfidence returns correct values', () {
    const tvProfile = DeviceBandwidthProfile(minMbps: 5, typicalMbps: 25, maxMbps: 100);
    expect(tvProfile.mbpsForConfidence(ConfidenceScore.high), 25);
    expect(tvProfile.mbpsForConfidence(ConfidenceScore.medium), 15); // (5+25)/2 = 15
    expect(tvProfile.mbpsForConfidence(ConfidenceScore.low), 5);
  });

  test('DeviceCategory.bandwidthProfile returns expected profiles', () {
    expect(DeviceCategory.tv.bandwidthProfile.typicalMbps, 25);
    expect(DeviceCategory.phone.bandwidthProfile.typicalMbps, 10);
    expect(DeviceCategory.tablet.bandwidthProfile.typicalMbps, 10);
    expect(DeviceCategory.laptop.bandwidthProfile.typicalMbps, 25);
    expect(DeviceCategory.console.bandwidthProfile.typicalMbps, 25);
    expect(DeviceCategory.camera.bandwidthProfile.typicalMbps, 5);
    expect(DeviceCategory.smartHome.bandwidthProfile.typicalMbps, 2);
    expect(DeviceCategory.nas.bandwidthProfile.typicalMbps, 10);
  });

  test('confidence is high when most devices are high-confidence with usage data', () {
    final engine = RecommendationEngine();
    final scenario = HouseholdScenario(
      homeProfile: HomeProfile.medium,
      devices: List.generate(
        4,
        (index) => const DetectedDevice(
          displayName: 'Device',
          category: DeviceCategory.laptop,
          confidence: ConfidenceScore.high,
          connection: ConnectionType.wifi,
        ),
      ),
      simultaneous4kStreams: 2,
      simultaneousHdStreams: 0,
      simultaneousVideoCalls: 0,
      remoteWorkers: 1,
      onlineGamers: 0,
      cloudBackupEnabled: false,
      securityCameraCount: 0,
      largeDownloadHabit: LargeDownloadHabit.rarely,
    );

    final recommendation = engine.buildRecommendation(scenario);
    expect(recommendation.confidence, ConfidenceScore.high);
  });

  test('reasons include bandwidth explanations and concurrency overhead', () {
    final engine = RecommendationEngine();
    final scenario = HouseholdScenario(
      homeProfile: HomeProfile.medium,
      devices: const [
        DetectedDevice(
          displayName: 'TV',
          category: DeviceCategory.tv,
          confidence: ConfidenceScore.high,
          connection: ConnectionType.wifi,
        ),
      ],
      simultaneous4kStreams: 3,
      simultaneousHdStreams: 0,
      simultaneousVideoCalls: 2,
      remoteWorkers: 1,
      onlineGamers: 1,
      cloudBackupEnabled: true,
      securityCameraCount: 0,
      largeDownloadHabit: LargeDownloadHabit.weekly,
    );

    final recommendation = engine.buildRecommendation(scenario);

    expect(recommendation.reasons.any((r) => r.contains('25 Mbps each')), isTrue);
    expect(recommendation.reasons.any((r) => r.contains('Concurrency overhead')), isTrue);
    expect(recommendation.reasons.any((r) => r.contains('Weekly large downloads')), isTrue);
  });

  test('concurrency overhead is zero for light usage', () {
    final engine = RecommendationEngine();
    final scenario = HouseholdScenario(
      homeProfile: HomeProfile.small,
      devices: const [
        DetectedDevice(
          displayName: 'Phone',
          category: DeviceCategory.phone,
          confidence: ConfidenceScore.medium,
          connection: ConnectionType.wifi,
        ),
      ],
      simultaneous4kStreams: 0,
      simultaneousHdStreams: 0,
      simultaneousVideoCalls: 0,
      remoteWorkers: 0,
      onlineGamers: 0,
      cloudBackupEnabled: false,
      securityCameraCount: 0,
      largeDownloadHabit: LargeDownloadHabit.rarely,
    );

    final recommendation = engine.buildRecommendation(scenario);
    expect(recommendation.reasons.any((r) => r.contains('Concurrency overhead')), isFalse);
  });
}
