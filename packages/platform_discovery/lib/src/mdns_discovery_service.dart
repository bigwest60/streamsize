import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:streamsize_core/streamsize_core.dart';
import 'dart_mdns_discovery_service.dart';
import 'device_classifier.dart';
import 'discovery_service.dart';

class MDNSDiscoveryService implements DiscoveryService {
  static const _channel = MethodChannel('com.streamsize/mdns');

  /// Whether the current platform supports native mDNS scanning.
  /// macOS uses the Swift plugin; Windows and Linux use a pure-Dart fallback.
  static bool get isPlatformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
       defaultTargetPlatform == TargetPlatform.windows ||
       defaultTargetPlatform == TargetPlatform.linux);

  final DartMDNSDiscoveryService? _dartFallback;

  /// Creates an [MDNSDiscoveryService].
  ///
  /// [dartFallback] is the service to use on Windows and Linux.
  /// Defaults to a new [DartMDNSDiscoveryService]; injectable for tests.
  MDNSDiscoveryService({DartMDNSDiscoveryService? dartFallback})
      : _dartFallback = dartFallback ?? DartMDNSDiscoveryService();

  @override
  Future<DiscoveryResult> discoverVisibleDevices() async {
    // macOS: use the native Swift plugin.
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return _discoverViaSwiftPlugin();
    }

    // Windows / Linux: delegate to the pure-Dart fallback.
    if (DartMDNSDiscoveryService.isPlatformSupported) {
      return _dartFallback!.discoverVisibleDevices();
    }

    return const DiscoveryResult(devices: [], platformSupportsScan: false);
  }

  Future<DiscoveryResult> _discoverViaSwiftPlugin() async {
    try {
      // .timeout(10s) is a dead-man switch (crash guard), not scan duration
      // control. Swift asyncAfter(5s) always resolves first under normal
      // conditions. This timeout only fires if the Swift plugin hangs or crashes.
      final names = await _channel
          .invokeListMethod<String>('discoverServices')
          .timeout(const Duration(seconds: 10), onTimeout: () => []) ?? [];
      return DiscoveryResult(
        devices: names.map(classifyDevice).toList(),
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
  DetectedDevice parseServiceName(String name) => classifyDevice(name);
}
