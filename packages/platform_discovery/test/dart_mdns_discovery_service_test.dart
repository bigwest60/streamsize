import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamsize_core/streamsize_core.dart';
import 'package:streamsize_platform_discovery/streamsize_platform_discovery.dart';
import 'package:streamsize_platform_discovery/src/device_classifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('classifyDevice', () {
    test('_airplay._tcp → tv / high', () {
      final d = classifyDevice('AppleTV._airplay._tcp.local');
      expect(d.category, DeviceCategory.tv);
      expect(d.confidence, ConfidenceScore.high);
      expect(d.displayName, 'AppleTV');
    });

    test('_googlecast._tcp → tv / high', () {
      final d = classifyDevice('Chromecast._googlecast._tcp.local');
      expect(d.category, DeviceCategory.tv);
      expect(d.confidence, ConfidenceScore.high);
    });

    test('_raop._tcp → smartHome / high (AirPlay speaker / HomePod)', () {
      final d = classifyDevice('HomePod._raop._tcp.local');
      expect(d.category, DeviceCategory.smartHome);
      expect(d.confidence, ConfidenceScore.high);
    });

    test('_hap._tcp → smartHome / high (HomeKit accessory)', () {
      final d = classifyDevice('BridgeLamp._hap._tcp.local');
      expect(d.category, DeviceCategory.smartHome);
      expect(d.confidence, ConfidenceScore.high);
    });

    test('_smb._tcp → laptop / medium (Mac with File Sharing)', () {
      final d = classifyDevice("Bill's MacBook Pro._smb._tcp.local");
      expect(d.category, DeviceCategory.laptop);
      expect(d.confidence, ConfidenceScore.medium);
    });

    test('_nas._tcp → nas / low (Swift NAS heuristic)', () {
      final d = classifyDevice('Synology._nas._tcp.local');
      expect(d.category, DeviceCategory.nas);
      expect(d.confidence, ConfidenceScore.low);
    });

    test('unknown service type → unknown / low', () {
      final d = classifyDevice('SomeDevice._http._tcp.local');
      expect(d.category, DeviceCategory.unknown);
      expect(d.confidence, ConfidenceScore.low);
    });
  });

  group('DartMDNSDiscoveryService.isPlatformSupported', () {
    test('returns bool', () {
      expect(DartMDNSDiscoveryService.isPlatformSupported, isA<bool>());
    });
  });

  group('DartMDNSDiscoveryService.discoverVisibleDevices', () {
    test('returns platformSupportsScan=false on macos', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final sut = DartMDNSDiscoveryService();
      final result = await sut.discoverVisibleDevices();
      expect(result.platformSupportsScan, isFalse);
      expect(result.devices, isEmpty);
    });

    test('returns platformSupportsScan=false on non-desktop platforms', () async {
      // Default platform is android; isPlatformSupported is false.
      final sut = DartMDNSDiscoveryService();
      final result = await sut.discoverVisibleDevices();
      expect(result.platformSupportsScan, isFalse);
      expect(result.devices, isEmpty);
    });
  });
}
