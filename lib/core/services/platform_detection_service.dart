import 'dart:io';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/core/services/airlink_plugin.dart';
import 'package:injectable/injectable.dart';

enum DiscoveryMethod {
  wifiAware,
  ble,
  webrtc,
  hotspot,
  cloudRelay,
}

enum PlatformCapability {
  wifiAware,
  ble,
  webrtc,
  hotspot,
  cloudRelay,
  multipeerConnectivity,
  networkDiscovery,
}

class PlatformCapabilities {
  final bool isAndroid;
  final bool isIOS;
  final bool isAndroidAPI26Plus;
  final bool isIOS12Plus;
  final Set<PlatformCapability> supportedCapabilities;
  final Map<DiscoveryMethod, int> discoveryMethodPriority;
  
  const PlatformCapabilities({
    required this.isAndroid,
    required this.isIOS,
    required this.isAndroidAPI26Plus,
    required this.isIOS12Plus,
    required this.supportedCapabilities,
    required this.discoveryMethodPriority,
  });
  
  bool hasCapability(PlatformCapability capability) {
    return supportedCapabilities.contains(capability);
  }
  
  List<DiscoveryMethod> getAvailableDiscoveryMethods() {
    return discoveryMethodPriority.keys.toList();
  }
  
  DiscoveryMethod getPrimaryDiscoveryMethod() {
    return discoveryMethodPriority.entries
        .where((entry) => entry.value == 1)
        .first
        .key;
  }
  
  List<DiscoveryMethod> getFallbackDiscoveryMethods() {
    final filteredEntries = discoveryMethodPriority.entries
        .where((entry) => entry.value > 1)
        .toList();
    filteredEntries.sort((a, b) => a.value.compareTo(b.value));
    return filteredEntries.map((entry) => entry.key).toList();
  }
}

@injectable
class PlatformDetectionService {
  final LoggerService _loggerService;
  PlatformCapabilities? _cachedCapabilities;
  
  PlatformDetectionService(this._loggerService);
  
  Future<PlatformCapabilities> detectPlatformCapabilities() async {
    if (_cachedCapabilities != null) {
      return _cachedCapabilities!;
    }
    
    _loggerService.info('Detecting platform capabilities...');
    
    final isAndroid = Platform.isAndroid;
    final isIOS = Platform.isIOS;
    final isAndroidAPI26Plus = await _checkAndroidAPILevel();
    final isIOS12Plus = await _checkIOSVersion();
    
    final supportedCapabilities = <PlatformCapability>{};
    final discoveryMethodPriority = <DiscoveryMethod, int>{};
    
    // Detect Android capabilities
    if (isAndroid) {
      if (isAndroidAPI26Plus) {
        // Check Wi-Fi Aware support
        final wifiAwareSupported = await _checkWifiAwareSupport();
        if (wifiAwareSupported) {
          supportedCapabilities.add(PlatformCapability.wifiAware);
          discoveryMethodPriority[DiscoveryMethod.wifiAware] = 1; // Primary
        }
      }
      
      // BLE is always available on Android (API 21+)
      supportedCapabilities.add(PlatformCapability.ble);
      discoveryMethodPriority[DiscoveryMethod.ble] = 2; // Fallback
      
      // WebRTC is available
      supportedCapabilities.add(PlatformCapability.webrtc);
      discoveryMethodPriority[DiscoveryMethod.webrtc] = 3; // Secondary fallback
      
      // Hotspot is available
      supportedCapabilities.add(PlatformCapability.hotspot);
      discoveryMethodPriority[DiscoveryMethod.hotspot] = 4; // Tertiary fallback
    }
    
    // Detect iOS capabilities
    if (isIOS) {
      if (isIOS12Plus) {
        // MultipeerConnectivity is available
        supportedCapabilities.add(PlatformCapability.multipeerConnectivity);
        discoveryMethodPriority[DiscoveryMethod.webrtc] = 1; // Primary (via MultipeerConnectivity)
      }
      
      // BLE is available
      supportedCapabilities.add(PlatformCapability.ble);
      discoveryMethodPriority[DiscoveryMethod.ble] = 2; // Fallback
      
      // Network discovery is available
      supportedCapabilities.add(PlatformCapability.networkDiscovery);
      discoveryMethodPriority[DiscoveryMethod.webrtc] = 3; // Secondary fallback
      
      // WebRTC is available
      supportedCapabilities.add(PlatformCapability.webrtc);
    }
    
    // Cloud relay is always available as last resort
    supportedCapabilities.add(PlatformCapability.cloudRelay);
    discoveryMethodPriority[DiscoveryMethod.cloudRelay] = 999; // Last resort
    
    _cachedCapabilities = PlatformCapabilities(
      isAndroid: isAndroid,
      isIOS: isIOS,
      isAndroidAPI26Plus: isAndroidAPI26Plus,
      isIOS12Plus: isIOS12Plus,
      supportedCapabilities: supportedCapabilities,
      discoveryMethodPriority: discoveryMethodPriority,
    );
    
    _loggerService.info('Platform capabilities detected: ${_cachedCapabilities!.supportedCapabilities}');
    _loggerService.info('Discovery method priority: ${_cachedCapabilities!.discoveryMethodPriority}');
    
    return _cachedCapabilities!;
  }
  
  Future<bool> _checkAndroidAPILevel() async {
    if (!Platform.isAndroid) return false;
    
    try {
      // This would typically be done through platform channels
      // For now, we'll assume API 26+ if we're on Android
      return true;
    } catch (e) {
      _loggerService.warning('Failed to check Android API level: $e');
      return false;
    }
  }
  
  Future<bool> _checkIOSVersion() async {
    if (!Platform.isIOS) return false;
    
    try {
      // This would typically be done through platform channels
      // For now, we'll assume iOS 12+ if we're on iOS
      return true;
    } catch (e) {
      _loggerService.warning('Failed to check iOS version: $e');
      return false;
    }
  }
  
  Future<bool> _checkWifiAwareSupport() async {
    if (!Platform.isAndroid) return false;
    
    try {
      return await AirLinkPlugin.isWifiAwareSupported();
    } catch (e) {
      _loggerService.warning('Failed to check Wi-Fi Aware support: $e');
      return false;
    }
  }
  
  
  void clearCache() {
    _cachedCapabilities = null;
  }
}
