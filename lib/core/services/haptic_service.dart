import 'package:flutter/services.dart';

/// Service for providing haptic feedback throughout the app
class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  bool _initialized = false;

  /// Initialize the haptic service
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
  }

  /// Light haptic feedback for button taps
  Future<void> light() async {
    if (!_initialized) await initialize();
    HapticFeedback.lightImpact();
  }

  /// Medium haptic feedback for selections
  Future<void> medium() async {
    if (!_initialized) await initialize();
    HapticFeedback.mediumImpact();
  }

  /// Heavy haptic feedback for important actions
  Future<void> heavy() async {
    if (!_initialized) await initialize();
    HapticFeedback.heavyImpact();
  }

  /// Selection haptic feedback for scrolling/swiping
  Future<void> selection() async {
    if (!_initialized) await initialize();
    HapticFeedback.selectionClick();
  }

  /// Success haptic pattern
  Future<void> success() async {
    if (!_initialized) await initialize();
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.lightImpact();
  }

  /// Error haptic pattern
  Future<void> error() async {
    if (!_initialized) await initialize();
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    HapticFeedback.heavyImpact();
  }

  /// Warning haptic pattern
  Future<void> warning() async {
    if (!_initialized) await initialize();
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.mediumImpact();
  }

  /// Custom vibration pattern (duration in milliseconds)
  Future<void> vibrate({int duration = 100}) async {
    if (!_initialized) await initialize();
    HapticFeedback.vibrate();
  }
}

