import 'package:streamsize_core/streamsize_core.dart';

/// Shared device-classification logic used by both [MDNSDiscoveryService]
/// (macOS Swift plugin) and [DartMDNSDiscoveryService] (pure-Dart fallback).
///
/// Parses a Bonjour service name of the form `hostname._type._tcp[.local]`
/// and returns a [DetectedDevice] with the appropriate category, confidence,
/// and default Wi-Fi connection type.
DetectedDevice classifyDevice(String serviceName) {
  final hostname = serviceName.split('.').first;
  DeviceCategory category;
  ConfidenceScore confidence;

  if (serviceName.contains('_airplay._tcp') ||
      serviceName.contains('_googlecast._tcp')) {
    category = DeviceCategory.tv;
    confidence = ConfidenceScore.high;
  } else if (serviceName.contains('_raop._tcp')) {
    category = DeviceCategory.smartHome;
    confidence = ConfidenceScore.high;
  } else if (serviceName.contains('_hap._tcp')) {
    category = DeviceCategory.smartHome;
    confidence = ConfidenceScore.high;
  } else if (serviceName.contains('_nas._tcp')) {
    category = DeviceCategory.nas;
    confidence = ConfidenceScore.low;
  } else if (serviceName.contains('_smb._tcp')) {
    category = DeviceCategory.laptop;
    confidence = ConfidenceScore.medium;
  } else {
    category = DeviceCategory.unknown;
    confidence = ConfidenceScore.low;
  }

  return DetectedDevice(
    displayName: hostname,
    category: category,
    confidence: confidence,
    connection: ConnectionType.wifi,
  );
}
