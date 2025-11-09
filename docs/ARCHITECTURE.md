# 🏗️ AirLink Architecture Documentation

## Table of Contents
1. [Overview](#overview)
2. [Architecture Layers](#architecture-layers)
3. [Core Components](#core-components)
4. [Service Architecture](#service-architecture)
5. [State Management](#state-management)
6. [Platform Integration](#platform-integration)
7. [Security Architecture](#security-architecture)
8. [Protocol Implementation](#protocol-implementation)
9. [Data Flow](#data-flow)
10. [Error Handling](#error-handling)

---

## Overview

AirLink follows **Clean Architecture** principles with clear separation of concerns across multiple layers. The architecture is designed for:
- **Scalability**: Easy to add new features and services
- **Maintainability**: Clear boundaries between layers
- **Testability**: Each layer can be tested independently
- **Platform Independence**: Core logic is platform-agnostic

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                           │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────────────┐    │
│  │    Pages     │  │   Widgets    │  │  Riverpod         │    │
│  │  (12 pages)  │  │  (20+ comp)  │  │  Providers        │    │
│  │              │  │              │  │  (100+)           │    │
│  └──────────────┘  └──────────────┘  └───────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│              INTEGRATION SERVICE LAYER                          │
│                                                                 │
│       ┌─────────────────────────────────────────┐             │
│       │  ShareitZapyaIntegrationService         │             │
│       │  - Main orchestrator                    │             │
│       │  - Service router                       │             │
│       │  - Transfer method selection            │             │
│       └─────────────────────────────────────────┘             │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    CORE SERVICES LAYER                          │
│                                                                 │
│  ┌────────────────┐  ┌──────────────────┐  ┌───────────────┐  │
│  │ WifiDirect     │  │ OfflineSharing   │  │ PhoneRep      │  │
│  │ Service        │  │ Service          │  │ Service       │  │
│  └────────────────┘  └──────────────────┘  └───────────────┘  │
│                                                                 │
│  ┌────────────────┐  ┌──────────────────┐  ┌───────────────┐  │
│  │ GroupSharing   │  │ EnhancedTransfer │  │ EnhancedCrypto│  │
│  │ Service        │  │ Service          │  │ Service       │  │
│  └────────────────┘  └──────────────────┘  └───────────────┘  │
│                                                                 │
│  ┌────────────────┐  ┌──────────────────┐  ┌───────────────┐  │
│  │ MediaPlayer    │  │ FileManager      │  │ ApkExtractor  │  │
│  │ Service        │  │ Service          │  │ Service       │  │
│  └────────────────┘  └──────────────────┘  └───────────────┘  │
│                                                                 │
│  ┌────────────────┐  ┌──────────────────┐                     │
│  │ CloudSync      │  │ VideoCompression │                     │
│  │ Service        │  │ Service          │                     │
│  └────────────────┘  └──────────────────┘                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    PROTOCOL & SECURITY LAYER                    │
│                                                                 │
│  ┌────────────────────────┐  ┌────────────────────────┐       │
│  │  AirLink Protocol      │  │  Security Module       │       │
│  │  - Frame handling      │  │  - AES-256-GCM         │       │
│  │  - Handshake           │  │  - X25519 key exchange │       │
│  │  - Reliability         │  │  - HKDF derivation     │       │
│  │  - Resume support      │  │  - Session management  │       │
│  └────────────────────────┘  └────────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    PLATFORM LAYER (Native)                      │
│                                                                 │
│  ┌────────────────────────┐  ┌────────────────────────┐       │
│  │  Android (Kotlin)      │  │  iOS (Swift)           │       │
│  │  - Wi-Fi Aware         │  │  - MultipeerConn       │       │
│  │  - Wi-Fi Direct        │  │  - CoreBluetooth       │       │
│  │  - BLE Advertiser      │  │  - Network Framework   │       │
│  │  - Foreground Service  │  │  - Background Tasks    │       │
│  │  - MethodChannel       │  │  - MethodChannel       │       │
│  │  - EventChannel        │  │  - EventChannel        │       │
│  └────────────────────────┘  └────────────────────────┘       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Architecture Layers

### 1. Presentation Layer

The presentation layer handles all UI-related code and user interactions.

#### Components:

**Pages** (`lib/features/*/presentation/pages/`)
- **HomePage** - Dashboard with device discovery
- **SendPickerPage** - File selection interface
- **ReceivePage** - Receiving mode interface
- **MediaPlayerPage** - Media playback interface
- **FileManagerPage** - File browsing and management
- **ApkSharingPage** - APK sharing interface
- **CloudSyncPage** - Cloud integration interface
- **VideoCompressionPage** - Video compression interface
- **PhoneReplicationPage** - Device cloning interface
- **GroupSharingPage** - Multi-device sharing interface
- **SettingsPage** - App configuration
- **TransferHistoryPage** - Transfer history

**Widgets** (`lib/shared/widgets/`)
- Device discovery widgets
- Transfer progress components
- Media player controls
- File management components
- Cloud sync UI components

**Providers** (`lib/shared/providers/`)
- 100+ Riverpod providers
- State management
- Service access layer

### 2. Integration Service Layer

**Main Component**: `ShareitZapyaIntegrationService`

This layer acts as the main orchestrator, routing requests to appropriate services.

```dart
class ShareitZapyaIntegrationService {
  // Responsibilities:
  // 1. Transfer method selection (Wi-Fi Direct, BLE, etc.)
  // 2. Service orchestration
  // 3. Event aggregation
  // 4. Error handling coordination
  
  Future<String> startTransfer({
    required String targetDeviceId,
    required List<TransferFile> files,
    TransferMethod method = TransferMethod.wifiDirect,
  }) async {
    // Route to appropriate service
  }
}
```

### 3. Core Services Layer

#### Core Transfer Services

1. **WifiDirectService**
   - High-speed P2P transfers
   - Wi-Fi Aware (Android) / MultipeerConnectivity (iOS)
   - Direct device-to-device connection

2. **OfflineSharingService**
   - Hotspot-based sharing
   - Bluetooth LE transfers
   - Fallback mechanism

3. **PhoneReplicationService**
   - Complete device data cloning
   - Selective data transfer
   - Progress tracking

4. **GroupSharingService**
   - Multi-device broadcasting
   - Peer-to-peer mesh
   - Concurrent transfers

5. **EnhancedTransferService**
   - Adaptive transfer algorithms
   - Speed optimization
   - Network condition monitoring

6. **EnhancedCryptoService**
   - End-to-end encryption
   - Key management
   - Secure channels

#### Advanced Feature Services

7. **MediaPlayerService**
   - Video playback
   - Audio playback
   - Image viewing
   - Playlist management

8. **FileManagerService**
   - File operations (copy, move, delete, rename)
   - Search and filtering
   - Storage analysis
   - Duplicate detection

9. **ApkExtractorService**
   - APK extraction from installed apps
   - APK installation
   - App information retrieval
   - Batch operations

10. **CloudSyncService**
    - Google Drive integration
    - Dropbox integration
    - OneDrive integration
    - iCloud integration
    - Two-way sync
    - Conflict resolution

11. **VideoCompressionService**
    - Video compression
    - Multiple presets (fast, balanced, best)
    - Custom settings
    - Batch compression

### 4. Protocol & Security Layer

#### AirLink Protocol (`lib/core/protocol/`)

- **Frame Handling** - Packet framing and parsing
- **Handshake** - Connection establishment
- **Reliability** - ACK/NACK, retransmission
- **Resume Support** - Transfer resumption database

#### Security Module (`lib/core/security/`)

- **Crypto** - AES-256-GCM encryption/decryption
- **Key Manager** - Key generation, storage, derivation
- **Secure Session** - Session lifecycle management

### 5. Platform Layer

#### Android (`android/app/src/main/kotlin/`)

- **AirLinkPlugin.kt** - Main plugin implementation
- **WifiAwareManagerWrapper.kt** - Wi-Fi Aware support
- **BleAdvertiser.kt** - Bluetooth LE advertising
- **TransferForegroundService.kt** - Background transfers

#### iOS (`ios/Runner/`)

- **AirLinkPlugin.swift** - Main plugin implementation
- MultipeerConnectivity integration
- CoreBluetooth support
- Background task support

---

## Core Components

### Dependency Injection

**Location**: `lib/core/services/dependency_injection.dart`

```dart
@InjectableInit(
  initializerName: r'$initGetIt',
  preferRelativeImports: true,
  asExtension: false,
)
void configureDependencies() => $initGetIt(getIt);

// Services are registered as singletons
@singleton
class WifiDirectService { }

@singleton
class MediaPlayerService { }
```

### Channel Factory

**Location**: `lib/core/services/channel_factory.dart`

```dart
// Namespaced method channels for service isolation
class NamespacedMethodChannel {
  final String _serviceName;
  final MethodChannel _underlying;
  
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) {
    final namespacedMethod = '$_serviceName.$method';
    return _underlying.invokeMethod<T>(namespacedMethod, arguments);
  }
}

// Filtered event channels for selective event streams
class FilteredEventChannel {
  Stream<Map<String, dynamic>> get stream {
    return _underlying
        .receiveBroadcastStream()
        .map((event) => Map<String, dynamic>.from(event))
        .where((event) => event['service'] == _serviceName);
  }
}
```

---

## Service Architecture

### Service Pattern

Each service follows a consistent pattern:

```dart
@singleton
class ExampleService {
  // Platform channels
  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  
  // Event stream
  final StreamController<ServiceEvent> _eventController;
  Stream<ServiceEvent> get events => _eventController.stream;
  
  // Constructor with channel factory
  ExampleService(ChannelFactory factory)
      : _methodChannel = factory.createMethodChannel('example'),
        _eventChannel = factory.createEventChannel('exampleEvents');
  
  // Public API methods
  Future<Result> performAction() async {
    try {
      final result = await _methodChannel.invokeMethod('action');
      return Result.success(result);
    } catch (e) {
      return Result.error(e);
    }
  }
  
  // Disposal
  void dispose() {
    _eventController.close();
  }
}
```

### Service Communication

Services communicate through:
1. **Direct method calls** - For synchronous operations
2. **Event streams** - For asynchronous updates
3. **Providers** - For UI integration

---

## State Management

### Riverpod Architecture

**Provider Types Used:**

1. **Provider** - For service instances
```dart
final exampleServiceProvider = Provider<ExampleService>((ref) {
  return getIt<ExampleService>();
});
```

2. **StateProvider** - For mutable state
```dart
final selectedFilesProvider = StateProvider<List<File>>((ref) => []);
```

3. **FutureProvider** - For async operations
```dart
final deviceListProvider = FutureProvider<List<Device>>((ref) async {
  final service = ref.watch(discoveryServiceProvider);
  return await service.discoverDevices();
});
```

4. **StreamProvider** - For real-time updates
```dart
final transferProgressProvider = StreamProvider.family<Progress, String>((ref, id) {
  final service = ref.watch(transferServiceProvider);
  return service.getProgressStream(id);
});
```

5. **StateNotifierProvider** - For complex state
```dart
final discoveryControllerProvider = 
    StateNotifierProvider<DiscoveryController, DiscoveryState>((ref) {
  return DiscoveryController(ref.watch(repositoryProvider));
});
```

---

## Platform Integration

### Method Channel Communication

**Flutter → Native:**
```dart
// Dart side
final result = await methodChannel.invokeMethod('startDiscovery', {
  'timeout': 30000,
  'mode': 'active',
});
```

```kotlin
// Android side
override fun onMethodCall(call: MethodCall, result: Result) {
  when (call.method) {
    "startDiscovery" -> {
      val timeout = call.argument<Int>("timeout") ?: 30000
      val mode = call.argument<String>("mode") ?: "active"
      startDiscovery(timeout, mode, result)
    }
  }
}
```

```swift
// iOS side
public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
  switch call.method {
  case "startDiscovery":
    let args = call.arguments as? [String: Any]
    let timeout = args?["timeout"] as? Int ?? 30000
    let mode = args?["mode"] as? String ?? "active"
    startDiscovery(timeout: timeout, mode: mode, result: result)
  default:
    result(FlutterMethodNotImplemented)
  }
}
```

### Event Channel Communication

**Native → Flutter:**
```kotlin
// Android side
eventSink?.success(mapOf(
  "type" to "deviceDiscovered",
  "deviceId" to device.id,
  "deviceName" to device.name,
  "timestamp" to System.currentTimeMillis()
))
```

```dart
// Dart side
eventChannel.receiveBroadcastStream().listen((event) {
  if (event['type'] == 'deviceDiscovered') {
    final device = Device.fromMap(event);
    _handleDeviceDiscovered(device);
  }
});
```

---

## Security Architecture

### Encryption Flow

```
┌─────────────┐
│   Sender    │
└──────┬──────┘
       │
       │ 1. Generate ephemeral key pair
       ↓
┌──────────────────┐
│  X25519 KeyGen   │
└──────┬───────────┘
       │
       │ 2. Exchange public keys
       ↓
┌──────────────────┐
│  Key Exchange    │
└──────┬───────────┘
       │
       │ ←───────→ │  Receiver  │
       │
       │
       │ 3. Compute shared secret
       ↓
┌──────────────────┐
│ ECDH Shared Key  │
└──────┬───────────┘
       │
       │ 4. Derive symmetric key
       ↓
┌──────────────────┐
│   HKDF (SHA256)  │
└──────┬───────────┘
       │
       │ 5. Encrypt file chunks
       ↓
┌──────────────────┐
│  AES-256-GCM     │
│  - Confidentiality
│  - Authentication
│  - Integrity
└──────┬───────────┘
       │
       │ 6. Send encrypted chunks
       ↓
┌──────────────────┐
│   Transfer       │
└──────────────────┘
```

### Session Management

```dart
class SecureSession {
  final String sessionId;
  final String deviceId;
  final KeyPair localKeyPair;
  Uint8List? remotePublicKey;
  bool isHandshakeComplete = false;
  
  // Encrypt data
  Future<AesGcmResult> encrypt(Uint8List data, Uint8List aad);
  
  // Decrypt data
  Future<Uint8List> decrypt(AesGcmResult encrypted, Uint8List aad);
  
  // Hash data
  Future<Uint8List> hash(Uint8List data);
}
```

---

## Protocol Implementation

### AirLinkProtocol Concurrency Approach

The AirLinkProtocol provides enhanced concurrency features for managing multiple transfer sessions, but the current implementation in `TransferRepositoryImpl` uses direct native transport APIs rather than the protocol abstraction. This design decision was made for the following reasons:

#### Current Architecture Decision

**Direct Native Transport Usage** (Current Implementation):
- `TransferRepositoryImpl` directly calls `AirLinkPlugin` methods
- Avoids duplication of connection state management
- Maintains direct control over native transport operations
- Simplifies architecture with one source of truth for connections

**Benefits:**
- Reduced complexity in connection management
- Direct access to native transport features
- Simplified debugging and error handling
- Better performance due to fewer abstraction layers

#### AirLinkProtocol Usage

The `AirLinkProtocol` is available for future use in complex scenarios where:
- Advanced session orchestration is needed
- Complex retry/fallback logic is required
- Multi-session coordination is necessary
- Protocol-level features like frame sequencing are needed

#### Implementation Notes

```dart
// Current approach in TransferRepositoryImpl
class TransferRepositoryImpl implements TransferRepository {
  // Direct native transport calls
  final success = await AirLinkPlugin.startTransfer(transferId, files);
  
  // Protocol available for complex scenarios
  // final protocol = getIt<AirLinkProtocol>();
  // await protocol.startSession(sessionId, files);
}
```

#### Future Considerations

If protocol-level orchestration becomes necessary, the architecture can be updated to:
1. Use `AirLinkProtocol` as the main orchestrator
2. Wrap `TransportAdapter`/`AirLinkPlugin` calls within the protocol
3. Implement advanced concurrency features like session queuing
4. Add protocol-level retry and fallback mechanisms

### Frame Structure

```
┌────────────────────────────────────────┐
│         AirLink Protocol Frame         │
├────────────────────────────────────────┤
│  Header (32 bytes)                     │
│  - Magic Number (4 bytes): 0xA1RL     │
│  - Version (2 bytes)                   │
│  - Frame Type (2 bytes)                │
│  - Flags (2 bytes)                     │
│  - Sequence Number (4 bytes)           │
│  - Chunk Index (4 bytes)               │
│  - Total Chunks (4 bytes)              │
│  - Payload Length (4 bytes)            │
│  - Checksum (4 bytes)                  │
│  - Reserved (2 bytes)                  │
├────────────────────────────────────────┤
│  Payload (variable size)               │
│  - Max: 262,144 bytes (256 KB)        │
├────────────────────────────────────────┤
│  Footer (optional)                     │
│  - Hash (32 bytes - SHA256)           │
└────────────────────────────────────────┘
```

### Transfer States

```
IDLE → HANDSHAKE → TRANSFERRING → COMPLETED
  ↓       ↓            ↓             ↓
ERROR ← ERROR ←──── ERROR ←──────── ERROR
  ↓                   ↓
RETRY              RESUME
```

---

## Data Flow

### File Transfer Flow

```
User Selects Files
       ↓
UI (SendPickerPage)
       ↓
Provider (selectedFilesProvider)
       ↓
Controller (TransferController)
       ↓
Integration Service (ShareitZapyaIntegrationService)
       ↓
Core Service (WifiDirectService)
       ↓
Protocol Layer (AirLinkProtocol)
       ↓
Security Layer (Encryption)
       ↓
Platform Channel (MethodChannel)
       ↓
Native Code (Android/iOS)
       ↓
Network Stack (Wi-Fi/BLE)
       ↓
Receiver Device
```

### Event Flow

```
Native Event (Device Discovered)
       ↓
EventChannel Stream
       ↓
Service Event Controller
       ↓
Provider Stream
       ↓
Consumer Widget
       ↓
UI Update
```

---

## Error Handling

### Error Hierarchy

```
AirLinkException
├── NetworkException
│   ├── ConnectionException
│   ├── TimeoutException
│   └── TransferException
├── SecurityException
│   ├── EncryptionException
│   ├── KeyExchangeException
│   └── AuthenticationException
├── PlatformException
│   ├── PermissionException
│   ├── UnsupportedPlatformException
│   └── NativeException
└── ValidationException
    ├── InvalidFileException
    ├── InvalidDeviceException
    └── InvalidParameterException
```

### Error Handling Pattern

```dart
// Service level
try {
  final result = await _performOperation();
  return Result.success(result);
} on NetworkException catch (e) {
  return Result.error(e, ErrorSeverity.high);
} on SecurityException catch (e) {
  return Result.error(e, ErrorSeverity.critical);
} catch (e) {
  return Result.error(UnknownException(e), ErrorSeverity.medium);
}

// UI level
ref.watch(operationProvider).when(
  data: (result) => SuccessWidget(result),
  loading: () => LoadingWidget(),
  error: (error, stack) => ErrorWidget(error),
);
```

---

## Best Practices

### 1. Service Implementation
- Always use dependency injection
- Implement proper disposal
- Use event streams for async updates
- Handle errors gracefully

### 2. State Management
- Use appropriate provider types
- Keep providers focused and single-purpose
- Use `.family` for parameterized providers
- Dispose of providers when not needed

### 3. Platform Integration
- Namespace all method calls
- Filter event streams appropriately
- Handle platform errors
- Test on both platforms

### 4. Security
- Use secure sessions for all transfers
- Implement proper key lifecycle
- Never store sensitive data unencrypted
- Validate all inputs

### 5. Testing
- Unit test all services
- Integration test data flow
- Widget test UI components
- Platform test native code

---

## Future Enhancements

1. **Desktop Support** - macOS, Windows, Linux
2. **Web Support** - WebRTC-based transfers
3. **Cloud Relay** - For NAT traversal
4. **Advanced Compression** - Adaptive compression algorithms
5. **Video Streaming** - Real-time media streaming
6. **Chat Integration** - Messaging during transfers
7. **File Versioning** - Track file versions
8. **Collaboration Tools** - Multi-user editing

---

**Last Updated**: October 2025  
**Version**: 1.0.0  
**Status**: Production Ready

