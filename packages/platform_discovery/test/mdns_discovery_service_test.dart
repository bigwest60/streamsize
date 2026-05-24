import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:streamsize_core/streamsize_core.dart';
import 'package:streamsize_platform_discovery/streamsize_platform_discovery.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('MDNSDiscoveryService.discoverVisibleDevices', () {
    test('short-circuits with platformSupportsScan=false on non-macOS without invoking channel', () async {
      // On the default test platform (android), isPlatformSupported is false,
      // so discoverVisibleDevices returns immediately without calling the channel.
      final sut = MDNSDiscoveryService();
      final result = await sut.discoverVisibleDevices();
      expect(result.platformSupportsScan, isFalse);
      expect(result.devices, isEmpty);
    });

    test('catches MissingPluginException and returns platformSupportsScan=false on macOS', () async {
      // Override to macOS so the channel is invoked, but the plugin is absent.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      var handlerInvoked = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.streamsize/mdns'),
        (MethodCall methodCall) async {
          handlerInvoked = true;
          throw MissingPluginException('no plugin');
        },
      );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.streamsize/mdns'),
          null,
        );
      });

      final sut = MDNSDiscoveryService();
      final result = await sut.discoverVisibleDevices();
      expect(handlerInvoked, isTrue);
      expect(result.platformSupportsScan, isFalse);
      expect(result.devices, isEmpty);
    });

    test('returns discovered devices with platformSupportsScan=true when channel responds', () async {
      // Simulate macOS where the plugin returns device names.
      // The test binding defaults to android, so override to macOS.
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.streamsize/mdns'),
        (MethodCall methodCall) async {
          if (methodCall.method == 'discoverServices') {
            return ['AppleTV._airplay._tcp', 'HomePod._raop._tcp'];
          }
          return null;
        },
      );
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
          const MethodChannel('com.streamsize/mdns'),
          null,
        );
      });

      final sut = MDNSDiscoveryService();
      final result = await sut.discoverVisibleDevices();
      expect(result.platformSupportsScan, isTrue);
      expect(result.devices.length, 2);
      expect(result.devices[0].category, DeviceCategory.tv);
      expect(result.devices[1].category, DeviceCategory.smartHome);
    });

    test('isPlatformSupported returns bool', () {
      expect(MDNSDiscoveryService.isPlatformSupported, isA<bool>());
    });
  });
}
