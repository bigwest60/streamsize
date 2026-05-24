import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:streamsize_core/streamsize_core.dart';
import 'discovery_service.dart';

class MDNSDiscoveryService implements DiscoveryService {
  static const _channel = MethodChannel('com.streamsize/mdns');

  /// Whether the current platform supports native mDNS scanning.
  /// Only macOS has the Swift plugin; Windows and Linux fall back gracefully.
  static bool get isPlatformSupported =>
      !kIsWeb && Platform.isMacOS;

  @override
  Future<DiscoveryResult> discoverVisibleDevices() async {
    if (!isPlatformSupported) {
      return const DiscoveryResult(
        devices: [],
        platformSupportsScan: false,
      );
    }

    try {
      // .timeout(10s) is a dead-man switch (crash guard), not scan duration
      // control. Swift asyncAfter(5s) always resolves first under normal
      // conditions. This timeout only fires if the Swift plugin hangs or crashes.
      final names = await _channel
          .invokeListMethod<String>('discoverServices')
          .timeout(const Duration(seconds: 10), onTimeout: () => []) ?? [];
      return DiscoveryResult(
        devices: names.map(_parseServiceName).toList(),
        platformSupportsScan: true,
      );
    } on MissingPluginException {
      // Plugin not registered (e.g. running in tests).
      return const DiscoveryResult(
        devices: [],
        platformSupportsScan: false,
      );
    }
  }

  @visibleForTesting
  DetectedDevice parseServiceName(String name) => _parseServiceName(name);

  DetectedDevice _parseServiceName(String name) {
    final hostname = name.split('.').first;
    DeviceCategory category;
    ConfidenceScore confidence;

    if (name.contains('_airplay._tcp') || name.contains('_googlecast._tcp')) {
      category = DeviceCategory.tv;
      confidence = ConfidenceScore.high;
    } else if (name.contains('_raop._tcp')) {
      category = DeviceCategory.smartHome; // AirPlay speaker / HomePod
      confidence = ConfidenceScore.high;
    } else if (name.contains('_hap._tcp')) {
      category = DeviceCategory.smartHome; // HomeKit accessory
      confidence = ConfidenceScore.high;
    } else if (name.contains('_nas._tcp')) {
      // Synthesized type: Swift heuristic identified this as NAS, not a Mac.
      // TXT record model= did not start with "mac"/"imac".
      category = DeviceCategory.nas;
      confidence = ConfidenceScore.low; // heuristic is best-effort
    } else if (name.contains('_smb._tcp')) {
      // Mac with File Sharing enabled, or model= key was absent (safe default).
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
}
