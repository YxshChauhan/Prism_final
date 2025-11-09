import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/features/transfer/presentation/providers/transfer_provider.dart';
import 'package:airlink/core/services/error_handling_service.dart';
import 'package:airlink/core/services/performance_optimization_service.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;


class EnhancedTransferProgressWidget extends ConsumerStatefulWidget {
  final String transferId;
  final unified.TransferFile file;
  
  const EnhancedTransferProgressWidget({
    super.key,
    required this.transferId,
    required this.file,
  });

  @override
  ConsumerState<EnhancedTransferProgressWidget> createState() => _EnhancedTransferProgressWidgetState();
}

class _EnhancedTransferProgressWidgetState extends ConsumerState<EnhancedTransferProgressWidget> {
  final ErrorHandlingService _errorHandlingService = ErrorHandlingService();
  final PerformanceOptimizationService _performanceService = PerformanceOptimizationService();
  
  Map<String, dynamic>? _performanceStats;
  
  @override
  void initState() {
    super.initState();
    _loadPerformanceStats();
  }
  
  void _loadPerformanceStats() {
    final stats = _performanceService.getPerformanceStatistics();
    if (stats.isNotEmpty) {
      setState(() {
        _performanceStats = stats;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final progressStream = ref.watch(transferProgressProvider(widget.transferId));
    
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File info header
            _buildFileHeader(),
            const SizedBox(height: 16),
            
            // Progress stream
            progressStream.when(
              data: (progress) => _buildProgressContent(progress),
              loading: () => _buildLoadingContent(),
              error: (error, stack) => _buildErrorContent(error),
            ),
            
            // Performance stats (if available)
            if (_performanceStats != null) ...[
              const SizedBox(height: 16),
              _buildPerformanceStats(),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildFileHeader() {
    return Row(
      children: [
        Icon(
          _getFileIcon(),
          size: 24,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.file.name,
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _formatFileSize(widget.file.size),
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        _buildTransferActions(),
      ],
    );
  }
  
  Widget _buildTransferActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.pause),
          onPressed: () => _pauseTransfer(),
          tooltip: 'Pause Transfer',
        ),
        IconButton(
          icon: const Icon(Icons.cancel),
          onPressed: () => _cancelTransfer(),
          tooltip: 'Cancel Transfer',
        ),
      ],
    );
  }
  
  Widget _buildProgressContent(unified.TransferProgress progress) {
    final percentage = (progress.bytesTransferred / progress.totalBytes * 100).round();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        LinearProgressIndicator(
          value: progress.bytesTransferred / progress.totalBytes,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation<Color>(
            Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        
        // Progress text
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_formatFileSize(progress.bytesTransferred)} / ${_formatFileSize(progress.totalBytes)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              '$percentage%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        
        // Transfer speed (if available)
        if (_performanceStats != null) ...[
          const SizedBox(height: 4),
          _buildTransferSpeed(),
        ],
      ],
    );
  }
  
  Widget _buildLoadingContent() {
    return const Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 12),
        Text('Preparing transfer...'),
      ],
    );
  }
  
  Widget _buildErrorContent(dynamic error) {
    // Get user-friendly error message and recovery suggestions locally
    final errorMessage = _errorHandlingService.getUserFriendlyMessage(error, 'file_transfer');
    final suggestions = _errorHandlingService.getRecoverySuggestions(error, 'file_transfer');
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                errorMessage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _retryTransfer(),
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
        // Show recovery suggestions inline if available
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 8),
          ExpansionTile(
            title: const Text('Recovery Suggestions'),
            children: [
              ...suggestions.map((suggestion) => ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: Text(suggestion),
              )).toList(),
            ],
          ),
        ],
      ],
    );
  }
  
  Widget _buildPerformanceStats() {
    return ExpansionTile(
      title: const Text('Performance Statistics'),
      children: [
        if (_performanceStats != null)
          ..._performanceStats!.entries.map((entry) {
            final operation = entry.key;
            final stats = entry.value as Map<String, dynamic>;
            
            return ListTile(
              title: Text(operation.replaceAll('_', ' ').toUpperCase()),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Operations: ${stats['totalOperations']}'),
                  Text('Avg Duration: ${stats['averageDuration']}ms'),
                  Text('Avg Throughput: ${_formatThroughput(stats['averageThroughput'])}'),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }
  
  
  Widget _buildTransferSpeed() {
    // Calculate current transfer speed from performance stats
    if (_performanceStats != null && _performanceStats!['file_transfer'] != null) {
      final stats = _performanceStats!['file_transfer'] as Map<String, dynamic>;
      final avgThroughput = stats['averageThroughput'] as double;
      
      return Text(
        'Speed: ${_formatThroughput(avgThroughput)}/s',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    
    return const SizedBox.shrink();
  }
  
  IconData _getFileIcon() {
    final extension = widget.file.name.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audio_file;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
  
  String _formatThroughput(double bytesPerSecond) {
    if (bytesPerSecond < 1024) return '${bytesPerSecond.toStringAsFixed(0)} B';
    if (bytesPerSecond < 1024 * 1024) return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB';
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  
  void _pauseTransfer() {
    ref.read(transferControllerProvider).pauseTransfer(widget.transferId);
  }
  
  void _cancelTransfer() {
    ref.read(transferControllerProvider).cancelTransfer(widget.transferId);
  }
  
  void _retryTransfer() {
    // Retry the transfer
    ref.read(transferControllerProvider).resumeTransfer(widget.transferId);
  }
}
