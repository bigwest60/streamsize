import 'models.dart';

class RecommendationEngine {
  PlanRecommendation buildRecommendation(HouseholdScenario scenario) {
    final detectedCounts = <DeviceCategory, int>{};
    for (final device in scenario.devices) {
      if (device.category == DeviceCategory.unknown) continue;
      detectedCounts.update(device.category, (value) => value + 1, ifAbsent: () => 1);
    }

    final maxConfidenceByCategory = <DeviceCategory, ConfidenceScore>{};
    for (final device in scenario.devices) {
      if (device.category == DeviceCategory.unknown) continue;
      final existing = maxConfidenceByCategory[device.category];
      if (existing == null || device.confidence.index > existing.index) {
        maxConfidenceByCategory[device.category] = device.confidence;
      }
    }

    final downloadDemand =
        (scenario.simultaneous4kStreams * 25) +
        (scenario.simultaneousHdStreams * 8) +
        (scenario.simultaneousVideoCalls * 6) +
        (scenario.remoteWorkers * 10) +
        (scenario.onlineGamers * 3) +
        _downloadHabitLoad(scenario.largeDownloadHabit) +
        _deviceBaselineDownloadWeighted(maxConfidenceByCategory, detectedCounts) +
        _homeProfileDownload(scenario.homeProfile) +
        _concurrencyOverhead(scenario);

    final uploadDemand =
        (scenario.simultaneousVideoCalls * 4) +
        (scenario.remoteWorkers * 5) +
        _cameraUploadLoad(scenario.devices, scenario.securityCameraCount) +
        (scenario.cloudBackupEnabled ? 20 : 0) +
        (detectedCounts[DeviceCategory.nas] ?? 0) * 5 +
        _homeProfileUpload(scenario.homeProfile);

    final normalizedDownload = _normalizeDownload(_withHeadroom(downloadDemand));
    final normalizedUpload = _normalizeUpload(_withHeadroom(uploadDemand));

    return PlanRecommendation(
      downloadMbps: normalizedDownload,
      uploadMbps: normalizedUpload,
      planLabel: '${normalizedDownload}/${normalizedUpload}',
      summary: _summary(normalizedDownload, normalizedUpload),
      reasons: _buildReasons(scenario, detectedCounts, maxConfidenceByCategory),
      confidence: _confidenceFor(scenario),
    );
  }

  int _deviceBaselineDownloadWeighted(
    Map<DeviceCategory, ConfidenceScore> maxConfidenceByCategory,
    Map<DeviceCategory, int> counts,
  ) {
    int total = 0;
    for (final entry in counts.entries) {
      final category = entry.key;
      final count = entry.value;
      final profile = category.bandwidthProfile;
      final confidence = maxConfidenceByCategory[category] ?? ConfidenceScore.medium;
      total += profile.mbpsForConfidence(confidence) * count;
    }
    return total;
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

  int _concurrencyOverhead(HouseholdScenario scenario) {
    final activeStreams = scenario.simultaneous4kStreams +
        scenario.simultaneousHdStreams +
        scenario.simultaneousVideoCalls +
        scenario.remoteWorkers +
        scenario.onlineGamers;
    if (activeStreams <= 2) return 0;
    if (activeStreams <= 5) return 10;
    if (activeStreams <= 8) return 20;
    return 30;
  }

  int _cameraUploadLoad(List<DetectedDevice> devices, int declaredCount) {
    final cameraDevices = devices.where((d) => d.category == DeviceCategory.camera).toList();
    final detectedCameras = cameraDevices.length;
    final totalCameras = detectedCameras > declaredCount ? detectedCameras : declaredCount;
    if (totalCameras == 0) return 0;
    final profile = DeviceCategory.camera.bandwidthProfile;
    // Best detected camera confidence for detected cameras; medium for declared-only
    final detectedConfidence = cameraDevices.isEmpty
        ? ConfidenceScore.medium
        : cameraDevices.fold<ConfidenceScore>(
            cameraDevices.first.confidence, (best, d) =>
                d.confidence.index > best.index ? d.confidence : best);
    final declaredOnlyCount = declaredCount > detectedCameras ? declaredCount - detectedCameras : 0;
    return (profile.mbpsForConfidence(detectedConfidence) * detectedCameras) +
        (profile.mbpsForConfidence(ConfidenceScore.medium) * declaredOnlyCount);
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

  List<String> _buildReasons(
    HouseholdScenario scenario,
    Map<DeviceCategory, int> counts,
    Map<DeviceCategory, ConfidenceScore> maxConfidenceByCategory,
  ) {
    final concurrencyOverhead = _concurrencyOverhead(scenario);
    final effectiveCameraCount = (counts[DeviceCategory.camera] ?? 0) > scenario.securityCameraCount
        ? counts[DeviceCategory.camera]!
        : scenario.securityCameraCount;
    return [
      if (scenario.simultaneous4kStreams > 0)
        '${scenario.simultaneous4kStreams} simultaneous 4K stream${scenario.simultaneous4kStreams != 1 ? "s" : ""} (25 Mbps each)',
      if (scenario.simultaneousHdStreams > 0)
        '${scenario.simultaneousHdStreams} simultaneous HD stream${scenario.simultaneousHdStreams != 1 ? "s" : ""} (8 Mbps each)',
      if (scenario.simultaneousVideoCalls > 0)
        '${scenario.simultaneousVideoCalls} live video call${scenario.simultaneousVideoCalls != 1 ? "s" : ""} (6 Mbps down / 4 Mbps up)',
      if (scenario.remoteWorkers > 0)
        '${scenario.remoteWorkers} remote worker${scenario.remoteWorkers != 1 ? "s" : ""} (10 Mbps each)',
      if (scenario.onlineGamers > 0)
        '${scenario.onlineGamers} online gamer${scenario.onlineGamers != 1 ? "s" : ""} (3 Mbps each)',
      if (effectiveCameraCount > 0)
        '$effectiveCameraCount security camera${effectiveCameraCount != 1 ? "s" : ""} uploading footage',
      if (scenario.cloudBackupEnabled)
        'Cloud backup headroom included (20 Mbps)',
      '${scenario.devices.length} device${scenario.devices.length != 1 ? "s" : ""} on the network',
      if ((counts[DeviceCategory.tv] ?? 0) > 0)
        '${counts[DeviceCategory.tv]} TV/streamer${(counts[DeviceCategory.tv]) != 1 ? "s" : ""} (${_confidenceLabel(maxConfidenceByCategory[DeviceCategory.tv])} ${DeviceCategory.tv.bandwidthProfile.mbpsForConfidence(maxConfidenceByCategory[DeviceCategory.tv] ?? ConfidenceScore.medium)} Mbps each)',
      if (scenario.largeDownloadHabit != LargeDownloadHabit.rarely)
        '${scenario.largeDownloadHabit.label} large downloads (+${_downloadHabitLoad(scenario.largeDownloadHabit)} Mbps)',
      if (concurrencyOverhead > 0)
        'Concurrency overhead: $concurrencyOverhead Mbps for ${scenario.simultaneous4kStreams + scenario.simultaneousHdStreams + scenario.simultaneousVideoCalls + scenario.remoteWorkers + scenario.onlineGamers} simultaneous active streams',
    ];
  }

  String _confidenceLabel(ConfidenceScore? confidence) {
    switch (confidence ?? ConfidenceScore.medium) {
      case ConfidenceScore.high:
        return 'up to';
      case ConfidenceScore.medium:
        return '~';
      case ConfidenceScore.low:
        return 'at least';
    }
  }

  ConfidenceScore _confidenceFor(HouseholdScenario scenario) {
    final highConfidenceDevices = scenario.devices.where((d) => d.confidence == ConfidenceScore.high).length;
    final totalDevices = scenario.devices.length;
    final ratio = totalDevices > 0 ? highConfidenceDevices / totalDevices : 0.0;

    final hasExplicitUsage = scenario.simultaneous4kStreams > 0 ||
        scenario.simultaneousHdStreams > 0 ||
        scenario.simultaneousVideoCalls > 0 ||
        scenario.remoteWorkers > 0 ||
        scenario.onlineGamers > 0 ||
        scenario.securityCameraCount > 0 ||
        scenario.cloudBackupEnabled ||
        scenario.largeDownloadHabit != LargeDownloadHabit.rarely;

    if (totalDevices >= 4 && ratio >= 0.6 && hasExplicitUsage) {
      return ConfidenceScore.high;
    }
    if (totalDevices >= 1 || hasExplicitUsage) {
      return ConfidenceScore.medium;
    }
    return ConfidenceScore.low;
  }
}
