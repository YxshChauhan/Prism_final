import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Radar-like device discovery widget inspired by Zapya
class RadarDiscoveryWidget extends StatefulWidget {
  final List<RadarDevice> devices;
  final bool isScanning;
  final VoidCallback? onShakeToConnect;
  final VoidCallback? onDeviceTap;
  final String? instructionText;

  const RadarDiscoveryWidget({
    super.key,
    required this.devices,
    this.isScanning = false,
    this.onShakeToConnect,
    this.onDeviceTap,
    this.instructionText,
  });

  @override
  State<RadarDiscoveryWidget> createState() => _RadarDiscoveryWidgetState();
}

class _RadarDiscoveryWidgetState extends State<RadarDiscoveryWidget>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _pulseController;
  late Animation<double> _radarAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _radarController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _radarAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _radarController,
      curve: Curves.linear,
    ));
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.isScanning) {
      _startAnimations();
    }
  }

  @override
  void didUpdateWidget(RadarDiscoveryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning && !oldWidget.isScanning) {
      _startAnimations();
    } else if (!widget.isScanning && oldWidget.isScanning) {
      _stopAnimations();
    }
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _startAnimations() {
    _radarController.repeat();
    _pulseController.repeat(reverse: true);
  }

  void _stopAnimations() {
    _radarController.stop();
    _pulseController.stop();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Radar background
          _buildRadarBackground(),
          
          // Radar sweep
          if (widget.isScanning) _buildRadarSweep(),
          
          // Center device
          _buildCenterDevice(),
          
          // Detected devices
          ...widget.devices.map((device) => _buildDeviceDot(device)),
          
          // Instructions
          if (widget.instructionText != null)
            Positioned(
              bottom: 20,
              child: _buildInstructions(),
            ),
        ],
      ),
    );
  }

  Widget _buildRadarBackground() {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[100],
        border: Border.all(
          color: Colors.grey[300]!,
          width: 2,
        ),
      ),
      child: CustomPaint(
        painter: RadarBackgroundPainter(),
      ),
    );
  }

  Widget _buildRadarSweep() {
    return AnimatedBuilder(
      animation: _radarAnimation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(250, 250),
          painter: RadarSweepPainter(
            sweepAngle: _radarAnimation.value * 2 * math.pi,
          ),
        );
      },
    );
  }

  Widget _buildCenterDevice() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: GestureDetector(
            onTap: widget.onDeviceTap,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.person,
                color: Colors.grey,
                size: 30,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceDot(RadarDevice device) {
    final angle = device.angle;
    final distance = device.distance;
    
    // Convert polar coordinates to screen coordinates
    final x = math.cos(angle) * distance * 100;
    final y = math.sin(angle) * distance * 100;
    
    return Positioned(
      left: 125 + x - 20,
      top: 125 + y - 20,
      child: GestureDetector(
        onTap: () => widget.onDeviceTap?.call(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getDeviceColor(device.type),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            _getDeviceIcon(device.type),
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.phone_android,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            widget.instructionText ?? 'Shake devices to connect now',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Color _getDeviceColor(RadarDeviceType type) {
    switch (type) {
      case RadarDeviceType.phone:
        return Colors.blue;
      case RadarDeviceType.computer:
        return Colors.purple;
      case RadarDeviceType.tablet:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getDeviceIcon(RadarDeviceType type) {
    switch (type) {
      case RadarDeviceType.phone:
        return Icons.phone_iphone;
      case RadarDeviceType.computer:
        return Icons.computer;
      case RadarDeviceType.tablet:
        return Icons.tablet;
      default:
        return Icons.device_unknown;
    }
  }
}

/// Radar device model
class RadarDevice {
  final String id;
  final String name;
  final RadarDeviceType type;
  final double angle; // in radians
  final double distance; // normalized 0-1
  final bool isConnected;

  const RadarDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.angle,
    required this.distance,
    this.isConnected = false,
  });
}

enum RadarDeviceType {
  phone,
  computer,
  tablet,
  unknown,
}

/// Custom painter for radar background
class RadarBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Background circle
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Border circle
    final borderPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);
    
    // Draw concentric circles with different opacities
    final circlePaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 1; i <= 3; i++) {
      final circleRadius = radius * (i / 3);
      canvas.drawCircle(center, circleRadius, circlePaint);
    }

    // Draw cross lines (horizontal and vertical)
    final linePaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // Horizontal line
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      linePaint,
    );
    
    // Vertical line
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      linePaint,
    );
    
    // Draw diagonal lines for better radar appearance
    final diagonalPaint = Paint()
      ..color = Colors.green.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    
    // 45-degree diagonal lines
    final diagonalLength = radius * 0.7;
    final offset = diagonalLength / math.sqrt(2);
    
    // Top-right to bottom-left
    canvas.drawLine(
      Offset(center.dx + offset, center.dy - offset),
      Offset(center.dx - offset, center.dy + offset),
      diagonalPaint,
    );
    
    // Top-left to bottom-right
    canvas.drawLine(
      Offset(center.dx - offset, center.dy - offset),
      Offset(center.dx + offset, center.dy + offset),
      diagonalPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Custom painter for radar sweep
class RadarSweepPainter extends CustomPainter {
  final double sweepAngle;

  RadarSweepPainter({required this.sweepAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Create multiple sweep layers for trailing effect
    final sweepSector = math.pi / 4; // 45 degrees for main sweep
    
    // Draw trailing sweeps with decreasing opacity
    for (int i = 0; i < 3; i++) {
      final trailingAngle = sweepAngle - (i * math.pi / 12); // 15 degrees behind
      final opacity = (1.0 - i * 0.3).clamp(0.0, 1.0);
      
      final paint = Paint()
        ..color = Colors.red.withValues(alpha: opacity * 0.3)
        ..style = PaintingStyle.fill;
      
      final path = Path();
      path.moveTo(center.dx, center.dy);
      
      final startAngle = trailingAngle - sweepSector / 2;
      final endAngle = trailingAngle + sweepSector / 2;
      
      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        endAngle - startAngle,
        false,
      );
      path.close();
      
      canvas.drawPath(path, paint);
    }
    
    // Main sweep with gradient
    final mainPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          Colors.red.withValues(alpha: 0.6),
          Colors.red.withValues(alpha: 0.3),
          Colors.red.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final mainPath = Path();
    mainPath.moveTo(center.dx, center.dy);
    
    final startAngle = sweepAngle - sweepSector / 2;
    final endAngle = sweepAngle + sweepSector / 2;
    
    mainPath.arcTo(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      endAngle - startAngle,
      false,
    );
    mainPath.close();

    canvas.drawPath(mainPath, mainPaint);
    
    // Bright leading edge line
    final linePaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;
    
    final lineEnd = Offset(
      center.dx + math.cos(sweepAngle) * radius,
      center.dy + math.sin(sweepAngle) * radius,
    );
    
    canvas.drawLine(center, lineEnd, linePaint);
    
    // Add a bright dot at the leading edge
    final dotPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.fill;
    
    canvas.drawCircle(lineEnd, 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
