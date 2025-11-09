import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/shared/utils/format_utils.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;
import 'package:airlink/features/transfer/presentation/providers/transfer_provider.dart';
import 'package:airlink/core/services/transfer_benchmark.dart';

/// Enhanced transfer widget with SHAREit/Zapya style progress display
class EnhancedTransferWidget extends ConsumerStatefulWidget {
  final String transferId;
  final unified.TransferSession session;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onCancel;
  final VoidCallback? onViewDetails;

  const EnhancedTransferWidget({
    super.key,
    required this.transferId,
    required this.session,
    this.onPause,
    this.onResume,
    this.onCancel,
    this.onViewDetails,
  });

  @override
  ConsumerState<EnhancedTransferWidget> createState() => _EnhancedTransferWidgetState();
}

class _EnhancedTransferWidgetState extends ConsumerState<EnhancedTransferWidget>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            _buildHeader(),
            const SizedBox(height: 12),
            
            // Progress bar
            _buildProgressBar(),
            const SizedBox(height: 12),
            
            // File info
            _buildFileInfo(),
            const SizedBox(height: 12),
            
            // Speed and time info
            _buildSpeedInfo(),
            const SizedBox(height: 12),
            
            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Status icon with animation
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _getStatusColor(),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getStatusIcon(),
                  color: Colors.white,
                  size: 20,
                ),
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        
        // Transfer info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _getStatusText(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: _getStatusColor(),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.session.files.length} file${widget.session.files.length == 1 ? '' : 's'} • ${FormatUtils.formatBytes(_getTotalSize())}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        
        // Transfer method icon
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getMethodIcon(),
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '${(_getProgress() * 100).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: _getProgress(),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(
              _getStatusColor(),
            ),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildFileInfo() {
    if (widget.session.files.isEmpty) return const SizedBox.shrink();
    
    final unified.TransferFile currentFile = widget.session.files.first;
    
    return Consumer(
      builder: (context, ref, child) {
        final progressAsync = ref.watch(transferProgressProvider(widget.transferId));
        
        return progressAsync.when(
          data: (progress) {
            // Use the progress data directly since TransferProgress represents a single file
            final fileProgress = progress;
            
            return Row(
              children: [
                Icon(
                  _getFileIcon(currentFile.mimeType),
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentFile.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '${FormatUtils.formatBytes(fileProgress.bytesTransferred)} / ${FormatUtils.formatBytes(currentFile.size)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          },
          loading: () => Row(
            children: [
              Icon(
                _getFileIcon(currentFile.mimeType),
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentFile.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${FormatUtils.formatBytes(currentFile.bytesTransferred)} / ${FormatUtils.formatBytes(currentFile.size)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          error: (error, stack) => Row(
            children: [
              Icon(
                _getFileIcon(currentFile.mimeType),
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentFile.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${FormatUtils.formatBytes(currentFile.bytesTransferred)} / ${FormatUtils.formatBytes(currentFile.size)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpeedInfo() {
    return Row(
      children: [
        Icon(
          Icons.speed,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        // Use FutureBuilder to get benchmark-based speed when available
        FutureBuilder<double>(
          future: widget.session.files.length > 1 ? _getAggregateSpeedFromBenchmarks() : Future.value(_getCurrentSpeed()),
          builder: (context, snapshot) {
            final speed = snapshot.hasData ? snapshot.data! : _getCurrentSpeed();
            return Text(
              'Speed: ${speed > 0 ? _formatSpeed(speed) : '—'}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            );
          },
        ),
        const SizedBox(width: 16),
        Icon(
          Icons.timer,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          'ETA: ${_getEstimatedTime()}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        if (widget.session.status == unified.TransferStatus.transferring)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onPause,
              icon: const Icon(Icons.pause, size: 16),
              label: const Text('Pause'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        
        if (widget.session.status == unified.TransferStatus.paused) ...[
          Expanded(
            child: FilledButton.icon(
              onPressed: widget.onResume,
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('Resume'),
            ),
          ),
          const SizedBox(width: 8),
        ],
        
        if (widget.session.status == unified.TransferStatus.transferring ||
            widget.session.status == unified.TransferStatus.paused)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onCancel,
              icon: const Icon(Icons.cancel, size: 16),
              label: const Text('Cancel'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        
        if (widget.session.status == unified.TransferStatus.completed ||
            widget.session.status == unified.TransferStatus.failed)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onViewDetails,
              icon: const Icon(Icons.info, size: 16),
              label: const Text('Details'),
            ),
          ),
      ],
    );
  }

  Color _getStatusColor() {
    switch (widget.session.status) {
      case unified.TransferStatus.pending:
        return Colors.orange;
      case unified.TransferStatus.connecting:
        return Colors.blue;
      case unified.TransferStatus.transferring:
        return Colors.blue;
      case unified.TransferStatus.paused:
        return Colors.amber;
      case unified.TransferStatus.completed:
        return Colors.green;
      case unified.TransferStatus.failed:
        return Colors.red;
      case unified.TransferStatus.cancelled:
        return Colors.grey;
      case unified.TransferStatus.handshaking:
        return Colors.purple;
      case unified.TransferStatus.resuming:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon() {
    switch (widget.session.status) {
      case unified.TransferStatus.pending:
        return Icons.schedule;
      case unified.TransferStatus.connecting:
        return Icons.sync;
      case unified.TransferStatus.transferring:
        return Icons.upload;
      case unified.TransferStatus.paused:
        return Icons.pause;
      case unified.TransferStatus.completed:
        return Icons.check_circle;
      case unified.TransferStatus.failed:
        return Icons.error;
      case unified.TransferStatus.cancelled:
        return Icons.cancel;
      case unified.TransferStatus.handshaking:
        return _iconOrFallback(Icons.handshake, Icons.sync_alt);
      case unified.TransferStatus.resuming:
        return Icons.play_arrow;
    }
  }

  String _getStatusText() {
    switch (widget.session.status) {
      case unified.TransferStatus.pending:
        return 'Pending';
      case unified.TransferStatus.connecting:
        return 'Connecting...';
      case unified.TransferStatus.transferring:
        return 'Transferring';
      case unified.TransferStatus.paused:
        return 'Paused';
      case unified.TransferStatus.completed:
        return 'Completed';
      case unified.TransferStatus.failed:
        return 'Failed';
      case unified.TransferStatus.cancelled:
        return 'Cancelled';
      case unified.TransferStatus.handshaking:
        return 'Handshaking...';
      case unified.TransferStatus.resuming:
        return 'Resuming...';
    }
  }

  IconData _getMethodIcon() {
    switch (widget.session.connectionMethod) {
      case 'wifi_aware':
        return Icons.wifi;
      case 'hotspot':
        return Icons.wifi_tethering;
      case 'ble':
        return Icons.bluetooth;
      case 'group':
        return Icons.group;
      default:
        return Icons.wifi;
    }
  }

  IconData _getFileIcon(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.videocam;
    if (mimeType.startsWith('audio/')) return Icons.music_note;
    if (mimeType.startsWith('text/')) return Icons.description;
    return Icons.attach_file;
  }

  double _getProgress() {
    if (widget.session.files.isEmpty) return 0.0;
    
    int totalBytes = 0;
    int transferredBytes = 0;
    
    for (final file in widget.session.files) {
      totalBytes += file.size;
      transferredBytes += file.bytesTransferred;
    }
    
    return totalBytes > 0 ? transferredBytes / totalBytes : 0.0;
  }

  int _getTotalSize() {
    return widget.session.files.fold(0, (sum, file) => sum + file.size);
  }

  double _getCurrentSpeed() {
    // Get current speed from transfer progress provider
    final progressAsync = ref.watch(transferProgressProvider(widget.transferId));
    
    return progressAsync.when(
      data: (progress) => progress.speed,
      loading: () => 0.0,
      error: (_, __) => 0.0,
    );
  }

  String _getEstimatedTime() {
    // For multi-file sessions, use smoothed aggregate speed
    final double aggregateSpeed = _getSmoothedAggregateSpeed();
    if (aggregateSpeed <= 0) return '—'; // Use em dash to indicate not available
    
    final int remainingBytes = _getTotalSize() - widget.session.files.fold(0, (sum, file) => sum + file.bytesTransferred);
    if (remainingBytes <= 0) return 'Complete';
    
    final int seconds = (remainingBytes / aggregateSpeed).round();
    
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${(seconds / 60).round()}m';
    return '${(seconds / 3600).round()}h';
  }

  /// Calculate smoothed aggregate speed for multi-file sessions
  /// Pulls rolling/aggregate speed from repository or benchmarking service when available.
  /// Falls back to current speed otherwise.
  double _getSmoothedAggregateSpeed() {
    // Get current speed from transfer progress
    final double currentSpeed = _getCurrentSpeed();
    
    // For single file, use current speed directly
    if (widget.session.files.length == 1) {
      return currentSpeed;
    }
    
    // For multi-file sessions, calculate aggregate speed using session data
    // This provides a more accurate estimate than just current speed
    final int transferredBytes = widget.session.files.fold(0, (sum, file) => sum + file.bytesTransferred);
    
    if (transferredBytes <= 0) return currentSpeed;
    
    // Calculate time elapsed (approximate)
    final DateTime? startTime = widget.session.createdAt;
    if (startTime == null) return currentSpeed;
    
    final Duration elapsed = DateTime.now().difference(startTime);
    if (elapsed.inSeconds <= 0) return currentSpeed;
    
    // Calculate average speed over the entire session
    final double sessionAverageSpeed = transferredBytes / elapsed.inSeconds;
    
    // Use a weighted average: 70% current speed, 30% session average
    // This provides a smoother estimate that considers both current performance and overall session progress
    return (currentSpeed * 0.7) + (sessionAverageSpeed * 0.3);
  }

  /// Get aggregate speed from benchmarking service for more accurate estimates
  /// This method can be called asynchronously to get benchmark-based speed estimates
  Future<double> _getAggregateSpeedFromBenchmarks() async {
    try {
      final repository = ref.read(transferRepositoryProvider);
      
      // Get benchmarks for all files in this session
      final List<TransferBenchmark?> benchmarks = await Future.wait(
        widget.session.files.map((file) {
          return repository.getTransferBenchmark('${widget.session.id}_${file.id}');
        }),
      );
      
      // Calculate aggregate speed from benchmarks if available
      final validBenchmarks = benchmarks.where((b) => b != null && b.averageSpeed > 0).cast<TransferBenchmark>().toList();
      
      if (validBenchmarks.isNotEmpty) {
        // Calculate weighted average based on file sizes
        double totalWeightedSpeed = 0.0;
        int totalWeight = 0;
        
        for (final benchmark in validBenchmarks) {
          final weight = benchmark.fileSize;
          totalWeightedSpeed += benchmark.averageSpeed * weight;
          totalWeight += weight;
        }
        
        if (totalWeight > 0) {
          return totalWeightedSpeed / totalWeight;
        }
      }
      
      // Fallback to current speed if no valid benchmarks or repository doesn't support benchmarks
      return _getCurrentSpeed();
      
    } catch (e) {
      // If benchmark lookup fails, fall back to current speed
      return _getCurrentSpeed();
    }
  }


  String _formatSpeed(double speed) {
    if (speed < 1024) return '${speed.toStringAsFixed(0)} B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    if (speed < 1024 * 1024 * 1024) return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    return '${(speed / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB/s';
  }

  /// Fallback icon method to handle potential Material icon availability issues
  IconData _iconOrFallback(IconData primary, IconData fallback) {
    try {
      // Try to use the primary icon, fallback if not available
      return primary;
    } catch (e) {
      return fallback;
    }
  }
}
