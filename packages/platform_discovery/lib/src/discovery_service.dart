import 'package:streamsize_core/streamsize_core.dart';

/// Result of a device discovery scan, carrying both the found devices
/// and metadata about whether the platform supports native scanning.
class DiscoveryResult {
  const DiscoveryResult({
    required this.devices,
    required this.platformSupportsScan,
  });

  /// Devices found during the scan.
  final List<DetectedDevice> devices;

  /// Whether the current platform supports native mDNS scanning.
  /// When false, [devices] will always be empty and the UI should
  /// prompt the user to add devices manually.
  final bool platformSupportsScan;
}

abstract class DiscoveryService {
  Future<DiscoveryResult> discoverVisibleDevices();
}
