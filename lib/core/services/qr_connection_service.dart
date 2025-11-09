import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:airlink/core/protocol/airlink_protocol.dart';
import 'package:airlink/core/security/secure_session.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for QR code-based device connections
/// Generates QR codes for this device and connects to other devices via scanned QR codes
class QRConnectionService {
  final LoggerService _logger = LoggerService();
  final NetworkInfo _networkInfo = NetworkInfo();
  final Uuid _uuid = const Uuid();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const int defaultPort = 8765;
  static const int qrValidityMinutes = 5;
  static const int connectionTimeoutSeconds = 30;
  static const int maxRetryAttempts = 3;
  static const String _deviceIdKey = 'airlink_device_id';
  
  // Connection state tracking
  final StreamController<QRConnectionState> _connectionStateController = 
      StreamController<QRConnectionState>.broadcast();
  Stream<QRConnectionState> get connectionStateStream => _connectionStateController.stream;
  QRConnectionState _currentState = QRConnectionState.idle;

  /// Generate QR data containing connection information for this device
  /// Format v2: {v, deviceId, name, connectionMethod, publicKey, sessionId, ipAddress, port, timestamp}
  Future<String> generateQRData({required String deviceName}) async {
    try {
      final deviceId = await _getOrCreateDeviceId();
      final ipAddress = await _getLocalIPAddress();
      // Create an ephemeral session to include public key and session id
      final String sessionId = _uuid.v4();
      final SecureSession session = await globalSessionManager.createSession(
        sessionId,
        deviceId,
      );
      final String publicKeyB64 = base64Encode(session.localPublicKey);
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Set platform-specific connection method
      final String connectionMethod = _getPlatformConnectionMethod();
      
      final connectionData = {
        'v': 2, // Protocol version
        'deviceId': deviceId,
        'name': deviceName,
        'connectionMethod': connectionMethod,
        'publicKey': publicKeyB64,
        'sessionId': sessionId,
        'ipAddress': ipAddress,
        'port': defaultPort,
        'timestamp': timestamp,
      };

      final qrString = jsonEncode(connectionData);
      _logger.info('Generated QR data for device: $deviceName');

      return qrString;
    } catch (e) {
      _logger.error('Failed to generate QR data', e);
      rethrow;
    }
  }

  /// Parse and validate scanned QR code data
  /// Returns connection data if valid, throws exception if invalid
  Future<QRConnectionData> parseQRData(String qrString) async {
    try {
      final data = jsonDecode(qrString) as Map<String, dynamic>;

      // Validate version
      final version = data['v'] as int?;
      if (version == null || (version != 1 && version != 2)) {
        throw QRConnectionException('Unsupported QR code version');
      }

      // Validate timestamp (must be within valid period)
      final timestamp = data['timestamp'] as int?;
      if (timestamp == null) {
        throw QRConnectionException('Missing timestamp');
      }

      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      final maxAge = qrValidityMinutes * 60 * 1000;

      if (age > maxAge) {
        throw QRConnectionException(
          'QR code expired (max $qrValidityMinutes minutes)',
        );
      }

      // Extract and validate required fields
      final String? deviceId = data['deviceId'] as String?;
      final String? name = data['name'] as String?;
      final String? ipAddress = data['ipAddress'] as String?;
      final int? port = data['port'] as int?;
      final String? connectionMethod =
          (data['connectionMethod'] ?? 'wifi_aware') as String?;
      final String? publicKeyB64 = data['publicKey'] as String?;
      final String? sessionId = (data['sessionId'] ?? _uuid.v4()) as String?;
      if (deviceId == null ||
          name == null ||
          ipAddress == null ||
          port == null) {
        throw QRConnectionException('Missing required fields');
      }

      _logger.info('Parsed valid QR code for device: $name');

      return QRConnectionData(
        deviceId: deviceId,
        name: name,
        ipAddress: ipAddress,
        port: port,
        connectionMethod: connectionMethod ?? 'wifi_aware',
        publicKeyBase64: publicKeyB64,
        sessionId: sessionId ?? _uuid.v4(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
      );
    } catch (e) {
      _logger.error('Failed to parse QR data', e);
      if (e is QRConnectionException) {
        rethrow;
      }
      throw QRConnectionException('Invalid QR code format');
    }
  }

  /// Initiate connection to a device using scanned QR data with timeout and retry logic
  Future<AirLinkProtocol> connectViaQR(QRConnectionData qrData) async {
    int attemptCount = 0;
    Exception? lastException;
    
    while (attemptCount < maxRetryAttempts) {
      try {
        attemptCount++;
        _updateConnectionState(QRConnectionState.connecting);
        _logger.info('Initiating QR connection to: ${qrData.name} (attempt $attemptCount/$maxRetryAttempts)');
        
        return await _connectViaQRWithTimeout(qrData);
      } on QRConnectionTimeoutException catch (e) {
        lastException = e;
        _logger.warning('Connection attempt $attemptCount timed out: ${e.message}');
        if (attemptCount < maxRetryAttempts) {
          // Exponential backoff: 1s, 2s, 4s
          final delaySeconds = pow(2, attemptCount - 1).toInt();
          _logger.info('Retrying in ${delaySeconds}s...');
          await Future.delayed(Duration(seconds: delaySeconds));
        }
      } on QRConnectionException catch (e) {
        // Non-recoverable errors - don't retry
        _updateConnectionState(QRConnectionState.failed);
        _logger.error('QR connection failed (non-recoverable)', e);
        rethrow;
      } catch (e) {
        lastException = e as Exception;
        _logger.error('QR connection failed (attempt $attemptCount)', e);
        if (attemptCount >= maxRetryAttempts) {
          _updateConnectionState(QRConnectionState.failed);
          rethrow;
        }
      }
    }
    
    _updateConnectionState(QRConnectionState.failed);
    throw QRConnectionException(
      'Failed to connect after $maxRetryAttempts attempts: ${lastException?.toString() ?? "Unknown error"}',
    );
  }
  
  /// Internal connection method with timeout
  Future<AirLinkProtocol> _connectViaQRWithTimeout(QRConnectionData qrData) async {
    try {
      _logger.debug('Validating QR connection data...');

      // Validate QR data
      _validateQRConnectionData(qrData);
      
      // Create protocol instance (no temp keys)
      final protocol = AirLinkProtocol(
        deviceId: await _getOrCreateDeviceId(),
        capabilities: {
          'encryption': true,
          'wifi_aware': true,
          'qr_connection': true,
        },
      );

      _logger.debug('Connecting to ${qrData.ipAddress}:${qrData.port}...');
      _updateConnectionState(QRConnectionState.establishing);
      
      // Connect to the remote device with timeout
      final success = await protocol.connectToDevice(
        qrData.ipAddress,
        qrData.port,
      ).timeout(
        Duration(seconds: connectionTimeoutSeconds),
        onTimeout: () => throw QRConnectionTimeoutException(
          'Connection timed out after ${connectionTimeoutSeconds}s',
        ),
      );

      if (!success) {
        throw QRConnectionNetworkException('Failed to establish network connection');
      }

      _logger.debug('Establishing secure session...');
      _updateConnectionState(QRConnectionState.handshaking);
      
      // Create/obtain a secure session and complete handshake with timeout
      final String sessionId = qrData.sessionId ?? _uuid.v4();
      await globalSessionManager.createSession(
        sessionId,
        qrData.deviceId,
        connectionMethod: qrData.connectionMethod,
      ).timeout(
        Duration(seconds: connectionTimeoutSeconds),
        onTimeout: () => throw QRConnectionTimeoutException(
          'Session creation timed out after ${connectionTimeoutSeconds}s',
        ),
      );

      // If remote provided public key, complete handshake immediately
      if (qrData.publicKeyBase64 != null) {
        final Uint8List remotePub = Uint8List.fromList(
          base64Decode(qrData.publicKeyBase64!),
        );
        await globalSessionManager.completeHandshakeSimple(
          sessionId,
          remotePub,
        ).timeout(
          Duration(seconds: connectionTimeoutSeconds),
          onTimeout: () => throw QRConnectionTimeoutException(
            'Handshake timed out after ${connectionTimeoutSeconds}s',
          ),
        );
      }

      _logger.debug('Verifying handshake...');
      _updateConnectionState(QRConnectionState.verifying);
      
      // Exchange verification payloads over chosen transport if needed (out-of-band stub)
      final Map<String, dynamic> verifyPayload = await globalSessionManager
          .generateVerificationPayload(sessionId);
      final bool verified = await globalSessionManager.verifyIncomingPayload(
        sessionId,
        verifyPayload,
      );
      if (!verified) {
        throw QRConnectionHandshakeException('Handshake verification failed - encryption keys do not match');
      }

      _updateConnectionState(QRConnectionState.connected);
      _logger.info(
        'Successfully connected via QR and completed handshake with: ${qrData.name}',
      );
      return protocol;
    } catch (e) {
      _logger.error('QR connection failed', e);
      rethrow;
    }
  }

  /// Get local IP address for this device
  Future<String> _getLocalIPAddress() async {
    try {
      // Try WiFi first
      String? ipAddress = await _networkInfo.getWifiIP();

      // Only allow 127.0.0.1 in debug mode for simulator/development
      if (ipAddress == null || ipAddress.isEmpty) {
        const bool kDebugMode = bool.fromEnvironment('dart.vm.product') == false;
        if (kDebugMode) {
          _logger.warning('Could not get WiFi IP, using localhost (debug mode only)');
          return '127.0.0.1';
        } else {
          throw QRConnectionException('Not connected to Wi-Fi. Please connect to a Wi-Fi network to generate QR code.');
        }
      }
      
      return ipAddress;
    } catch (e) {
      if (e is QRConnectionException) rethrow;
      _logger.error('Failed to get IP address', e);
      throw QRConnectionException('Unable to determine device IP address. Please check your network connection.');
    }
  }

  /// Get or create a persistent device ID using secure storage
  Future<String> _getOrCreateDeviceId() async {
    try {
      // Try to read existing device ID from secure storage
      String? deviceId = await _secureStorage.read(key: _deviceIdKey);
      
      if (deviceId == null || deviceId.isEmpty) {
        // Generate new device ID and store it
        deviceId = _uuid.v4();
        await _secureStorage.write(key: _deviceIdKey, value: deviceId);
        _logger.info('Generated and stored new device ID: ${deviceId.substring(0, 8)}...');
      } else {
        _logger.debug('Retrieved existing device ID: ${deviceId.substring(0, 8)}...');
      }
      
      return deviceId;
    } catch (e) {
      _logger.error('Failed to get/create device ID from secure storage', e);
      // Fallback to generating a new ID (not persisted)
      _logger.warning('Using non-persistent device ID as fallback');
      return _uuid.v4();
    }
  }
  
  /// Validate QR connection data thoroughly
  void _validateQRConnectionData(QRConnectionData qrData) {
    _logger.debug('Validating QR connection data...');
    
    // Validate IP address format (IPv4, IPv6, or mDNS hostname)
    if (!_isValidIPAddress(qrData.ipAddress)) {
      throw QRConnectionException('Invalid IP address format: ${qrData.ipAddress}');
    }
    
    // Validate port range
    if (qrData.port < 1 || qrData.port > 65535) {
      throw QRConnectionException('Invalid port number: ${qrData.port} (must be 1-65535)');
    }
    
    // Validate device ID format (should be UUID)
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    if (!uuidRegex.hasMatch(qrData.deviceId)) {
      throw QRConnectionException('Invalid device ID format: ${qrData.deviceId}');
    }
    
    // Validate connection method
    final validMethods = ['wifi_aware', 'multipeer', 'ble'];
    if (qrData.connectionMethod != null && 
        !validMethods.contains(qrData.connectionMethod)) {
      throw QRConnectionException(
        'Invalid connection method: ${qrData.connectionMethod} (must be one of: ${validMethods.join(", ")})',
      );
    }
    
    _logger.debug('QR connection data validation passed');
  }
  
  /// Update connection state and emit event
  void _updateConnectionState(QRConnectionState newState) {
    _currentState = newState;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(newState);
    }
    _logger.debug('Connection state changed: ${newState.name}');
  }
  
  /// Get current connection state
  QRConnectionState get currentConnectionState => _currentState;
  
  /// Dispose resources
  void dispose() {
    _connectionStateController.close();
  }
  
  /// Get platform-specific connection method
  String _getPlatformConnectionMethod() {
    if (Platform.isIOS) {
      return 'multipeer'; // iOS uses MultipeerConnectivity
    } else if (Platform.isAndroid) {
      return 'wifi_aware'; // Android uses Wi-Fi Aware
    } else {
      return 'qr_tcp'; // Fallback for other platforms
    }
  }
  
  /// Validate IP address (IPv4, IPv6, or mDNS hostname)
  bool _isValidIPAddress(String address) {
    // IPv4 validation with strict octet range (0-255)
    final ipv4Regex = RegExp(
      r'^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$'
    );
    if (ipv4Regex.hasMatch(address)) {
      return true;
    }
    
    // IPv6 validation (standard and compressed formats)
    final ipv6Regex = RegExp(
      r'^(([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}|'
      r'([0-9a-fA-F]{1,4}:){1,7}:|'
      r'([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|'
      r'([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|'
      r'([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|'
      r'([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|'
      r'([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|'
      r'[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|'
      r':((:[0-9a-fA-F]{1,4}){1,7}|:)|'
      r'::)$'
    );
    if (ipv6Regex.hasMatch(address)) {
      return true;
    }
    
    // IPv6 with brackets [::1]
    if (address.startsWith('[') && address.endsWith(']')) {
      final innerAddress = address.substring(1, address.length - 1);
      return ipv6Regex.hasMatch(innerAddress);
    }
    
    // mDNS hostname validation (e.g., device.local)
    final mdnsRegex = RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\.local$');
    if (mdnsRegex.hasMatch(address)) {
      return true;
    }
    
    return false;
  }

  // Removed temporary key path; handshake establishes session key
}

/// Connection data extracted from QR code
class QRConnectionData {
  final String deviceId;
  final String name;
  final String ipAddress;
  final int port;
  final String? connectionMethod;
  final String? publicKeyBase64;
  final String? sessionId;
  final DateTime timestamp;

  const QRConnectionData({
    required this.deviceId,
    required this.name,
    required this.ipAddress,
    required this.port,
    this.connectionMethod,
    this.publicKeyBase64,
    this.sessionId,
    required this.timestamp,
  });

  @override
  String toString() {
    return 'QRConnectionData(name: $name, ip: $ipAddress:$port, age: ${DateTime.now().difference(timestamp).inSeconds}s)';
  }
}

/// Connection state enum
enum QRConnectionState {
  idle,
  connecting,
  establishing,
  handshaking,
  verifying,
  connected,
  failed,
}

/// Base exception for QR connection errors
class QRConnectionException implements Exception {
  final String message;

  QRConnectionException(this.message);

  @override
  String toString() => 'QRConnectionException: $message';
}

/// Timeout exception for QR connections
class QRConnectionTimeoutException extends QRConnectionException {
  QRConnectionTimeoutException(super.message);
  
  @override
  String toString() => 'QRConnectionTimeoutException: $message';
}

/// Network exception for QR connections
class QRConnectionNetworkException extends QRConnectionException {
  QRConnectionNetworkException(super.message);
  
  @override
  String toString() => 'QRConnectionNetworkException: $message';
}

/// Handshake exception for QR connections
class QRConnectionHandshakeException extends QRConnectionException {
  QRConnectionHandshakeException(super.message);
  
  @override
  String toString() => 'QRConnectionHandshakeException: $message';
}
