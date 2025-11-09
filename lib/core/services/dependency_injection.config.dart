// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// InjectableConfigGenerator
// **************************************************************************

// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:flutter/services.dart' as _i281;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i558;
import 'package:get_it/get_it.dart' as _i174;
import 'package:injectable/injectable.dart' as _i526;
import 'package:shared_preferences/shared_preferences.dart' as _i460;

import '../../features/discovery/data/repositories/discovery_repository_impl.dart'
    as _i366;
import '../../features/discovery/domain/repositories/discovery_repository.dart'
    as _i949;
import '../../features/transfer/data/repositories/transfer_repository_impl.dart'
    as _i847;
import '../../features/transfer/domain/repositories/transfer_repository.dart'
    as _i336;
import '../protocol/airlink_protocol.dart' as _i618;
import '../protocol/airlink_protocol_simplified.dart' as _i866;
import '../security/secure_session.dart' as _i901;
import 'apk_extractor_service.dart' as _i19;
import 'checksum_verification_service.dart' as _i222;
import 'cloud_sync_service.dart' as _i270;
import 'connection_service.dart' as _i686;
import 'crypto_service.dart' as _i157;
import 'device_id_service.dart' as _i326;
import 'device_service.dart' as _i510;
import 'discovery_strategy_service.dart' as _i206;
import 'enhanced_crypto_service.dart' as _i964;
import 'enhanced_transfer_service.dart' as _i155;
import 'error_handling_service.dart' as _i646;
import 'file_manager_service.dart' as _i187;
import 'group_sharing_service.dart' as _i122;
import 'logger_service.dart' as _i464;
import 'media_player_service.dart' as _i966;
import 'offline_sharing_service.dart' as _i133;
import 'performance_optimization_service.dart' as _i702;
import 'permission_service.dart' as _i886;
import 'phone_replication_service.dart' as _i751;
import 'platform_detection_service.dart' as _i811;
import 'rate_limiting_service.dart' as _i633;
import 'settings_service.dart' as _i115;
import 'shareit_zapya_integration_service.dart' as _i1002;
import 'transfer_benchmarking_service.dart' as _i639;
import 'transfer_strategy_service.dart' as _i322;
import 'video_compression_service.dart' as _i628;
import 'wifi_direct_service.dart' as _i675;

// initializes the registration of main-scope dependencies inside of GetIt
_i174.GetIt $initGetIt(
  _i174.GetIt getIt, {
  String? environment,
  _i526.EnvironmentFilter? environmentFilter,
}) {
  final gh = _i526.GetItHelper(
    getIt,
    environment,
    environmentFilter,
  );
  gh.factory<_i886.PermissionService>(() => _i886.PermissionService());
  gh.factory<_i157.CryptoService>(() => _i157.CryptoService());
  gh.factory<_i633.RateLimitingService>(() => _i633.RateLimitingService());
  gh.factory<_i326.DeviceIdService>(() => _i326.DeviceIdService());
  gh.factory<_i702.PerformanceOptimizationService>(
      () => _i702.PerformanceOptimizationService());
  gh.factory<_i639.TransferBenchmarkingService>(
      () => _i639.TransferBenchmarkingService());
  gh.factory<_i464.LoggerService>(() => _i464.LoggerService());
  gh.factory<_i646.ErrorHandlingService>(() => _i646.ErrorHandlingService());
  gh.factory<_i675.WifiDirectService>(() => _i675.WifiDirectService(
        logger: gh<_i464.LoggerService>(),
        methodChannel: gh<_i281.MethodChannel>(instanceName: 'wifiDirect'),
        eventChannel: gh<_i281.EventChannel>(instanceName: 'wifiDirectEvents'),
      ));
  gh.factory<_i510.DeviceService>(
      () => _i510.DeviceService(loggerService: gh<_i464.LoggerService>()));
  gh.factory<_i322.TransferStrategyService>(() => _i322.TransferStrategyService(
        loggerService: gh<_i464.LoggerService>(),
        cryptoService: gh<_i157.CryptoService>(),
      ));
  gh.factory<_i133.OfflineSharingService>(() => _i133.OfflineSharingService(
        logger: gh<_i464.LoggerService>(),
        methodChannel: gh<_i281.MethodChannel>(instanceName: 'offlineSharing'),
        eventChannel:
            gh<_i281.EventChannel>(instanceName: 'offlineSharingEvents'),
      ));
  gh.factory<_i686.ConnectionService>(() => _i686.ConnectionService(
        gh<_i558.FlutterSecureStorage>(),
        gh<_i460.SharedPreferences>(),
      ));
  gh.factory<_i751.PhoneReplicationService>(() => _i751.PhoneReplicationService(
        logger: gh<_i464.LoggerService>(),
        methodChannel:
            gh<_i281.MethodChannel>(instanceName: 'phoneReplication'),
        eventChannel:
            gh<_i281.EventChannel>(instanceName: 'phoneReplicationEvents'),
      ));
  gh.factory<_i966.MediaPlayerService>(() => _i966.MediaPlayerService(
        logger: gh<_i464.LoggerService>(),
        methodChannel: gh<_i281.MethodChannel>(instanceName: 'mediaPlayer'),
        eventChannel: gh<_i281.EventChannel>(instanceName: 'mediaPlayerEvents'),
      ));
  gh.factory<_i628.VideoCompressionService>(() => _i628.VideoCompressionService(
        logger: gh<_i464.LoggerService>(),
        methodChannel:
            gh<_i281.MethodChannel>(instanceName: 'videoCompression'),
        eventChannel:
            gh<_i281.EventChannel>(instanceName: 'videoCompressionEvents'),
      ));
  gh.factory<_i270.CloudSyncService>(() => _i270.CloudSyncService(
        logger: gh<_i464.LoggerService>(),
        methodChannel: gh<_i281.MethodChannel>(instanceName: 'cloudSync'),
        eventChannel: gh<_i281.EventChannel>(instanceName: 'cloudSyncEvents'),
      ));
  gh.factory<_i222.ChecksumVerificationService>(
      () => _i222.ChecksumVerificationService(gh<_i464.LoggerService>()));
  gh.factory<_i115.SettingsService>(() => _i115.SettingsService(
        logger: gh<_i464.LoggerService>(),
        prefs: gh<_i460.SharedPreferences>(),
        secureStorage: gh<_i558.FlutterSecureStorage>(),
      ));
  gh.factory<_i964.EnhancedCryptoService>(
      () => _i964.EnhancedCryptoService(logger: gh<_i464.LoggerService>()));
  gh.factory<_i187.FileManagerService>(
      () => _i187.FileManagerService(logger: gh<_i464.LoggerService>()));
  gh.factory<_i19.ApkExtractorService>(() => _i19.ApkExtractorService(
        logger: gh<_i464.LoggerService>(),
        methodChannel: gh<_i281.MethodChannel>(instanceName: 'apkExtractor'),
        eventChannel:
            gh<_i281.EventChannel>(instanceName: 'apkExtractorEvents'),
      ));
  gh.factory<_i122.GroupSharingService>(() => _i122.GroupSharingService(
        logger: gh<_i464.LoggerService>(),
        methodChannel: gh<_i281.MethodChannel>(instanceName: 'groupSharing'),
        eventChannel:
            gh<_i281.EventChannel>(instanceName: 'groupSharingEvents'),
      ));
  gh.factory<_i811.PlatformDetectionService>(
      () => _i811.PlatformDetectionService(gh<_i464.LoggerService>()));
  gh.factory<_i155.EnhancedTransferService>(() => _i155.EnhancedTransferService(
        logger: gh<_i464.LoggerService>(),
        cryptoService: gh<_i964.EnhancedCryptoService>(),
        wifiDirectService: gh<_i675.WifiDirectService>(),
        offlineSharingService: gh<_i133.OfflineSharingService>(),
        protocol: gh<_i866.AirLinkProtocolSimplified>(),
      ));
  gh.factory<_i336.TransferRepository>(() => _i847.TransferRepositoryImpl(
        loggerService: gh<_i464.LoggerService>(),
        connectionService: gh<_i686.ConnectionService>(),
        errorHandlingService: gh<_i646.ErrorHandlingService>(),
        performanceService: gh<_i702.PerformanceOptimizationService>(),
        benchmarkingService: gh<_i639.TransferBenchmarkingService>(),
        checksumService: gh<_i222.ChecksumVerificationService>(),
        airLinkProtocol: gh<_i618.AirLinkProtocol>(),
        rateLimitingService: gh<_i633.RateLimitingService>(),
        secureSessionManager: gh<_i901.SecureSessionManager>(),
      ));
  gh.factory<_i206.DiscoveryStrategyService>(
      () => _i206.DiscoveryStrategyService(
            loggerService: gh<_i464.LoggerService>(),
            platformDetectionService: gh<_i811.PlatformDetectionService>(),
            connectionService: gh<_i686.ConnectionService>(),
          ));
  gh.factory<_i1002.ShareitZapyaIntegrationService>(
      () => _i1002.ShareitZapyaIntegrationService(
            logger: gh<_i464.LoggerService>(),
            transferService: gh<_i155.EnhancedTransferService>(),
            wifiDirectService: gh<_i675.WifiDirectService>(),
            offlineSharingService: gh<_i133.OfflineSharingService>(),
            phoneReplicationService: gh<_i751.PhoneReplicationService>(),
            groupSharingService: gh<_i122.GroupSharingService>(),
          ));
  gh.factory<_i949.DiscoveryRepository>(() => _i366.DiscoveryRepositoryImpl(
        loggerService: gh<_i464.LoggerService>(),
        permissionService: gh<_i886.PermissionService>(),
        discoveryStrategyService: gh<_i206.DiscoveryStrategyService>(),
      ));
  return getIt;
}
