import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'dependency_injection.config.dart';
import 'channel_factory.dart';
import 'device_id_service.dart';
import 'connection_service.dart';
import 'rate_limiting_service.dart';
import 'error_handling_service.dart';
import 'performance_optimization_service.dart';
import 'logger_service.dart';
import 'crypto_service.dart';
import 'permission_service.dart';
import 'file_manager_service.dart';
import 'device_service.dart';
import 'discovery_strategy_service.dart';
import 'enhanced_crypto_service.dart';
import 'enhanced_transfer_service.dart';
import 'apk_extractor_service.dart';
import 'cloud_sync_service.dart';
import 'group_sharing_service.dart';
import 'media_player_service.dart';
import 'offline_sharing_service.dart';
import 'phone_replication_service.dart';
import 'platform_detection_service.dart';
import 'shareit_zapya_integration_service.dart';
import 'transfer_strategy_service.dart';
import 'video_compression_service.dart';
import 'wifi_direct_service.dart';
import '../protocol/airlink_protocol_simplified.dart';
import '../protocol/airlink_protocol.dart';
import '../security/secure_session.dart';
import '../../features/transfer/domain/repositories/transfer_repository.dart';
import '../../features/transfer/data/repositories/transfer_repository_impl.dart';
import '../../features/discovery/domain/repositories/discovery_repository.dart';
import '../../features/discovery/data/repositories/discovery_repository_impl.dart';
import '../protocol/socket_manager.dart';
import 'transfer_benchmarking_service.dart';
import 'airlink_plugin.dart';
import 'checksum_verification_service.dart';
import 'audit_service.dart';

final GetIt getIt = GetIt.instance;

@InjectableInit(
  initializerName: r'$initGetIt', // default
  preferRelativeImports: true, // default
  asExtension: false, // default
)
Future<void> configureDependencies() async {
  // Initialize SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  getIt.registerSingleton<SharedPreferences>(prefs);
  
  // Initialize FlutterSecureStorage
  const secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  getIt.registerSingleton<FlutterSecureStorage>(secureStorage);
  
  // Register core platform channels (for backwards compatibility)
  getIt.registerSingleton<MethodChannel>(
    ChannelFactory.coreMethodChannel,
    instanceName: 'airlink/core',
  );
  
  getIt.registerSingleton<EventChannel>(
    ChannelFactory.coreEventChannel,
    instanceName: 'airlink/events',
  );
  
  // Register named channels for each service using ChannelFactory
  // All these channels multiplex through the core channel with method name prefixes
  
  // Wi-Fi Direct channels
  getIt.registerFactory<NamespacedMethodChannel>(
    () => ChannelFactory.createMethodChannel('wifiDirect'),
    instanceName: 'wifiDirect',
  );
  getIt.registerFactory<FilteredEventChannel>(
    () => ChannelFactory.createEventChannel('wifiDirect'),
    instanceName: 'wifiDirectEvents',
  );
  
  // Offline Sharing channels
  getIt.registerFactory<NamespacedMethodChannel>(
    () => ChannelFactory.createMethodChannel('offlineSharing'),
    instanceName: 'offlineSharing',
  );
  getIt.registerFactory<FilteredEventChannel>(
    () => ChannelFactory.createEventChannel('offlineSharing'),
    instanceName: 'offlineSharingEvents',
  );
  
  // Phone Replication channels
  getIt.registerFactory<NamespacedMethodChannel>(
    () => ChannelFactory.createMethodChannel('phoneReplication'),
    instanceName: 'phoneReplication',
  );
  getIt.registerFactory<FilteredEventChannel>(
    () => ChannelFactory.createEventChannel('phoneReplication'),
    instanceName: 'phoneReplicationEvents',
  );
  
  // Media Player channels
  getIt.registerFactory<NamespacedMethodChannel>(
    () => ChannelFactory.createMethodChannel('mediaPlayer'),
    instanceName: 'mediaPlayer',
  );
  getIt.registerFactory<FilteredEventChannel>(
    () => ChannelFactory.createEventChannel('mediaPlayer'),
    instanceName: 'mediaPlayerEvents',
  );
  
  // APK Extractor channels
  getIt.registerFactory<NamespacedMethodChannel>(
    () => ChannelFactory.createMethodChannel('apkExtractor'),
    instanceName: 'apkExtractor',
  );
  getIt.registerFactory<FilteredEventChannel>(
    () => ChannelFactory.createEventChannel('apkExtractor'),
    instanceName: 'apkExtractorEvents',
  );
  
  // Group Sharing channels
  getIt.registerFactory<NamespacedMethodChannel>(
    () => ChannelFactory.createMethodChannel('groupSharing'),
    instanceName: 'groupSharing',
  );
  getIt.registerFactory<FilteredEventChannel>(
    () => ChannelFactory.createEventChannel('groupSharing'),
    instanceName: 'groupSharingEvents',
  );
  
  // Cloud Sync channels
  getIt.registerFactory<NamespacedMethodChannel>(
    () => ChannelFactory.createMethodChannel('cloudSync'),
    instanceName: 'cloudSync',
  );
  getIt.registerFactory<FilteredEventChannel>(
    () => ChannelFactory.createEventChannel('cloudSync'),
    instanceName: 'cloudSyncEvents',
  );
  
  // Video Compression channels
  getIt.registerFactory<NamespacedMethodChannel>(
    () => ChannelFactory.createMethodChannel('videoCompression'),
    instanceName: 'videoCompression',
  );
  getIt.registerFactory<FilteredEventChannel>(
    () => ChannelFactory.createEventChannel('videoCompression'),
    instanceName: 'videoCompressionEvents',
  );
  
  // Discovery channels
  getIt.registerFactory<NamespacedMethodChannel>(
    () => ChannelFactory.createMethodChannel('discovery'),
    instanceName: 'discovery',
  );
  getIt.registerFactory<FilteredEventChannel>(
    () => ChannelFactory.createEventChannel('discovery'),
    instanceName: 'discoveryEvents',
  );
  
  // Enhanced Services
  getIt.registerLazySingleton<ErrorHandlingService>(
    () => ErrorHandlingService(),
  );
  
  getIt.registerLazySingleton<PerformanceOptimizationService>(
    () => PerformanceOptimizationService(),
  );

  // Benchmarking service
  getIt.registerSingleton<TransferBenchmarkingService>(
    TransferBenchmarkingService()..initialize()..scheduleCleanup(),
  );
  
  getIt.registerLazySingleton<LoggerService>(
    () => LoggerService(),
  );
  
  getIt.registerLazySingleton<CryptoService>(
    () => CryptoService(),
  );
  
  getIt.registerLazySingleton<PermissionService>(
    () => PermissionService(),
  );
  
  getIt.registerLazySingleton<FileManagerService>(
    () => FileManagerService(logger: getIt<LoggerService>()),
  );
  
  getIt.registerLazySingleton<DeviceService>(
    () => DeviceService(loggerService: getIt<LoggerService>()),
  );
  
  getIt.registerLazySingleton<DiscoveryStrategyService>(
    () => DiscoveryStrategyService(
      loggerService: getIt<LoggerService>(),
      platformDetectionService: getIt<PlatformDetectionService>(),
      connectionService: getIt<ConnectionService>(),
    ),
  );
  
  getIt.registerLazySingleton<EnhancedCryptoService>(
    () => EnhancedCryptoService(logger: getIt<LoggerService>()),
  );
  
  getIt.registerLazySingleton<EnhancedTransferService>(
    () => EnhancedTransferService(
      logger: getIt<LoggerService>(),
      cryptoService: getIt<EnhancedCryptoService>(),
      wifiDirectService: getIt<WifiDirectService>(),
      offlineSharingService: getIt<OfflineSharingService>(),
      protocol: getIt<AirLinkProtocolSimplified>(),
    ),
  );
  
  getIt.registerLazySingleton<ApkExtractorService>(
    () => ApkExtractorService(
      logger: getIt<LoggerService>(),
      methodChannel: ChannelFactory.coreMethodChannel,
      eventChannel: ChannelFactory.coreEventChannel,
    ),
  );
  
  getIt.registerLazySingleton<CloudSyncService>(
    () => CloudSyncService(
      logger: getIt<LoggerService>(),
      methodChannel: ChannelFactory.coreMethodChannel,
      eventChannel: ChannelFactory.coreEventChannel,
    ),
  );
  
  getIt.registerLazySingleton<GroupSharingService>(
    () => GroupSharingService(
      logger: getIt<LoggerService>(),
      methodChannel: ChannelFactory.coreMethodChannel,
      eventChannel: ChannelFactory.coreEventChannel,
    ),
  );
  
  getIt.registerLazySingleton<MediaPlayerService>(
    () => MediaPlayerService(
      logger: getIt<LoggerService>(),
      methodChannel: ChannelFactory.coreMethodChannel,
      eventChannel: ChannelFactory.coreEventChannel,
    ),
  );
  
  getIt.registerLazySingleton<OfflineSharingService>(
    () => OfflineSharingService(
      logger: getIt<LoggerService>(),
      methodChannel: ChannelFactory.coreMethodChannel,
      eventChannel: ChannelFactory.coreEventChannel,
    ),
  );
  
  getIt.registerLazySingleton<PhoneReplicationService>(
    () => PhoneReplicationService(
      logger: getIt<LoggerService>(),
      methodChannel: ChannelFactory.coreMethodChannel,
      eventChannel: ChannelFactory.coreEventChannel,
    ),
  );
  
  getIt.registerLazySingleton<PlatformDetectionService>(
    () => PlatformDetectionService(getIt<LoggerService>()),
  );
  
  getIt.registerLazySingleton<ShareitZapyaIntegrationService>(
    () => ShareitZapyaIntegrationService(
      logger: getIt<LoggerService>(),
      transferService: getIt<EnhancedTransferService>(),
      wifiDirectService: getIt<WifiDirectService>(),
      offlineSharingService: getIt<OfflineSharingService>(),
      phoneReplicationService: getIt<PhoneReplicationService>(),
      groupSharingService: getIt<GroupSharingService>(),
    ),
  );
  
  getIt.registerLazySingleton<TransferStrategyService>(
    () => TransferStrategyService(
      loggerService: getIt<LoggerService>(),
      cryptoService: getIt<CryptoService>(),
    ),
  );
  
  getIt.registerLazySingleton<VideoCompressionService>(
    () => VideoCompressionService(
      logger: getIt<LoggerService>(),
      methodChannel: ChannelFactory.coreMethodChannel,
      eventChannel: ChannelFactory.coreEventChannel,
    ),
  );
  
  getIt.registerLazySingleton<WifiDirectService>(
    () => WifiDirectService(
      logger: getIt<LoggerService>(),
      methodChannel: ChannelFactory.coreMethodChannel,
      eventChannel: ChannelFactory.coreEventChannel,
    ),
  );
  
  getIt.registerLazySingleton<AirLinkProtocolSimplified>(
    () => AirLinkProtocolSimplified(
      deviceId: 'airlink_device',
      capabilities: const {
        'maxChunkSize': 1024 * 1024,
        'supportsResume': true,
        'encryption': 'AES-GCM',
      },
    ),
  );
  
  getIt.registerLazySingleton<AirLinkProtocol>(
    () => AirLinkProtocol(
      deviceId: 'airlink_device',
      capabilities: const {
        'maxChunkSize': 1024 * 1024,
        'supportsResume': true,
        'encryption': 'AES-GCM',
      },
    ),
  );
  
  getIt.registerLazySingleton<SecureSessionManager>(
    () => SecureSessionManager(),
  );
  
  // Audit Services
  getIt.registerLazySingleton<ChecksumVerificationService>(
    () => ChecksumVerificationService(getIt<LoggerService>()),
  );
  
  // Initialize ChecksumVerificationService database
  await getIt<ChecksumVerificationService>().initialize();
  
  getIt.registerLazySingleton<AuditService>(
    () => AuditService(getIt<LoggerService>(), getIt<ChecksumVerificationService>()),
  );
  
  // Repository Services
  getIt.registerLazySingleton<TransferRepository>(
    () => TransferRepositoryImpl(
      loggerService: getIt<LoggerService>(),
      connectionService: getIt<ConnectionService>(),
      errorHandlingService: getIt<ErrorHandlingService>(),
      performanceService: getIt<PerformanceOptimizationService>(),
      benchmarkingService: getIt<TransferBenchmarkingService>(),
      airLinkProtocol: getIt<AirLinkProtocol>(),
      rateLimitingService: getIt<RateLimitingService>(),
      secureSessionManager: getIt<SecureSessionManager>(),
      checksumService: getIt<ChecksumVerificationService>(),
    ),
  );
  
  getIt.registerLazySingleton<DiscoveryRepository>(
    () => DiscoveryRepositoryImpl(
      loggerService: getIt<LoggerService>(),
      permissionService: getIt<PermissionService>(),
      discoveryStrategyService: getIt<DiscoveryStrategyService>(),
    ),
  );
  
  // Core Services
  getIt.registerLazySingleton<DeviceIdService>(
    () => DeviceIdService(),
  );
  
  getIt.registerLazySingleton<ConnectionService>(
    () => ConnectionService(
      getIt<FlutterSecureStorage>(),
      getIt<SharedPreferences>(),
    ),
  );
  
  getIt.registerLazySingleton<RateLimitingService>(
    () => RateLimitingService(),
  );

  // Register SocketManager factory with required dependencies
  getIt.registerFactory<SocketManager>(
    () => SocketManager(
      deviceId: 'airlink_device', // Will be replaced with actual device ID
      capabilities: {
        'maxChunkSize': 1024 * 1024, // 1MB default
        'supportsResume': true,
        'encryption': 'AES-GCM',
      },
      rateLimitingService: getIt<RateLimitingService>(),
    ),
  );
  
  // Transfer channels
  getIt.registerFactory<NamespacedMethodChannel>(
    () => ChannelFactory.createMethodChannel('transfer'),
    instanceName: 'transfer',
  );
  getIt.registerFactory<FilteredEventChannel>(
    () => ChannelFactory.createEventChannel('transfer'),
    instanceName: 'transferEvents',
  );
  
  // Initialize auto-generated dependencies
  $initGetIt(getIt);
  
  // Initialize AirLinkPlugin with DI-provided channels
  AirLinkPlugin.initializeWithChannels(
    channel: getIt<MethodChannel>(instanceName: 'airlink/core'),
    eventChannel: getIt<EventChannel>(instanceName: 'airlink/events'),
    wifiAwareDataChannel: const EventChannel('airlink/wifi_aware_data'),
  );
}
