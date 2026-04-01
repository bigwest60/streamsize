import 'package:flutter_test/flutter_test.dart';
import 'package:streamsize_core/streamsize_core.dart';
import 'package:streamsize_platform_discovery/streamsize_platform_discovery.dart';

void main() {
  group('MDNSDiscoveryService.parseServiceName', () {
    late MDNSDiscoveryService sut;

    setUp(() => sut = MDNSDiscoveryService());

    test('_airplay._tcp → tv / high', () {
      final d = sut.parseServiceName('AppleTV._airplay._tcp.local');
      expect(d.category, DeviceCategory.tv);
      expect(d.confidence, ConfidenceScore.high);
      expect(d.displayName, 'AppleTV');
    });

    test('_googlecast._tcp → tv / high', () {
      final d = sut.parseServiceName('Chromecast._googlecast._tcp.local');
      expect(d.category, DeviceCategory.tv);
      expect(d.confidence, ConfidenceScore.high);
    });

    test('_raop._tcp → smartHome / high (AirPlay speaker / HomePod)', () {
      final d = sut.parseServiceName('HomePod._raop._tcp.local');
      expect(d.category, DeviceCategory.smartHome);
      expect(d.confidence, ConfidenceScore.high);
    });

    test('_hap._tcp → smartHome / high (HomeKit accessory)', () {
      final d = sut.parseServiceName('BridgeLamp._hap._tcp.local');
      expect(d.category, DeviceCategory.smartHome);
      expect(d.confidence, ConfidenceScore.high);
    });

    test('_smb._tcp → laptop / medium (Mac with File Sharing)', () {
      final d = sut.parseServiceName("Bill's MacBook Pro._smb._tcp.local");
      expect(d.category, DeviceCategory.laptop);
      expect(d.confidence, ConfidenceScore.medium);
    });

    test('_nas._tcp → nas / low (Swift NAS heuristic)', () {
      final d = sut.parseServiceName('Synology._nas._tcp.local');
      expect(d.category, DeviceCategory.nas);
      expect(d.confidence, ConfidenceScore.low);
    });

    test('unknown service type → unknown / low', () {
      final d = sut.parseServiceName('SomeDevice._http._tcp.local');
      expect(d.category, DeviceCategory.unknown);
      expect(d.confidence, ConfidenceScore.low);
    });
  });
}
