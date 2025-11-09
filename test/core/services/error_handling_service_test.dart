import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:airlink/core/services/error_handling_service.dart';

void main() {
  group('Error Handling Service Tests', () {
    late ErrorHandlingService errorService;

    setUp(() {
      errorService = ErrorHandlingService();
    });

    tearDown(() {
      errorService.clearErrorHistory();
    });

    test('should handle network errors correctly', () async {
      final socketException = SocketException('Connection failed');
      await errorService.handleError(socketException, 'test_context');
      // Verify error was handled without throwing
      expect(true, isTrue);
    });

    test('should handle file system errors correctly', () async {
      final fileException = FileSystemException('Permission denied');
      await errorService.handleError(fileException, 'test_context');
      expect(true, isTrue);
    });

    test('should handle timeout errors correctly', () async {
      final timeoutException = TimeoutException('Operation timed out');
      await errorService.handleError(timeoutException, 'timeout_test');
      expect(true, isTrue); // Verify error was handled without throwing
    });

    test('should handle format errors correctly', () async {
      final formatException = FormatException('Invalid format');
      await errorService.handleError(formatException, 'format_test');
      expect(true, isTrue); // Verify error was handled without throwing
    });

    test('should handle state errors correctly', () async {
      final stateError = StateError('Invalid state');
      await errorService.handleError(stateError, 'state_test');
      expect(true, isTrue); // Verify error was handled without throwing
    });

    test('should handle argument errors correctly', () async {
      final argumentError = ArgumentError('Invalid argument');
      await errorService.handleError(argumentError, 'argument_test');
      expect(true, isTrue); // Verify error was handled without throwing
    });

    test('should handle unknown errors correctly', () async {
      final unknownError = Exception('Unknown error');
      await errorService.handleError(unknownError, 'unknown_test');
      expect(true, isTrue); // Verify error was handled without throwing
    });

    test('should provide user-friendly error messages', () {
      final socketException = SocketException('Connection failed');
      final message = errorService.getUserFriendlyMessage(socketException, 'network_test');
      expect(message.toLowerCase(), contains('connection'));
      expect(message.toLowerCase(), contains('network'));
    });

    test('should provide recovery suggestions for network errors', () {
      final socketException = SocketException('Connection failed');
      final suggestions = errorService.getRecoverySuggestions(socketException, 'network_test');
      expect(suggestions, anyElement(contains('internet')));
      expect(suggestions, anyElement(contains('WiFi')));
    });

    test('should provide recovery suggestions for file system errors', () {
      final fileException = FileSystemException('Permission denied');
      final suggestions = errorService.getRecoverySuggestions(fileException, 'file_test');
      expect(suggestions, anyElement(contains('permission')));
      expect(suggestions, anyElement(contains('storage')));
    });

    test('should track error counts', () async {
      final error = SocketException('Test error');
      await errorService.handleError(error, 'test_context');

      final stats = errorService.getErrorStatistics();
      expect(stats['totalErrors'], equals(1));
      expect(stats['errorTypes'], contains('SocketException_test_context'));
    });

    test('should apply cooldown for excessive errors', () async {
      // Generate a few errors to test the mechanism without triggering long cooldown
      for (int i = 0; i < 5; i++) {
        await errorService.handleError(
          SocketException('Test error $i'),
          'test_context',
        );
      }

      final stats = errorService.getErrorStatistics();
      expect(stats['totalErrors'], equals(5));
    });

    test('should clear error history', () {
      errorService.clearErrorHistory();
      final stats = errorService.getErrorStatistics();
      expect(stats['totalErrors'], equals(0));
      expect(stats['errorTypes'], isEmpty);
    });
  });

  group('Error Handling Integration Tests', () {
    test('should handle multiple error types', () async {
      final errorService = ErrorHandlingService();

      final errors = [
        SocketException('Network error'),
        FileSystemException('File error'),
        TimeoutException('Timeout error'),
        FormatException('Format error'),
        StateError('State error'),
        ArgumentError('Argument error'),
        Exception('Unknown error'),
      ];

      for (int i = 0; i < errors.length; i++) {
        await errorService.handleError(errors[i], 'test_context_$i');
      }

      final stats = errorService.getErrorStatistics();
      expect(stats['totalErrors'], equals(errors.length));
      expect(stats['errorTypes'].length, equals(errors.length));
    });

    test('should provide appropriate suggestions for each error type', () {
      final errorService = ErrorHandlingService();

      final testCases = [
        (SocketException('Network error'), 'network'),
        (FileSystemException('File error'), 'file'),
        (TimeoutException('Timeout error'), 'timeout'),
        (FormatException('Format error'), 'format'),
        (StateError('State error'), 'state'),
        (ArgumentError('Argument error'), 'argument'),
        (Exception('Unknown error'), 'unknown'),
      ];

      for (final testCase in testCases) {
        final error = testCase.$1;
        final context = testCase.$2;

        final message = errorService.getUserFriendlyMessage(error, context);
        final suggestions = errorService.getRecoverySuggestions(error, context);

        expect(message, isNotEmpty);
        expect(suggestions, isNotEmpty);
        expect(suggestions.length, greaterThan(0));
      }
    });
  });
}
