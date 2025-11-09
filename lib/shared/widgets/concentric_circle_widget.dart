import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Device model for nearby devices
class NearbyDevice {
  final String id;
  final String name;
  final String type; // 'android', 'ios', 'windows', etc.
  final bool isConnected;

  NearbyDevice({
    required this.id,
    required this.name,
    required this.type,
    this.isConnected = false,
  });
}

/// Concentric Circle Widget with animated rings showing nearby devices
/// Displays discovered devices as popups around the concentric circles
class ConcentricCircleWidget extends StatefulWidget {
  final List<NearbyDevice> nearbyDevices;
  final VoidCallback? onDeviceTap;

  const ConcentricCircleWidget({
    super.key,
    this.nearbyDevices = const [],
    this.onDeviceTap,
  });

  @override
  State<ConcentricCircleWidget> createState() => _ConcentricCircleWidgetState();
}

class _ConcentricCircleWidgetState extends State<ConcentricCircleWidget>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Rotation animation for outer rings
    _rotationController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();

    // Pulse animation for center
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(20),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated concentric circles
          AnimatedBuilder(
            animation: _rotationController,
            builder: (context, child) {
              return CustomPaint(
                size: const Size(350, 350),
                painter: ConcentricCirclesPainter(
                  rotation: _rotationController.value * 2 * math.pi,
                  color: Theme.of(context).colorScheme.primary,
                ),
              );
            },
          ),

          // Nearby devices positioned around the circle
          ..._buildDevicePopups(context),

          // Center pulsing icon
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 102),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.radar,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDevicePopups(BuildContext context) {
    if (widget.nearbyDevices.isEmpty) {
      return [];
    }

    final radius = 140.0;
    final devices = widget.nearbyDevices.take(8).toList(); // Max 8 devices
    
    return List.generate(devices.length, (index) {
      final device = devices[index];
      final angle = (2 * math.pi * index) / devices.length;
      final x = radius * math.cos(angle);
      final y = radius * math.sin(angle);

      return Positioned(
        left: 175 + x - 35,
        top: 175 + y - 35,
        child: _buildDevicePopup(context, device),
      );
    });
  }

  Widget _buildDevicePopup(BuildContext context, NearbyDevice device) {
    final deviceIcon = _getDeviceIcon(device.type);
    final deviceColor = device.isConnected ? Colors.green : Colors.blue;

    return GestureDetector(
      onTap: widget.onDeviceTap,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: device.isConnected ? 1.0 : _pulseAnimation.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: deviceColor.withValues(alpha: 38),
                    border: Border.all(
                      color: deviceColor,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: deviceColor.withValues(alpha: 102),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    deviceIcon,
                    color: deviceColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: deviceColor.withValues(alpha: 25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    device.name.length > 10 
                        ? '${device.name.substring(0, 10)}...' 
                        : device.name,
                    style: TextStyle(
                      color: deviceColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _getDeviceIcon(String type) {
    switch (type.toLowerCase()) {
      case 'android':
        return Icons.android;
      case 'ios':
      case 'iphone':
        return Icons.phone_iphone;
      case 'windows':
        return Icons.computer;
      case 'mac':
      case 'macos':
        return Icons.laptop_mac;
      case 'linux':
        return Icons.computer;
      default:
        return Icons.devices;
    }
  }
}

/// Custom painter for animated concentric circles
class ConcentricCirclesPainter extends CustomPainter {
  final double rotation;
  final Color color;

  ConcentricCirclesPainter({
    required this.rotation,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw 5 concentric circles with different opacities and rotations
    for (int i = 1; i <= 5; i++) {
      final radius = (size.width / 2) * (i / 5);
      final opacity = 0.1 + (i * 0.05);
      
      paint.color = color.withValues(alpha: opacity);

      // Draw circle
      canvas.drawCircle(center, radius, paint);

      // Draw rotating dashed effect
      final dashCount = 20 + (i * 4);
      final angleStep = (2 * math.pi) / dashCount;
      final rotationOffset = rotation * (i.isEven ? 1 : -1);

      for (int j = 0; j < dashCount; j++) {
        final angle = (j * angleStep) + rotationOffset;
        final x1 = center.dx + (radius - 5) * math.cos(angle);
        final y1 = center.dy + (radius - 5) * math.sin(angle);
        final x2 = center.dx + (radius + 5) * math.cos(angle);
        final y2 = center.dy + (radius + 5) * math.sin(angle);

        if (j % 2 == 0) {
          canvas.drawLine(
            Offset(x1, y1),
            Offset(x2, y2),
            paint..strokeWidth = 2,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(ConcentricCirclesPainter oldDelegate) {
    return oldDelegate.rotation != rotation || oldDelegate.color != color;
  }
}
