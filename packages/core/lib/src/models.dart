enum DeviceCategory {
  tv('TV / streamer'),
  phone('Phone'),
  tablet('Tablet'),
  laptop('Laptop / desktop'),
  console('Game console'),
  camera('Security camera'),
  smartHome('Smart home / IoT'),
  unknown('Unknown');

  const DeviceCategory(this.label);
  final String label;
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
