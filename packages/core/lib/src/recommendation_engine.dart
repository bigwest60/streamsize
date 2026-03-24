import 'models.dart';

class RecommendationEngine {
  PlanRecommendation buildRecommendation(HouseholdScenario scenario) {
    final detectedCounts = <DeviceCategory, int>{};
    for (final device in scenario.devices) {
      detectedCounts.update(device.category, (value) => value + 1, ifAbsent: () => 1);
    }

    final downloadDemand =
        (scenario.simultaneous4kStreams * 25) +
        (scenario.simultaneousHdStreams * 8) +
        (scenario.simultaneousVideoCalls * 6) +
        (scenario.remoteWorkers * 10) +
        (scenario.onlineGamers * 3) +
        _downloadHabitLoad(scenario.largeDownloadHabit) +
        _deviceBaselineDownload(detectedCounts) +
        _homeProfileDownload(scenario.homeProfile);

    final uploadDemand =
        (scenario.simultaneousVideoCalls * 4) +
        (scenario.remoteWorkers * 5) +
        (scenario.securityCameraCount * 3) +
        (scenario.cloudBackupEnabled ? 20 : 0) +
        _homeProfileUpload(scenario.homeProfile);

    final normalizedDownload = _normalizeDownload(_withHeadroom(downloadDemand));
    final normalizedUpload = _normalizeUpload(_withHeadroom(uploadDemand));

    return PlanRecommendation(
      downloadMbps: normalizedDownload,
      uploadMbps: normalizedUpload,
      planLabel: '${normalizedDownload}/${normalizedUpload}',
      summary: _summary(normalizedDownload, normalizedUpload),
      reasons: _buildReasons(scenario, detectedCounts),
      confidence: _confidenceFor(scenario),
    );
  }

  int _deviceBaselineDownload(Map<DeviceCategory, int> counts) {
    return (counts[DeviceCategory.tv] ?? 0) * 5 +
        (counts[DeviceCategory.laptop] ?? 0) * 3 +
        (counts[DeviceCategory.phone] ?? 0) * 2 +
        (counts[DeviceCategory.tablet] ?? 0) * 2 +
        (counts[DeviceCategory.console] ?? 0) * 3 +
        (counts[DeviceCategory.smartHome] ?? 0);
  }

  int _downloadHabitLoad(LargeDownloadHabit habit) {
    switch (habit) {
      case LargeDownloadHabit.rarely:
        return 0;
      case LargeDownloadHabit.weekly:
        return 25;
      case LargeDownloadHabit.daily:
        return 75;
    }
  }

  int _homeProfileDownload(HomeProfile profile) {
    switch (profile) {
      case HomeProfile.small:
        return 10;
      case HomeProfile.medium:
        return 25;
      case HomeProfile.large:
        return 50;
    }
  }

  int _homeProfileUpload(HomeProfile profile) {
    switch (profile) {
      case HomeProfile.small:
        return 5;
      case HomeProfile.medium:
        return 10;
      case HomeProfile.large:
        return 20;
    }
  }

  int _withHeadroom(int value) => (value * 1.3).ceil();

  int _normalizeDownload(int value) {
    const tiers = [100, 300, 500, 1000, 2000, 5000, 10000];
    return tiers.firstWhere((tier) => value <= tier, orElse: () => 10000);
  }

  int _normalizeUpload(int value) {
    const tiers = [20, 50, 100, 200, 500, 1000];
    return tiers.firstWhere((tier) => value <= tier, orElse: () => 1000);
  }

  String _summary(int down, int up) {
    if (down <= 100 && up <= 20) {
      return 'Suitable for lighter households with a few simultaneous streams and calls.';
    }
    if (down <= 300 && up <= 50) {
      return 'A solid fit for most homes without paying for gigabit service.';
    }
    if (down <= 500 && up <= 100) {
      return 'Good for busy homes with multiple streams, calls, and regular downloads.';
    }
    return 'Best for heavy simultaneous usage, many users, or creator-style upload needs.';
  }

  List<String> _buildReasons(HouseholdScenario scenario, Map<DeviceCategory, int> counts) {
    return [
      '${scenario.simultaneous4kStreams} simultaneous 4K streams',
      '${scenario.simultaneousVideoCalls} live video calls',
      if (scenario.remoteWorkers > 0) '${scenario.remoteWorkers} remote workers',
      if (scenario.onlineGamers > 0) '${scenario.onlineGamers} online gamers sharing the connection',
      if (scenario.securityCameraCount > 0) '${scenario.securityCameraCount} security cameras pushing upload traffic',
      if (scenario.cloudBackupEnabled) 'cloud backup headroom included',
      '${scenario.devices.length} visible devices detected on the local network',
      if ((counts[DeviceCategory.tv] ?? 0) > 0) '${counts[DeviceCategory.tv]} TVs or streamers discovered',
    ];
  }

  ConfidenceScore _confidenceFor(HouseholdScenario scenario) {
    if (scenario.devices.length >= 6 && scenario.simultaneous4kStreams > 0) {
      return ConfidenceScore.high;
    }
    if (scenario.devices.isNotEmpty) {
      return ConfidenceScore.medium;
    }
    return ConfidenceScore.low;
  }
}
