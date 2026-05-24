enum DeviceCategory {
  tv('TV / streamer'),
  phone('Phone'),
  tablet('Tablet'),
  laptop('Laptop / desktop'),
  console('Game console'),
  camera('Security camera'),
  smartHome('Smart home / IoT'),
  nas('NAS / storage'),
  unknown('Unknown');

  const DeviceCategory(this.label);
  final String label;

  DeviceBandwidthProfile get bandwidthProfile {
    switch (this) {
      case DeviceCategory.tv:
        return const DeviceBandwidthProfile(minMbps: 5, typicalMbps: 25, maxMbps: 100);
      case DeviceCategory.phone:
        return const DeviceBandwidthProfile(minMbps: 2, typicalMbps: 10, maxMbps: 50);
      case DeviceCategory.tablet:
        return const DeviceBandwidthProfile(minMbps: 2, typicalMbps: 10, maxMbps: 50);
      case DeviceCategory.laptop:
        return const DeviceBandwidthProfile(minMbps: 5, typicalMbps: 25, maxMbps: 100);
      case DeviceCategory.console:
        return const DeviceBandwidthProfile(minMbps: 5, typicalMbps: 25, maxMbps: 100);
      case DeviceCategory.camera:
        return const DeviceBandwidthProfile(minMbps: 2, typicalMbps: 5, maxMbps: 20);
      case DeviceCategory.smartHome:
        return const DeviceBandwidthProfile(minMbps: 1, typicalMbps: 2, maxMbps: 10);
      case DeviceCategory.nas:
        return const DeviceBandwidthProfile(minMbps: 5, typicalMbps: 10, maxMbps: 50);
      case DeviceCategory.unknown:
        return const DeviceBandwidthProfile(minMbps: 1, typicalMbps: 3, maxMbps: 10);
    }
  }
}

class DeviceBandwidthProfile {
  const DeviceBandwidthProfile({
    required this.minMbps,
    required this.typicalMbps,
    required this.maxMbps,
  });

  final int minMbps;
  final int typicalMbps;
  final int maxMbps;

  int mbpsForConfidence(ConfidenceScore confidence) {
    switch (confidence) {
      case ConfidenceScore.high:
        return typicalMbps;
      case ConfidenceScore.medium:
        return ((minMbps + typicalMbps) / 2).round();
      case ConfidenceScore.low:
        return minMbps;
    }
  }
}

enum ConfidenceScore { low, medium, high }

enum ConnectionType {
  ethernet('Ethernet'),
  wifi('Wi-Fi'),
  unknown('Unknown');

  const ConnectionType(this.label);
  final String label;
}

enum HomeProfile { small, medium, large }

enum LargeDownloadHabit {
  rarely('Rarely'),
  weekly('Weekly'),
  daily('Daily');

  const LargeDownloadHabit(this.label);
  final String label;
}

class DetectedDevice {
  const DetectedDevice({
    required this.displayName,
    required this.category,
    required this.confidence,
    required this.connection,
  });

  final String displayName;
  final DeviceCategory category;
  final ConfidenceScore confidence;
  final ConnectionType connection;

  DetectedDevice copyWith({
    String? displayName,
    DeviceCategory? category,
    ConfidenceScore? confidence,
    ConnectionType? connection,
  }) {
    return DetectedDevice(
      displayName: displayName ?? this.displayName,
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      connection: connection ?? this.connection,
    );
  }
}

class HouseholdScenario {
  const HouseholdScenario({
    required this.homeProfile,
    required this.devices,
    required this.simultaneous4kStreams,
    required this.simultaneousHdStreams,
    required this.simultaneousVideoCalls,
    required this.remoteWorkers,
    required this.onlineGamers,
    required this.cloudBackupEnabled,
    required this.securityCameraCount,
    required this.largeDownloadHabit,
  });

  final HomeProfile homeProfile;
  final List<DetectedDevice> devices;
  final int simultaneous4kStreams;
  final int simultaneousHdStreams;
  final int simultaneousVideoCalls;
  final int remoteWorkers;
  final int onlineGamers;
  final bool cloudBackupEnabled;
  final int securityCameraCount;
  final LargeDownloadHabit largeDownloadHabit;

  HouseholdScenario copyWith({
    HomeProfile? homeProfile,
    List<DetectedDevice>? devices,
    int? simultaneous4kStreams,
    int? simultaneousHdStreams,
    int? simultaneousVideoCalls,
    int? remoteWorkers,
    int? onlineGamers,
    bool? cloudBackupEnabled,
    int? securityCameraCount,
    LargeDownloadHabit? largeDownloadHabit,
  }) {
    return HouseholdScenario(
      homeProfile: homeProfile ?? this.homeProfile,
      devices: devices ?? this.devices,
      simultaneous4kStreams: simultaneous4kStreams ?? this.simultaneous4kStreams,
      simultaneousHdStreams: simultaneousHdStreams ?? this.simultaneousHdStreams,
      simultaneousVideoCalls: simultaneousVideoCalls ?? this.simultaneousVideoCalls,
      remoteWorkers: remoteWorkers ?? this.remoteWorkers,
      onlineGamers: onlineGamers ?? this.onlineGamers,
      cloudBackupEnabled: cloudBackupEnabled ?? this.cloudBackupEnabled,
      securityCameraCount: securityCameraCount ?? this.securityCameraCount,
      largeDownloadHabit: largeDownloadHabit ?? this.largeDownloadHabit,
    );
  }
}

class PlanRecommendation {
  const PlanRecommendation({
    required this.downloadMbps,
    required this.uploadMbps,
    required this.planLabel,
    required this.summary,
    required this.reasons,
    required this.confidence,
  });

  final int downloadMbps;
  final int uploadMbps;
  final String planLabel;
  final String summary;
  final List<String> reasons;
  final ConfidenceScore confidence;
}
