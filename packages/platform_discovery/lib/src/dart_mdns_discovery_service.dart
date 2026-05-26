import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:multicast_dns/multicast_dns.dart';
import 'device_classifier.dart';
import 'discovery_service.dart';

/// Pure-Dart mDNS discovery for Windows and Linux desktops.
///
/// Uses the [multicast_dns] package to browse the same five Bonjour
/// service types as the macOS Swift plugin.  On non-macOS platforms
/// that support the `multicast_dns` package (Windows, Linux), this
/// provides real network discovery without native code.
///
/// TXT-record inspection (the NAS heuristic) is not available through
/// [multicast_dns], so all `_smb` responders are classified as `laptop`
/// with medium confidence — the same safe default the macOS plugin uses
/// when the `model=` TXT key is absent.
class DartMDNSDiscoveryService implements DiscoveryService {
  /// Service types to scan, matching the macOS Swift plugin.
  static const _serviceTypes = [
    '_airplay._tcp',
    '_googlecast._tcp',
    '_hap._tcp',
    '_raop._tcp',
    '_smb._tcp',
  ];

  /// Whether the current platform supports the [multicast_dns] package.
  /// This is false on macOS (which uses the native Swift plugin) and on
  /// the web; true on Windows and Linux.
  static bool get isPlatformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
       defaultTargetPlatform == TargetPlatform.linux);

  @override
  Future<DiscoveryResult> discoverVisibleDevices() async {
    if (!isPlatformSupported) {
      return const DiscoveryResult(devices: [], platformSupportsScan: false);
    }

    final client = MDnsClient();
    try {
      await client.start();

      final seen = <String>{};
      final List<String> serviceNames = [];

      for (final serviceType in _serviceTypes) {
        try {
          await for (final ptr in client.lookup<PtrResourceRecord>(
            ResourceRecordQuery.serverPointer(serviceType),
            timeout: const Duration(seconds: 5),
          )) {
            final name = '${ptr.name}.$serviceType';
            if (seen.add(name)) {
              serviceNames.add(name);
            }
          }
        } on TimeoutException {
          // Expected: scan window closed.
        }
      }

      client.stop();

      return DiscoveryResult(
        devices: serviceNames.map(classifyDevice).toList(),
        platformSupportsScan: true,
      );
    } catch (_) {
      return const DiscoveryResult(devices: [], platformSupportsScan: false);
    }
  }
}
