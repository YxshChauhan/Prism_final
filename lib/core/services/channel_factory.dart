import 'dart:async';
import 'package:flutter/services.dart';
import 'package:airlink/core/services/logger_service.dart';

/// Factory for creating namespaced platform channels that multiplex
/// through a single core channel.
///
/// This allows multiple services to communicate through one platform channel
/// by prefixing method names with service identifiers.
class ChannelFactory {
  static final LoggerService _loggerService = LoggerService();
  static const String _coreMethodChannelName = 'airlink/core';
  static const String _coreEventChannelName = 'airlink/events';

  static final MethodChannel _coreMethodChannel =
      const MethodChannel(_coreMethodChannelName);
  static final EventChannel _coreEventChannel =
      const EventChannel(_coreEventChannelName);

  /// Creates a namespaced method channel for the given service
  static NamespacedMethodChannel createMethodChannel(String serviceName) {
    return NamespacedMethodChannel(_coreMethodChannel, serviceName);
  }

  /// Creates a filtered event channel for the given service
  static FilteredEventChannel createEventChannel(String serviceName, {bool requireService = true}) {
    // Initialize the multiplexer if not already done
    _eventMultiplexer.initialize();
    return FilteredEventChannel(_coreEventChannel, serviceName, requireService: requireService);
  }

  /// Creates a multiplexed event channel for the given service
  static Stream<dynamic> createMultiplexedEventChannel(String serviceName) {
    _eventMultiplexer.initialize();
    return _eventMultiplexer.getServiceStream(serviceName);
  }

  /// Gets the core method channel (for backwards compatibility)
  static MethodChannel get coreMethodChannel => _coreMethodChannel;

  /// Gets the core event channel (for backwards compatibility)
  static EventChannel get coreEventChannel => _coreEventChannel;

  /// Event multiplexer singleton
  static final EventMultiplexer _eventMultiplexer = EventMultiplexer();

  /// Get the event multiplexer instance
  static EventMultiplexer get eventMultiplexer => _eventMultiplexer;
}

/// A MethodChannel wrapper that prefixes all method calls with a service name
class NamespacedMethodChannel {
  final MethodChannel _underlying;
  final String _serviceName;

  NamespacedMethodChannel(this._underlying, this._serviceName);

  String get name => '${_underlying.name}/$_serviceName';

  MethodCodec get codec => _underlying.codec;

  BinaryMessenger get binaryMessenger => _underlying.binaryMessenger;

  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) {
    // Prefix method name with service name
    final String namespacedMethod = '$_serviceName.$method';
    return _underlying.invokeMethod<T>(namespacedMethod, arguments);
  }

  Future<List<T>> invokeListMethod<T>(String method, [dynamic arguments]) {
    final String namespacedMethod = '$_serviceName.$method';
    return _underlying.invokeListMethod<T>(namespacedMethod, arguments).then((result) => result ?? []);
  }

  Future<Map<K, V>> invokeMapMethod<K, V>(String method,
      [dynamic arguments]) {
    final String namespacedMethod = '$_serviceName.$method';
    return _underlying.invokeMapMethod<K, V>(namespacedMethod, arguments).then((result) => result ?? {});
  }

  void setMethodCallHandler(
      Future<dynamic> Function(MethodCall call)? handler) {
    // Disallow setMethodCallHandler on namespaced channels to prevent collisions
    throw UnsupportedError(
      'setMethodCallHandler is not supported on namespaced channels. '
      'Use the core channel directly or implement proper routing.'
    );
  }

  // Removed deprecated methods that don't exist in current Flutter version
}

/// An EventChannel wrapper that filters events by service name
class FilteredEventChannel {
  final EventChannel _underlying;
  final String _serviceName;
  final bool _requireService;

  FilteredEventChannel(this._underlying, this._serviceName, {bool requireService = true})
      : _requireService = requireService;

  String get name => '${_underlying.name}/$_serviceName';

  MethodCodec get codec => _underlying.codec;

  BinaryMessenger get binaryMessenger => _underlying.binaryMessenger;

  Stream<dynamic> receiveBroadcastStream([dynamic arguments]) {
    final StreamController<dynamic> controller =
        StreamController<dynamic>.broadcast();
    
    // Store the subscription to properly cancel it
    late StreamSubscription<dynamic> subscription;
    
    subscription = _underlying.receiveBroadcastStream(arguments).listen(
      (dynamic event) {
        // Filter events by service name with normalization
        if (event is Map) {
          final String? eventService = event['service'] as String?;
          final String? normalizedEventService = eventService?.toLowerCase();
          final String normalizedServiceName = _serviceName.toLowerCase();
          
          if (_requireService) {
            // Only forward events that explicitly match our service
            if (normalizedEventService == normalizedServiceName) {
              controller.add(event);
            } else {
              // Debug log when events are dropped due to service mismatch
              ChannelFactory._loggerService.debug('FilteredEventChannel: Dropped event for service "$eventService" (expected "$_serviceName")');
            }
          } else {
            // Forward events that match our service or have no service field
            if (normalizedEventService == normalizedServiceName || eventService == null) {
              controller.add(event);
            } else {
              // Debug log when events are dropped
              ChannelFactory._loggerService.debug('FilteredEventChannel: Dropped event for service "$eventService" (expected "$_serviceName" or null)');
            }
          }
        } else {
          // Only forward non-map events if service requirement is disabled
          if (!_requireService) {
            controller.add(event);
          } else {
            // Debug log when non-map events are dropped
            ChannelFactory._loggerService.debug('FilteredEventChannel: Dropped non-map event (service required: $_serviceName)');
          }
        }
      },
      onError: controller.addError,
      onDone: controller.close,
    );
    
    // Implement proper cleanup when the stream is cancelled
    controller.onCancel = () {
      subscription.cancel();
    };
    
    return controller.stream;
  }
}

/// Singleton event multiplexer that centralizes EventChannel subscriptions
/// and broadcasts events to per-service streams
class EventMultiplexer {
  static final EventMultiplexer _instance = EventMultiplexer._internal();
  factory EventMultiplexer() => _instance;
  EventMultiplexer._internal();

  final Map<String, StreamController<dynamic>> _serviceControllers = {};
  StreamSubscription<dynamic>? _coreSubscription;
  bool _isInitialized = false;

  /// Initialize the multiplexer with the core event channel
  void initialize() {
    if (_isInitialized) return;
    
    _coreSubscription = ChannelFactory.coreEventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        // Filter and route events to appropriate service controllers
        if (event is Map) {
          final String? eventService = event['service'] as String?;
          if (eventService != null) {
            final String normalizedEventService = eventService.toLowerCase();
            final controller = _serviceControllers[normalizedEventService];
            if (controller != null && !controller.isClosed) {
              controller.add(event);
            } else {
              // Debug log when events are dropped due to no matching service controller
              ChannelFactory._loggerService.debug('EventMultiplexer: Dropped event for service "$eventService" (no controller found)');
            }
          } else {
            // Broadcast to all controllers if no service specified
            for (final controller in _serviceControllers.values) {
              if (!controller.isClosed) {
                controller.add(event);
              }
            }
          }
        } else {
          // Broadcast non-map events to all controllers
          for (final controller in _serviceControllers.values) {
            if (!controller.isClosed) {
              controller.add(event);
            }
          }
        }
      },
      onError: (error) {
        // Broadcast errors to all service controllers
        for (final controller in _serviceControllers.values) {
          if (!controller.isClosed) {
            controller.addError(error);
          }
        }
      },
    );
    
    _isInitialized = true;
  }

  /// Get a stream for a specific service
  Stream<dynamic> getServiceStream(String serviceName) {
    final String normalizedServiceName = serviceName.toLowerCase();
    if (!_serviceControllers.containsKey(normalizedServiceName)) {
      _serviceControllers[normalizedServiceName] = StreamController<dynamic>.broadcast();
    }
    return _serviceControllers[normalizedServiceName]!.stream;
  }

  /// Dispose the multiplexer and clean up resources
  void dispose() {
    _coreSubscription?.cancel();
    for (final controller in _serviceControllers.values) {
      controller.close();
    }
    _serviceControllers.clear();
    _isInitialized = false;
  }
}

