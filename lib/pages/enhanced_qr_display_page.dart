import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:airlink/core/services/qr_connection_service.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/pages/enhanced_qr_scanner_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Enhanced QR Display page with Zapya-inspired design
class EnhancedQRDisplayPage extends StatefulWidget {
  final String deviceName;

  const EnhancedQRDisplayPage({super.key, required this.deviceName});

  @override
  State<EnhancedQRDisplayPage> createState() => _EnhancedQRDisplayPageState();
}

class _EnhancedQRDisplayPageState extends State<EnhancedQRDisplayPage> {
  final QRConnectionService _qrService = QRConnectionService();
  final LoggerService _logger = LoggerService();

  String? _qrData;
  bool _isLoading = true;
  String? _errorMessage;
  DateTime? _generatedAt;
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  bool _isWaitingForConnection = true;
  int _remainingSeconds = 0;
  String? _localIpAddress;
  final List<String> _connectionHistory = [];
  StreamSubscription<QRConnectionState>? _connectionSubscription;
  final GlobalKey _qrKey = GlobalKey();

  static const int refreshIntervalMinutes = 4; // Refresh before 5-min expiry

  @override
  void initState() {
    super.initState();
    _generateQRCode();
    _startAutoRefresh();

    // Listen to connection events
    _connectionSubscription = _qrService.connectionStateStream.listen((state) {
      if (state == QRConnectionState.connected) {
        _addToConnectionHistory('Device connected');
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    _connectionSubscription?.cancel();
    _qrService.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(
      Duration(minutes: refreshIntervalMinutes),
      (_) => _generateQRCode(),
    );
    _startCountdownTimer();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateCountdown(),
    );
  }

  void _updateCountdown() {
    if (_generatedAt == null) return;

    final expiry = _generatedAt!.add(
      const Duration(minutes: QRConnectionService.qrValidityMinutes),
    );
    final remaining = expiry.difference(DateTime.now());

    if (mounted) {
      setState(() {
        _remainingSeconds = remaining.inSeconds;
        if (_remainingSeconds <= 0) {
          // Auto-refresh when expired
          _generateQRCode();
        }
      });
    }
  }

  Future<void> _generateQRCode() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final qrData = await _qrService.generateQRData(
        deviceName: widget.deviceName,
      );

      // Extract IP address from QR data for display
      final qrJson = jsonDecode(qrData);
      final ipAddress = qrJson['ipAddress'] as String?;

      setState(() {
        _qrData = qrData;
        _generatedAt = DateTime.now();
        _isLoading = false;
        _isWaitingForConnection = true;
        _localIpAddress = ipAddress;
        _remainingSeconds = QRConnectionService.qrValidityMinutes * 60;
      });

      _startCountdownTimer();
      _logger.info('QR code generated successfully');
    } catch (e) {
      _logger.error('Failed to generate QR code', e);
      setState(() {
        _errorMessage = 'Failed to generate QR code';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('My QR Code'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareQRCode,
            tooltip: 'Share QR Code',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _generateQRCode,
            tooltip: 'Regenerate QR Code',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Generating QR code...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _generateQRCode,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header with Zapya styling
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(Icons.qr_code, size: 48, color: Colors.white),
                  const SizedBox(height: 12),
                  const Text(
                    'Scan to Connect',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Let others scan this QR code to connect with you instantly',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // QR Code with Zapya styling
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x1A000000),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: QrImageView(
                  data: _qrData!,
                  version: QrVersions.auto,
                  size: 280,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                  embeddedImage: null,
                  embeddedImageStyle: const QrEmbeddedImageStyle(
                    size: Size(40, 40),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Device Info Card with Zapya styling
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Device Information',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildInfoRow(Icons.device_hub, 'Name', widget.deviceName),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.access_time,
                      'Generated',
                      _getTimeAgoString(),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(
                      Icons.timer_outlined,
                      'Expires in',
                      _getExpiryString(),
                    ),
                    if (_localIpAddress != null) ...[
                      const SizedBox(height: 12),
                      _buildInfoRow(Icons.wifi, 'IP Address', _localIpAddress!),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.settings_ethernet,
                        'Port',
                        '${QRConnectionService.defaultPort}',
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          _isWaitingForConnection
                              ? Icons.wifi_tethering
                              : Icons.check_circle,
                          color: _isWaitingForConnection
                              ? Theme.of(context).colorScheme.primary
                              : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isWaitingForConnection
                              ? 'Waiting for connection…'
                              : 'Connected',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Connection History
            if (_connectionHistory.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.history,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Recent Connections',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ..._connectionHistory
                        .take(5)
                        .map(
                          (device) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  device,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),

            if (_connectionHistory.isNotEmpty) const SizedBox(height: 24),

            // Instructions with Zapya styling
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'How to use',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInstructionStep(
                    '1',
                    'Ask the other person to open AirLink',
                  ),
                  const SizedBox(height: 8),
                  _buildInstructionStep(
                    '2',
                    'They tap "Scan QR" on the Discovery page',
                  ),
                  const SizedBox(height: 8),
                  _buildInstructionStep(
                    '3',
                    'They point their camera at this QR code',
                  ),
                  const SizedBox(height: 8),
                  _buildInstructionStep(
                    '4',
                    'Connection will establish automatically!',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
            isActive: false,
            onTap: () => _openQRScanner(),
          ),
          _buildNavItem(
            icon: Icons.qr_code,
            label: 'My QR Code',
            isActive: true,
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

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionStep(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }

  String _getTimeAgoString() {
    if (_generatedAt == null) return 'Just now';

    final duration = DateTime.now().difference(_generatedAt!);

    if (duration.inMinutes < 1) {
      return 'Just now';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}m ago';
    } else {
      return '${duration.inHours}h ${duration.inMinutes % 60}m ago';
    }
  }

  String _getExpiryString() {
    if (_remainingSeconds <= 0) {
      return 'Expired';
    }

    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;

    if (minutes < 1) {
      return '${seconds}s';
    } else {
      return '${minutes}m ${seconds}s';
    }
  }

  /// Add device to connection history (called when connection event is received)
  void _addToConnectionHistory(String deviceName) {
    if (mounted) {
      setState(() {
        final timestamp = DateTime.now();
        final timeStr =
            '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
        _connectionHistory.insert(0, '$deviceName - $timeStr');
        _isWaitingForConnection = false;
      });
    }
  }

  /// Share QR code as image
  Future<void> _shareQRCode() async {
    try {
      // Capture QR code as image
      final RenderRepaintBoundary boundary =
          _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      // Save to temporary file
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/airlink_qr_code.png');
      await file.writeAsBytes(pngBytes);

      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'Scan this QR code to connect with ${widget.deviceName} on AirLink',
      );

      _logger.info('QR code shared successfully');
    } catch (e) {
      _logger.error('Failed to share QR code', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share QR code')),
        );
      }
    }
  }

  Future<void> _openQRScanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EnhancedQRScannerPage()),
    );
  }
}
