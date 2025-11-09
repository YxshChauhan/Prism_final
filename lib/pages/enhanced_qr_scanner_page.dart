import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:airlink/core/services/qr_connection_service.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/pages/enhanced_qr_display_page.dart';

/// Enhanced QR Scanner page with Zapya-inspired design
class EnhancedQRScannerPage extends StatefulWidget {
  const EnhancedQRScannerPage({super.key});

  @override
  State<EnhancedQRScannerPage> createState() => _EnhancedQRScannerPageState();
}

class _EnhancedQRScannerPageState extends State<EnhancedQRScannerPage> {
  final QRConnectionService _qrService = QRConnectionService();
  final LoggerService _logger = LoggerService();
  MobileScannerController? _scannerController;
  bool get _isMobilePlatform => !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  
  bool _isProcessing = false;
  bool _isTorchOn = false;
  String? _errorMessage;
  QRConnectionState _connectionState = QRConnectionState.idle;
  StreamSubscription<QRConnectionState>? _stateSubscription;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
    _stateSubscription = _qrService.connectionStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _connectionState = state;
        });
      }
    });
    
    // Initialize scanner controller only on supported mobile platforms
    if (_isMobilePlatform) {
      _scannerController = MobileScannerController();
      // Listen to torch state changes
      _scannerController?.torchState.addListener(_onTorchStateChanged);
    }
  }
  
  void _onTorchStateChanged() {
    if (mounted && _scannerController != null) {
      setState(() {
        _isTorchOn = _scannerController?.torchState.value == TorchState.on;
      });
    }
  }
  
  Future<void> _toggleTorch() async {
    try {
      await _scannerController?.toggleTorch();
    } catch (e) {
      _logger.error('Failed to toggle torch', e);
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _qrService.dispose();
    _scannerController?.dispose();
    super.dispose();
  }
  
  Future<void> _checkCameraPermission() async {
    // Permission check is handled by mobile_scanner package
    // This is a placeholder for additional permission handling if needed
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isTorchOn ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            onPressed: _toggleTorch,
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
            onPressed: () => _scannerController?.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Scanner view (only supported on mobile platforms)
          if (_isMobilePlatform)
            MobileScanner(
              controller: _scannerController!,
              onDetect: _onQRCodeDetected,
            )
          else
            // Desktop/web placeholder
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.qr_code_scanner, size: 64, color: Colors.white54),
                    SizedBox(height: 12),
                    Text('QR scanner is available only on mobile devices', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          
          // Zapya-inspired overlay
          _buildZapyaOverlay(),
          
          // Error message
          if (_errorMessage != null)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: _buildErrorCard(),
            ),
          
          // Connection state indicator
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    Text(
                      _getConnectionStateText(),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getConnectionStateDescription(),
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          
          // Success indicator
          if (_connectionState == QRConnectionState.connected)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 80,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Connected Successfully!',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildZapyaOverlay() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
      ),
      child: Column(
        children: [
          const Spacer(),
          // QR Code scanning window with Zapya-style corners
          Center(
            child: SizedBox(
              width: 250,
              height: 250,
              child: Stack(
                children: [
                  // Corner brackets
                  Positioned(
                    top: 0,
                    left: 0,
                    child: _buildCornerBracket(true, true),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _buildCornerBracket(true, false),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: _buildCornerBracket(false, true),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: _buildCornerBracket(false, false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Instructions with Zapya styling
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.qr_code_scanner,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Align the scanner so that the QR code fits',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Text(
                  'inside the box',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Make sure the QR code is visible and well-lit',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  Widget _buildCornerBracket(bool isTop, bool isLeft) {
    return SizedBox(
      width: 30,
      height: 30,
      child: CustomPaint(
        painter: CornerBracketPainter(
          isTop: isTop,
          isLeft: isLeft,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.error_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _errorMessage = null;
                      _isProcessing = false;
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  String _getConnectionStateText() {
    switch (_connectionState) {
      case QRConnectionState.idle:
        return 'Processing...';
      case QRConnectionState.connecting:
        return 'Connecting...';
      case QRConnectionState.establishing:
        return 'Establishing Connection...';
      case QRConnectionState.handshaking:
        return 'Securing Connection...';
      case QRConnectionState.verifying:
        return 'Verifying...';
      case QRConnectionState.connected:
        return 'Connected!';
      case QRConnectionState.failed:
        return 'Connection Failed';
    }
  }
  
  String _getConnectionStateDescription() {
    switch (_connectionState) {
      case QRConnectionState.idle:
        return 'Validating QR code...';
      case QRConnectionState.connecting:
        return 'Initiating connection to device...';
      case QRConnectionState.establishing:
        return 'Creating network connection...';
      case QRConnectionState.handshaking:
        return 'Exchanging encryption keys...';
      case QRConnectionState.verifying:
        return 'Verifying secure handshake...';
      case QRConnectionState.connected:
        return 'Secure connection established';
      case QRConnectionState.failed:
        return 'Please try again';
    }
  }

  Widget _buildBottomNavigation() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(
            icon: Icons.qr_code_scanner,
            label: 'Scan QR Code',
            isActive: true,
          ),
          _buildNavItem(
            icon: Icons.qr_code,
            label: 'My QR Code',
            isActive: false,
            onTap: () => _showMyQRCode(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? Colors.white : Colors.white70,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onQRCodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final String? qrCode = barcodes.first.rawValue;
    if (qrCode == null || qrCode.isEmpty) return;
    
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });
    
    try {
      _logger.info('QR code detected, processing...');
      
      // Parse QR data
      final qrData = await _qrService.parseQRData(qrCode);
      
      // Show confirmation dialog
      if (!mounted) return;
      
      final confirmed = await _showConnectionConfirmation(qrData);
      
      if (confirmed == true) {
        // Initiate connection and wait for handshake completion
        final protocol = await _qrService.connectViaQR(qrData);
        
        if (!mounted) return;
        
        // Return connection result to previous screen
        Navigator.of(context).pop({
          'success': true,
          'qrData': qrData,
          'protocol': protocol,
        });
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } on QRConnectionTimeoutException catch (e) {
      _logger.error('QR connection timeout', e);
      if (!mounted) return;
      setState(() {
        _errorMessage = '⏱️ Connection Timeout\n${e.message}\nPlease check your network and try again.';
        _isProcessing = false;
      });
    } on QRConnectionNetworkException catch (e) {
      _logger.error('QR connection network error', e);
      if (!mounted) return;
      setState(() {
        _errorMessage = '🌐 Network Error\n${e.message}\nPlease check that both devices are on the same network.';
        _isProcessing = false;
      });
    } on QRConnectionHandshakeException catch (e) {
      _logger.error('QR connection handshake error', e);
      if (!mounted) return;
      setState(() {
        _errorMessage = '🔐 Security Error\n${e.message}\nPlease regenerate the QR code and try again.';
        _isProcessing = false;
      });
    } on QRConnectionException catch (e) {
      _logger.error('QR connection error', e);
      if (!mounted) return;
      setState(() {
        _errorMessage = '❌ ${e.message}\nPlease try scanning again.';
        _isProcessing = false;
      });
    } catch (e) {
      _logger.error('Failed to process QR code', e);
      if (!mounted) return;
      setState(() {
        _errorMessage = '❌ Invalid QR Code\nPlease make sure you\'re scanning an AirLink QR code.';
        _isProcessing = false;
      });
    }
  }

  Future<bool?> _showConnectionConfirmation(QRConnectionData qrData) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect to Device?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Do you want to connect to this device?'),
            const SizedBox(height: 16),
            _buildInfoRow('Device Name', qrData.name),
            _buildInfoRow('Device ID', qrData.deviceId.substring(0, 8)),
            _buildInfoRow('IP Address', qrData.ipAddress),
            _buildInfoRow('Age', '${DateTime.now().difference(qrData.timestamp).inSeconds}s ago'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showMyQRCode() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EnhancedQRDisplayPage(
          deviceName: 'AirLink Device',
        ),
      ),
    );
  }
}

/// Custom painter for corner brackets
class CornerBracketPainter extends CustomPainter {
  final bool isTop;
  final bool isLeft;
  final Color color;

  CornerBracketPainter({
    required this.isTop,
    required this.isLeft,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    
    if (isTop && isLeft) {
      // Top-left corner
      path.moveTo(0, size.height * 0.7);
      path.lineTo(0, 0);
      path.lineTo(size.width * 0.7, 0);
    } else if (isTop && !isLeft) {
      // Top-right corner
      path.moveTo(size.width * 0.3, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height * 0.7);
    } else if (!isTop && isLeft) {
      // Bottom-left corner
      path.moveTo(0, size.height * 0.3);
      path.lineTo(0, size.height);
      path.lineTo(size.width * 0.7, size.height);
    } else {
      // Bottom-right corner
      path.moveTo(size.width * 0.3, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, size.height * 0.3);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
