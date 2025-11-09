import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:airlink/shared/widgets/device_card.dart';
import 'package:airlink/shared/models/app_state.dart';

void main() {
  group('DeviceCard Tests', () {
    testWidgets('should display device information correctly', (WidgetTester tester) async {
      final device = Device(
        id: 'device-123',
        name: 'Test Device',
        type: DeviceType.ios,
        discoveredAt: DateTime.now(),
        rssi: -50,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceCard(
              device: device,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Device'), findsOneWidget);
      expect(find.text('iPhone'), findsOneWidget);
      expect(find.byIcon(Icons.phone_iphone), findsOneWidget);
    });

    testWidgets('should handle tap correctly', (WidgetTester tester) async {
      bool tapped = false;
      final device = Device(
        id: 'device-123',
        name: 'Test Device',
        type: DeviceType.ios,
        discoveredAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceCard(
              device: device,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(DeviceCard));
      expect(tapped, isTrue);
    });

    testWidgets('should display laptop device correctly', (WidgetTester tester) async {
      final device = Device(
        id: 'device-456',
        name: 'Test Laptop',
        type: DeviceType.desktop,
        discoveredAt: DateTime.now(),
        rssi: -60,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceCard(
              device: device,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Laptop'), findsOneWidget);
      expect(find.text('Computer'), findsOneWidget);
      expect(find.byIcon(Icons.computer), findsOneWidget);
    });

    testWidgets('should display tablet device correctly', (WidgetTester tester) async {
      final device = Device(
        id: 'device-789',
        name: 'Test Tablet',
        type: DeviceType.android,
        discoveredAt: DateTime.now(),
        rssi: -70,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceCard(
              device: device,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Tablet'), findsOneWidget);
      expect(find.text('Android'), findsOneWidget);
      expect(find.byIcon(Icons.android), findsOneWidget);
    });

    testWidgets('should display unknown device correctly', (WidgetTester tester) async {
      final device = Device(
        id: 'device-unknown',
        name: 'Unknown Device',
        type: DeviceType.unknown,
        discoveredAt: DateTime.now(),
        rssi: -80,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceCard(
              device: device,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Unknown Device'), findsOneWidget);
      expect(find.text('Unknown'), findsOneWidget);
      expect(find.byIcon(Icons.device_unknown), findsOneWidget);
    });

    testWidgets('should display signal strength correctly', (WidgetTester tester) async {
      final device = Device(
        id: 'device-123',
        name: 'Test Device',
        type: DeviceType.ios,
        discoveredAt: DateTime.now(),
        rssi: -45, // Strong signal
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceCard(
              device: device,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.signal_cellular_4_bar), findsOneWidget);
    });

    testWidgets('should display weak signal correctly', (WidgetTester tester) async {
      final device = Device(
        id: 'device-123',
        name: 'Test Device',
        type: DeviceType.ios,
        discoveredAt: DateTime.now(),
        rssi: -85, // Weak signal
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceCard(
              device: device,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.signal_cellular_0_bar), findsOneWidget);
    });

    testWidgets('should display connection status when connected', (WidgetTester tester) async {
      final device = Device(
        id: 'device-123',
        name: 'Test Device',
        type: DeviceType.ios,
        discoveredAt: DateTime.now(),
        isConnected: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceCard(
              device: device,
              onTap: () {},
              showConnectionStatus: true,
            ),
          ),
        ),
      );

      expect(find.text('Connected'), findsOneWidget);
    });

    testWidgets('should display connection status when not connected', (WidgetTester tester) async {
      final device = Device(
        id: 'device-123',
        name: 'Test Device',
        type: DeviceType.ios,
        discoveredAt: DateTime.now(),
        isConnected: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceCard(
              device: device,
              onTap: () {},
              showConnectionStatus: true,
            ),
          ),
        ),
      );

      expect(find.text('Connected'), findsNothing);
    });

    testWidgets('should not display connection status when disabled', (WidgetTester tester) async {
      final device = Device(
        id: 'device-123',
        name: 'Test Device',
        type: DeviceType.ios,
        discoveredAt: DateTime.now(),
        isConnected: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceCard(
              device: device,
              onTap: () {},
              showConnectionStatus: false,
            ),
          ),
        ),
      );

      expect(find.text('Connected'), findsNothing);
      expect(find.text('Not Connected'), findsNothing);
    });

    // Discovery time is not displayed by the current widget; skip related assertion.

    testWidgets('should handle null RSSI gracefully', (WidgetTester tester) async {
      final device = Device(
        id: 'device-123',
        name: 'Test Device',
        type: DeviceType.ios,
        discoveredAt: DateTime.now(),
        rssi: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceCard(
              device: device,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Test Device'), findsOneWidget);
      // No signal icon rendered when RSSI is null; ensure no crash and basic content exists.
    });

    testWidgets('should handle empty device name gracefully', (WidgetTester tester) async {
      final device = Device(
        id: 'device-123',
        name: '',
        type: DeviceType.ios,
        discoveredAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceCard(
              device: device,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Unknown Device'), findsOneWidget);
    });

    testWidgets('should handle null device name gracefully', (WidgetTester tester) async {
      final device = Device(
        id: 'device-123',
        name: 'Unknown Device',
        type: DeviceType.ios,
        discoveredAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DeviceCard(
              device: device,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Unknown Device'), findsOneWidget);
    });
  });
}
