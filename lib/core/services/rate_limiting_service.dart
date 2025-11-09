import 'package:injectable/injectable.dart';

/// Service for implementing rate limiting to prevent DoS attacks
@injectable
class RateLimitingService {
  // Rate limiting configurations
  static const int maxDiscoveryRequests = 10; // per minute
  static const int maxConnectionAttempts = 3; // per minute
  static const int maxInvalidFrames = 10; // per connection
  static const int maxTransferRequests = 5; // per minute
  
  // Time windows
  static const Duration discoveryWindow = Duration(minutes: 1);
  static const Duration connectionWindow = Duration(minutes: 1);
  static const Duration transferWindow = Duration(minutes: 1);
  static const Duration frameWindow = Duration(minutes: 5);
  
  // Request tracking maps
  final Map<String, List<DateTime>> _discoveryRequests = {};
  final Map<String, List<DateTime>> _connectionAttempts = {};
  final Map<String, List<DateTime>> _transferRequests = {};
  final Map<String, List<DateTime>> _invalidFrames = {};
  
  /// Check if discovery request is allowed for a device
  bool isDiscoveryAllowed(String deviceId) {
    return _isAllowed(
      deviceId,
      _discoveryRequests,
      maxDiscoveryRequests,
      discoveryWindow,
    );
  }
  
  /// Record a discovery request
  void recordDiscoveryRequest(String deviceId) {
    _recordRequest(deviceId, _discoveryRequests);
  }
  
  /// Check if connection attempt is allowed for a device
  bool isConnectionAllowed(String deviceId) {
    return _isAllowed(
      deviceId,
      _connectionAttempts,
      maxConnectionAttempts,
      connectionWindow,
    );
  }
  
  /// Record a connection attempt
  void recordConnectionAttempt(String deviceId) {
    _recordRequest(deviceId, _connectionAttempts);
  }
  
  /// Check if transfer request is allowed for a device
  bool isTransferAllowed(String deviceId) {
    return _isAllowed(
      deviceId,
      _transferRequests,
      maxTransferRequests,
      transferWindow,
    );
  }
  
  /// Record a transfer request
  void recordTransferRequest(String deviceId) {
    _recordRequest(deviceId, _transferRequests);
  }
  
  /// Check if invalid frame is within limits for a connection
  bool isInvalidFrameAllowed(String connectionId) {
    return _isAllowed(
      connectionId,
      _invalidFrames,
      maxInvalidFrames,
      frameWindow,
    );
  }
  
  /// Record an invalid frame
  void recordInvalidFrame(String connectionId) {
    _recordRequest(connectionId, _invalidFrames);
  }
  
  /// Get rate limiting status for a device
  RateLimitStatus getRateLimitStatus(String deviceId) {
    // Clean old requests
    _cleanOldRequests(deviceId, _discoveryRequests, discoveryWindow);
    _cleanOldRequests(deviceId, _connectionAttempts, connectionWindow);
    _cleanOldRequests(deviceId, _transferRequests, transferWindow);
    _cleanOldRequests(deviceId, _invalidFrames, frameWindow);
    
    return RateLimitStatus(
      deviceId: deviceId,
      discoveryRequests: _discoveryRequests[deviceId]?.length ?? 0,
      maxDiscoveryRequests: maxDiscoveryRequests,
      connectionAttempts: _connectionAttempts[deviceId]?.length ?? 0,
      maxConnectionAttempts: maxConnectionAttempts,
      transferRequests: _transferRequests[deviceId]?.length ?? 0,
      maxTransferRequests: maxTransferRequests,
      invalidFrames: _invalidFrames[deviceId]?.length ?? 0,
      maxInvalidFrames: maxInvalidFrames,
      isDiscoveryBlocked: !isDiscoveryAllowed(deviceId),
      isConnectionBlocked: !isConnectionAllowed(deviceId),
      isTransferBlocked: !isTransferAllowed(deviceId),
      isInvalidFrameBlocked: !isInvalidFrameAllowed(deviceId),
    );
  }
  
  /// Reset rate limiting for a device (for testing or manual reset)
  void resetRateLimit(String deviceId) {
    _discoveryRequests.remove(deviceId);
    _connectionAttempts.remove(deviceId);
    _transferRequests.remove(deviceId);
    _invalidFrames.remove(deviceId);
  }
  
  /// Reset all rate limiting (for testing)
  void resetAllRateLimits() {
    _discoveryRequests.clear();
    _connectionAttempts.clear();
    _transferRequests.clear();
    _invalidFrames.clear();
  }
  
  /// Check if request is allowed based on rate limiting rules
  bool _isAllowed(
    String key,
    Map<String, List<DateTime>> requestMap,
    int maxRequests,
    Duration window,
  ) {
    final now = DateTime.now();
    final requests = requestMap[key] ?? [];
    
    // Remove old requests outside window
    requests.removeWhere((time) => now.difference(time) > window);
    
    return requests.length < maxRequests;
  }
  
  /// Record a request timestamp
  void _recordRequest(String key, Map<String, List<DateTime>> requestMap) {
    final now = DateTime.now();
    requestMap[key] ??= [];
    requestMap[key]!.add(now);
  }
  
  /// Clean old requests outside the time window
  void _cleanOldRequests(
    String key,
    Map<String, List<DateTime>> requestMap,
    Duration window,
  ) {
    final now = DateTime.now();
    final requests = requestMap[key];
    if (requests != null) {
      requests.removeWhere((time) => now.difference(time) > window);
      if (requests.isEmpty) {
        requestMap.remove(key);
      }
    }
  }
  
  /// Check if transfer request is allowed for a specific device
  RateLimitResult checkTransferRateLimit(String deviceId) {
    _cleanOldRequests(deviceId, _transferRequests, transferWindow);
    final int currentCount = _transferRequests[deviceId]?.length ?? 0;
    final bool allowed = currentCount < maxTransfersPerDevice;
    final Duration? retryAfter = allowed ? null : transferWindow;
    return RateLimitResult(
      allowed: allowed,
      retryAfter: retryAfter,
      currentCount: currentCount,
    );
  }

  /// Check global transfer rate limit (across all devices)
  RateLimitResult checkGlobalRateLimit() {
    final DateTime now = DateTime.now();
    int totalCount = 0;
    for (final requests in _transferRequests.values) {
      requests.removeWhere((time) => now.difference(time) > transferWindow);
      totalCount += requests.length;
    }
    final bool allowed = totalCount < maxGlobalTransfers;
    final Duration? retryAfter = allowed ? null : transferWindow;
    return RateLimitResult(
      allowed: allowed,
      retryAfter: retryAfter,
      currentCount: totalCount,
    );
  }

  /// Cleanup old entries to prevent memory leaks
  void cleanupOldEntries() {
    final DateTime cutoff = DateTime.now().subtract(const Duration(minutes: 5));
    _discoveryRequests.removeWhere((key, requests) {
      requests.removeWhere((time) => time.isBefore(cutoff));
      return requests.isEmpty;
    });
    _connectionAttempts.removeWhere((key, requests) {
      requests.removeWhere((time) => time.isBefore(cutoff));
      return requests.isEmpty;
    });
    _transferRequests.removeWhere((key, requests) {
      requests.removeWhere((time) => time.isBefore(cutoff));
      return requests.isEmpty;
    });
    _invalidFrames.removeWhere((key, requests) {
      requests.removeWhere((time) => time.isBefore(cutoff));
      return requests.isEmpty;
    });
  }

  /// Get all rate limiting statistics
  Map<String, dynamic> getStatistics() {
    return {
      'discoveryRequests': _discoveryRequests.length,
      'connectionAttempts': _connectionAttempts.length,
      'transferRequests': _transferRequests.length,
      'invalidFrames': _invalidFrames.length,
      'totalTrackedDevices': {
        ..._discoveryRequests.keys,
        ..._connectionAttempts.keys,
        ..._transferRequests.keys,
        ..._invalidFrames.keys,
      }.length,
    };
  }
  
  // Rate limiting configuration constants
  static const int maxTransfersPerDevice = 10; // per minute
  static const int maxGlobalTransfers = 50; // per minute across all devices
}

/// Rate limit check result
class RateLimitResult {
  final bool allowed;
  final Duration? retryAfter;
  final int currentCount;
  
  RateLimitResult({
    required this.allowed,
    this.retryAfter,
    required this.currentCount,
  });
}

/// Rate limiting status for a device
class RateLimitStatus {
  final String deviceId;
  final int discoveryRequests;
  final int maxDiscoveryRequests;
  final int connectionAttempts;
  final int maxConnectionAttempts;
  final int transferRequests;
  final int maxTransferRequests;
  final int invalidFrames;
  final int maxInvalidFrames;
  final bool isDiscoveryBlocked;
  final bool isConnectionBlocked;
  final bool isTransferBlocked;
  final bool isInvalidFrameBlocked;
  
  RateLimitStatus({
    required this.deviceId,
    required this.discoveryRequests,
    required this.maxDiscoveryRequests,
    required this.connectionAttempts,
    required this.maxConnectionAttempts,
    required this.transferRequests,
    required this.maxTransferRequests,
    required this.invalidFrames,
    required this.maxInvalidFrames,
    required this.isDiscoveryBlocked,
    required this.isConnectionBlocked,
    required this.isTransferBlocked,
    required this.isInvalidFrameBlocked,
  });
  
  /// Check if any rate limit is exceeded
  bool get isAnyBlocked => isDiscoveryBlocked || isConnectionBlocked || isTransferBlocked || isInvalidFrameBlocked;
  
  /// Get the most restrictive rate limit
  String get mostRestrictiveLimit {
    if (isInvalidFrameBlocked) return 'invalid_frame';
    if (isTransferBlocked) return 'transfer';
    if (isConnectionBlocked) return 'connection';
    if (isDiscoveryBlocked) return 'discovery';
    return 'none';
  }
  
  @override
  String toString() {
    return 'RateLimitStatus(device: $deviceId, discovery: $discoveryRequests/$maxDiscoveryRequests, '
           'connection: $connectionAttempts/$maxConnectionAttempts, '
           'transfer: $transferRequests/$maxTransferRequests, '
           'invalidFrames: $invalidFrames/$maxInvalidFrames, '
           'blocked: discovery=$isDiscoveryBlocked, connection=$isConnectionBlocked, '
           'transfer=$isTransferBlocked, invalidFrame=$isInvalidFrameBlocked)';
  }
}