import 'package:streamsize_core/streamsize_core.dart';
import 'discovery_service.dart';

class MockDiscoveryService implements DiscoveryService {
  const MockDiscoveryService();

  @override
  Future<List<DetectedDevice>> discoverVisibleDevices() async {
    return const [
      DetectedDevice(
        displayName: 'Living Room Apple TV',
        category: DeviceCategory.tv,
        confidence: ConfidenceScore.high,
        connection: ConnectionType.ethernet,
      ),
      DetectedDevice(
        displayName: 'Office MacBook Pro',
        category: DeviceCategory.laptop,
        confidence: ConfidenceScore.high,
        connection: ConnectionType.wifi,
      ),
      DetectedDevice(
        displayName: 'Hallway Camera',
        category: DeviceCategory.camera,
        confidence: ConfidenceScore.medium,
        connection: ConnectionType.wifi,
      ),
      DetectedDevice(
        displayName: 'Bedroom iPhone',
        category: DeviceCategory.phone,
        confidence: ConfidenceScore.medium,
        connection: ConnectionType.wifi,
      ),
      DetectedDevice(
        displayName: 'Kitchen Speaker',
        category: DeviceCategory.smartHome,
        confidence: ConfidenceScore.low,
        connection: ConnectionType.wifi,
      ),
    ];
  }
}
