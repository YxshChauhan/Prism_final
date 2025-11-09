import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:injectable/injectable.dart';

/// Service for managing device connection information
/// Uses FlutterSecureStorage for sensitive connection tokens
@injectable
class ConnectionService {
  static const String _connectionsKey = 'device_connections';
  static const String _legacyPrefsKey = 'device_connections'; // For migration
  
  final FlutterSecureStorage _secureStorage;
  final SharedPreferences _prefs;
  bool _migrated = false;
  
  ConnectionService(this._secureStorage, this._prefs) {
    _migrateFromSharedPreferences();
  }
  
  /// Migrate existing connection data from SharedPreferences to secure storage
  Future<void> _migrateFromSharedPreferences() async {
    if (_migrated) return;
    try {
      final String? legacyData = _prefs.getString(_legacyPrefsKey);
      if (legacyData != null && legacyData.isNotEmpty) {
        // Check if already migrated
        final String? existingData = await _secureStorage.read(key: _connectionsKey);
        if (existingData == null) {
          // Migrate data to secure storage
          await _secureStorage.write(key: _connectionsKey, value: legacyData);
          // Clear from SharedPreferences
          await _prefs.remove(_legacyPrefsKey);
        }
      }
      _migrated = true;
    } catch (e) {
      // Log migration failure but don't crash
      _migrated = true; // Don't retry indefinitely
    }
  }

  /// Store connection information for a discovered device
  Future<void> storeConnectionInfo(String deviceId, DeviceConnectionInfo info) async {
    try {
      final connections = await getStoredConnections();
      connections[deviceId] = info;
      
      final jsonString = jsonEncode(connections.map(
        (key, value) => MapEntry(key, value.toJson()),
      ));
      
      await _secureStorage.write(key: _connectionsKey, value: jsonString);
    } catch (e) {
      throw Exception('Failed to store connection info: $e');
    }
  }
  
  /// Get connection information for a device
  Future<DeviceConnectionInfo?> getConnectionInfo(String deviceId) async {
    try {
      final connections = await getStoredConnections();
      return connections[deviceId];
    } catch (e) {
      return null;
    }
  }
  
  /// Get all stored connections
  Future<Map<String, DeviceConnectionInfo>> getStoredConnections() async {
    try {
      final jsonString = await _secureStorage.read(key: _connectionsKey);
      if (jsonString == null || jsonString.isEmpty) return {};
      
      final Map<String, dynamic> json = jsonDecode(jsonString);
      return json.map(
        (key, value) => MapEntry(key, DeviceConnectionInfo.fromJson(value)),
      );
    } catch (e) {
      // Fallback to in-memory if secure storage fails
      return {};
    }
  }
  
  /// Remove connection information for a device
  Future<void> removeConnectionInfo(String deviceId) async {
    try {
      final connections = await getStoredConnections();
      connections.remove(deviceId);
      
      final jsonString = jsonEncode(connections.map(
        (key, value) => MapEntry(key, value.toJson()),
      ));
      
      await _secureStorage.write(key: _connectionsKey, value: jsonString);
    } catch (e) {
      throw Exception('Failed to remove connection info: $e');
    }
  }
  
  /// Clear all connection information
  Future<void> clearAllConnections() async {
    await _secureStorage.delete(key: _connectionsKey);
  }
  
  /// Update connection status
  Future<void> updateConnectionStatus(String deviceId, bool isConnected) async {
    try {
      final info = await getConnectionInfo(deviceId);
      if (info != null) {
        final updatedInfo = DeviceConnectionInfo(
          host: info.host,
          port: info.port,
          connectionMethod: info.connectionMethod,
          isConnected: isConnected,
          lastConnected: isConnected ? DateTime.now() : info.lastConnected,
          metadata: info.metadata,
        );
        
        await storeConnectionInfo(deviceId, updatedInfo);
      }
    } catch (e) {
      throw Exception('Failed to update connection status: $e');
    }
  }
  
  /// Get connection info by host and port
  Future<DeviceConnectionInfo?> getConnectionByHostPort(String host, int port) async {
    try {
      final connections = await getStoredConnections();
      
      for (final info in connections.values) {
        if (info.host == host && info.port == port) {
          return info;
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// Data class for device connection information
class DeviceConnectionInfo {
  final String host;
  final int port;
  final String connectionMethod; // 'wifi_aware', 'ble', 'multipeer'
  final bool isConnected;
  final DateTime? lastConnected;
  final Map<String, dynamic> metadata;
  
  // Transport-specific connection identifiers
  final String? connectionToken; // For BLE/Multipeer connections
  final String? peerId; // For peer-to-peer connections
  
  DeviceConnectionInfo({
    required this.host,
    required this.port,
    required this.connectionMethod,
    this.isConnected = false,
    this.lastConnected,
    this.metadata = const {},
    this.connectionToken,
    this.peerId,
  });
  
  factory DeviceConnectionInfo.fromJson(Map<String, dynamic> json) {
    return DeviceConnectionInfo(
      host: json['host'] as String,
      port: json['port'] as int,
      connectionMethod: json['connectionMethod'] as String,
      isConnected: json['isConnected'] as bool? ?? false,
      lastConnected: json['lastConnected'] != null 
          ? DateTime.parse(json['lastConnected'] as String)
          : null,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
      connectionToken: json['connectionToken'] as String?,
      peerId: json['peerId'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'port': port,
      'connectionMethod': connectionMethod,
      'isConnected': isConnected,
      'lastConnected': lastConnected?.toIso8601String(),
      'metadata': metadata,
      'connectionToken': connectionToken,
      'peerId': peerId,
    };
  }
  
  @override
  String toString() {
    return 'DeviceConnectionInfo(host: $host, port: $port, method: $connectionMethod, connected: $isConnected)';
  }
}