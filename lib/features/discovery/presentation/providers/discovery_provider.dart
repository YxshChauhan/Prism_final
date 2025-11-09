import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:airlink/core/services/dependency_injection.dart';

final discoveryProvider = StreamProvider<List<Device>>((ref) {
  final discoveryRepository = getIt<DiscoveryRepository>();
  return discoveryRepository.startDiscovery();
});

final discoveryControllerProvider = Provider<DiscoveryController>((ref) {
  return DiscoveryController();
});

class DiscoveryController {
  DiscoveryController();
  
  Future<void> startDiscovery() async {
    final discoveryRepository = getIt<DiscoveryRepository>();
    await discoveryRepository.startAdvertising();
  }
  
  Future<void> stopDiscovery() async {
    final discoveryRepository = getIt<DiscoveryRepository>();
    await discoveryRepository.stopDiscovery();
    await discoveryRepository.stopAdvertising();
  }
  
  Future<bool> connectToDevice(Device device) async {
    final discoveryRepository = getIt<DiscoveryRepository>();
    return await discoveryRepository.connectToDevice(device);
  }
  
  Future<void> disconnectFromDevice(Device device) async {
    final discoveryRepository = getIt<DiscoveryRepository>();
    await discoveryRepository.disconnectFromDevice(device);
  }
}
