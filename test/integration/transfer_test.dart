import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:airlink/main.dart' as app;
// Removed unused imports to fix analyzer warnings

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('End-to-End Transfer Tests', () {
    testWidgets('should complete file transfer successfully', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to send page
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Select a test file
      await tester.tap(find.text('Select Files'));
      await tester.pumpAndSettle();

      // Select a device (should be available from mock discovery)
      await tester.tap(find.text('iPhone 15 Pro'));
      await tester.pumpAndSettle();

      // Start transfer
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      // Verify transfer started (check for transfer session)
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Wait for completion
      await tester.pumpAndSettle(Duration(seconds: 5));

      // Verify completion (check for success state)
      expect(find.text('Transfer completed'), findsOneWidget);
    });

    testWidgets('should handle transfer failure gracefully', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to send page
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Select a test file
      await tester.tap(find.text('Select Files'));
      await tester.pumpAndSettle();

      // Select a device
      await tester.tap(find.text('iPhone 15 Pro'));
      await tester.pumpAndSettle();

      // Start transfer
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      // Simulate network failure
      await tester.pumpAndSettle(Duration(seconds: 2));

      // Verify error handling (check for error state)
      expect(find.text('Transfer failed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('should handle transfer cancellation', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to send page
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Select a test file
      await tester.tap(find.text('Select Files'));
      await tester.pumpAndSettle();

      // Select a device
      await tester.tap(find.text('iPhone 15 Pro'));
      await tester.pumpAndSettle();

      // Start transfer
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      // Cancel transfer
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify cancellation
      expect(find.text('Transfer cancelled'), findsOneWidget);
    });

    testWidgets('should handle transfer pause and resume', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to send page
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Select a test file
      await tester.tap(find.text('Select Files'));
      await tester.pumpAndSettle();

      // Select a device
      await tester.tap(find.text('iPhone 15 Pro'));
      await tester.pumpAndSettle();

      // Start transfer
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      // Pause transfer
      await tester.tap(find.text('Pause'));
      await tester.pumpAndSettle();

      // Verify pause
      expect(find.text('Transfer paused'), findsOneWidget);

      // Resume transfer
      await tester.tap(find.text('Resume'));
      await tester.pumpAndSettle();

      // Verify resume
      expect(find.text('Transfer in progress'), findsOneWidget);
    });

    testWidgets('should display transfer progress correctly', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to send page
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Select a test file
      await tester.tap(find.text('Select Files'));
      await tester.pumpAndSettle();

      // Select a device
      await tester.tap(find.text('iPhone 15 Pro'));
      await tester.pumpAndSettle();

      // Start transfer
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      // Verify progress indicators
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);

      // Wait for progress update
      await tester.pumpAndSettle(Duration(seconds: 2));

      // Verify progress update
      expect(find.text('50%'), findsOneWidget);
    });

    testWidgets('should handle multiple file transfer', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to send page
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Select multiple files
      await tester.tap(find.text('Select Files'));
      await tester.pumpAndSettle();

      // Select a device
      await tester.tap(find.text('iPhone 15 Pro'));
      await tester.pumpAndSettle();

      // Start transfer
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      // Verify multiple files
      expect(find.text('3 files selected'), findsOneWidget);

      // Wait for completion
      await tester.pumpAndSettle(Duration(seconds: 5));

      // Verify completion
      expect(find.text('Transfer completed'), findsOneWidget);
    });

    testWidgets('should handle large file transfer', (WidgetTester tester) async {
      // Start the app
      app.main();
      await tester.pumpAndSettle();

      // Navigate to send page
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Select a large file
      await tester.tap(find.text('Select Files'));
      await tester.pumpAndSettle();

      // Select a device
      await tester.tap(find.text('iPhone 15 Pro'));
      await tester.pumpAndSettle();

      // Start transfer
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();

      // Verify large file handling
      expect(find.text('100 MB'), findsOneWidget);

      // Wait for completion
      await tester.pumpAndSettle(Duration(seconds: 10));

      // Verify completion
      expect(find.text('Transfer completed'), findsOneWidget);
    });
  });
}
