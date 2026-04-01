import 'package:streamsize_core/streamsize_core.dart';

abstract class DiscoveryService {
  Future<List<DetectedDevice>> discoverVisibleDevices();
}
