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

    expect(recommendation.reasons.any((r) => r.contains('Mbps each')), isTrue);
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

  test('HD streams appear in reasons when present', () {
    final engine = RecommendationEngine();
    final scenario = HouseholdScenario(
      homeProfile: HomeProfile.small,
      devices: const [
        DetectedDevice(
          displayName: 'TV',
          category: DeviceCategory.tv,
          confidence: ConfidenceScore.high,
          connection: ConnectionType.wifi,
        ),
      ],
      simultaneous4kStreams: 0,
      simultaneousHdStreams: 2,
      simultaneousVideoCalls: 0,
      remoteWorkers: 0,
      onlineGamers: 0,
      cloudBackupEnabled: false,
      securityCameraCount: 0,
      largeDownloadHabit: LargeDownloadHabit.rarely,
    );

    final recommendation = engine.buildRecommendation(scenario);
    expect(recommendation.reasons.any((r) => r.contains('HD stream')), isTrue);
    expect(recommendation.reasons.any((r) => r.contains('8 Mbps each')), isTrue);
  });

  test('unknown devices are excluded from baseline', () {
    final engine = RecommendationEngine();
    final scenario = HouseholdScenario(
      homeProfile: HomeProfile.small,
      devices: const [
        DetectedDevice(
          displayName: 'Mystery Device',
          category: DeviceCategory.unknown,
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
    // Only home profile small (10 Mbps) + 30% headroom = 13 → round to 100
    // Unknown device should NOT contribute bandwidth
    expect(recommendation.downloadMbps, 100);
  });

  test('camera upload uses detected count when higher than declared', () {
    final engine = RecommendationEngine();
    final scenario = HouseholdScenario(
      homeProfile: HomeProfile.small,
      devices: const [
        DetectedDevice(
          displayName: 'Camera 1',
          category: DeviceCategory.camera,
          confidence: ConfidenceScore.medium,
          connection: ConnectionType.wifi,
        ),
        DetectedDevice(
          displayName: 'Camera 2',
          category: DeviceCategory.camera,
          confidence: ConfidenceScore.medium,
          connection: ConnectionType.wifi,
        ),
        DetectedDevice(
          displayName: 'Camera 3',
          category: DeviceCategory.camera,
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
      securityCameraCount: 1,
      largeDownloadHabit: LargeDownloadHabit.rarely,
    );

    final recommendation = engine.buildRecommendation(scenario);
    // 3 detected cameras with medium confidence: (2+5)/2=4 Mbps each * 3 = 12 Mbps upload
    // Plus home profile small upload = 5, total = 17, headroom = 23 → normalize to 50
    expect(recommendation.uploadMbps, 50);
  });

  test('camera upload uses declared count when no detected cameras', () {
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
      securityCameraCount: 2,
      largeDownloadHabit: LargeDownloadHabit.rarely,
    );

    final recommendation = engine.buildRecommendation(scenario);
    // 2 declared cameras * 4 Mbps each = 8, home profile upload = 5, total = 13, headroom = 17 → 20
    expect(recommendation.uploadMbps, 20);
  });

  test('camera upload blends detected and declared cameras with different confidence', () {
    final engine = RecommendationEngine();
    final scenario = HouseholdScenario(
      homeProfile: HomeProfile.small,
      devices: const [
        DetectedDevice(
          displayName: 'Camera 1',
          category: DeviceCategory.camera,
          confidence: ConfidenceScore.high,
          connection: ConnectionType.wifi,
        ),
      ],
      simultaneous4kStreams: 0,
      simultaneousHdStreams: 0,
      simultaneousVideoCalls: 0,
      remoteWorkers: 0,
      onlineGamers: 0,
      cloudBackupEnabled: false,
      securityCameraCount: 3,
      largeDownloadHabit: LargeDownloadHabit.rarely,
    );

    final recommendation = engine.buildRecommendation(scenario);
    // 1 detected (high, typical=5 Mbps) + 2 declared-only (medium, 4 Mbps each) = 5 + 8 = 13
    // Plus home small upload = 5, total = 18, headroom = 24 → 50
    expect(recommendation.uploadMbps, 50);
  });

  test('confidence is medium with cloud backup but no devices', () {
    final engine = RecommendationEngine();
    final scenario = HouseholdScenario(
      homeProfile: HomeProfile.small,
      devices: const [],
      simultaneous4kStreams: 0,
      simultaneousHdStreams: 0,
      simultaneousVideoCalls: 0,
      remoteWorkers: 0,
      onlineGamers: 0,
      cloudBackupEnabled: true,
      securityCameraCount: 0,
      largeDownloadHabit: LargeDownloadHabit.rarely,
    );

    final recommendation = engine.buildRecommendation(scenario);
    expect(recommendation.confidence, ConfidenceScore.medium);
  });

  test('confidence is medium with daily download habit but no devices', () {
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
      largeDownloadHabit: LargeDownloadHabit.daily,
    );

    final recommendation = engine.buildRecommendation(scenario);
    expect(recommendation.confidence, ConfidenceScore.medium);
  });

  test('TV reason shows confidence-weighted Mbps', () {
    final engine = RecommendationEngine();
    final scenario = HouseholdScenario(
      homeProfile: HomeProfile.small,
      devices: const [
        DetectedDevice(
          displayName: 'TV',
          category: DeviceCategory.tv,
          confidence: ConfidenceScore.high,
          connection: ConnectionType.wifi,
        ),
      ],
      simultaneous4kStreams: 1,
      simultaneousHdStreams: 0,
      simultaneousVideoCalls: 0,
      remoteWorkers: 0,
      onlineGamers: 0,
      cloudBackupEnabled: false,
      securityCameraCount: 0,
      largeDownloadHabit: LargeDownloadHabit.rarely,
    );

    final recommendation = engine.buildRecommendation(scenario);
    // High confidence TV should show "~ 25 Mbps each"
    expect(recommendation.reasons.any((r) => r.contains('~ 25 Mbps each')), isTrue);
  });

  test('mixed confidence within same category uses max confidence', () {
    final engine = RecommendationEngine();
    final scenario = HouseholdScenario(
      homeProfile: HomeProfile.small,
      devices: const [
        DetectedDevice(
          displayName: 'TV 1',
          category: DeviceCategory.tv,
          confidence: ConfidenceScore.low,
          connection: ConnectionType.wifi,
        ),
        DetectedDevice(
          displayName: 'TV 2',
          category: DeviceCategory.tv,
          confidence: ConfidenceScore.high,
          connection: ConnectionType.ethernet,
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
    // Max confidence is high → typical Mbps for TV = 25, so 2 * 25 = 50
    // Home small = 10, total = 60, headroom = 78 → 100
    expect(recommendation.downloadMbps, 100);
    // TV reason should show "up to" (high confidence label)
    expect(recommendation.reasons.any((r) => r.contains('~ 25 Mbps each')), isTrue);
  });

  test('low-confidence detected cameras use min Mbps, not medium', () {
    final engine = RecommendationEngine();
    final scenario = HouseholdScenario(
      homeProfile: HomeProfile.large,
      devices: List.generate(
        5,
        (_) => const DetectedDevice(
          displayName: 'Camera',
          category: DeviceCategory.camera,
          confidence: ConfidenceScore.low,
          connection: ConnectionType.wifi,
        ),
      ),
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
    // 5 low-confidence cameras * minMbps 2 = 10, home large upload = 20, total = 30
    // headroom = 39 → 50
    // If bug (medium=(2+5)/2=4): 5*4=20 + 20 = 40, headroom = 52 → 100
    expect(recommendation.uploadMbps, 50);
  });

  test('multiple low-confidence cameras produce distinctly lower upload than high-confidence', () {
    final engine = RecommendationEngine();

    final lowConfScenario = HouseholdScenario(
      homeProfile: HomeProfile.large,
      devices: List.generate(
        5,
        (_) => const DetectedDevice(
          displayName: 'Cam',
          category: DeviceCategory.camera,
          confidence: ConfidenceScore.low,
          connection: ConnectionType.wifi,
        ),
      ),
      simultaneous4kStreams: 0,
      simultaneousHdStreams: 0,
      simultaneousVideoCalls: 0,
      remoteWorkers: 0,
      onlineGamers: 0,
      cloudBackupEnabled: false,
      securityCameraCount: 0,
      largeDownloadHabit: LargeDownloadHabit.rarely,
    );

    final highConfScenario = HouseholdScenario(
      homeProfile: HomeProfile.large,
      devices: List.generate(
        5,
        (_) => const DetectedDevice(
          displayName: 'Cam',
          category: DeviceCategory.camera,
          confidence: ConfidenceScore.high,
          connection: ConnectionType.wifi,
        ),
      ),
      simultaneous4kStreams: 0,
      simultaneousHdStreams: 0,
      simultaneousVideoCalls: 0,
      remoteWorkers: 0,
      onlineGamers: 0,
      cloudBackupEnabled: false,
      securityCameraCount: 0,
      largeDownloadHabit: LargeDownloadHabit.rarely,
    );

    final lowRec = engine.buildRecommendation(lowConfScenario);
    final highRec = engine.buildRecommendation(highConfScenario);
    // low: 5 cameras * 2 Mbps + 20 (large profile) = 30 * 1.3 = 39 → 50
    // high: 5 cameras * 5 Mbps + 20 (large profile) = 45 * 1.3 = 59 → 100
    expect(lowRec.uploadMbps, lessThan(highRec.uploadMbps));
  });
}
