import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/core/errors/error_boundary.dart';
import 'package:airlink/features/transfer/presentation/providers/transfer_provider.dart';
import 'package:airlink/shared/providers/app_providers.dart';
import 'package:airlink/core/services/transfer_benchmark.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;
import 'package:share_plus/share_plus.dart';

/// Transfer history page showing completed and failed transfers
class TransferHistoryPage extends ConsumerStatefulWidget {
  const TransferHistoryPage({super.key});

  @override
  ConsumerState<TransferHistoryPage> createState() => _TransferHistoryPageState();
}

class _TransferHistoryPageState extends ConsumerState<TransferHistoryPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  // Filter and sort state
  String _selectedConnectionMethod = 'All';
  String _selectedStatus = 'All';
  String _selectedSortBy = 'Date';
  bool _sortAscending = false;
  DateTimeRange? _dateRange;
  
  // Connection method mapping for UI labels vs internal values
  static const Map<String, String?> _connectionMethodMap = {
    'All': null,
    'Wi-Fi Aware': 'wifi_aware',
    'BLE': 'ble',
    'Multipeer': 'multipeer'
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Transfer History'),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: _showFilterDialog,
              tooltip: 'Filter & Sort',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.share),
              tooltip: 'Export Benchmarks',
              onSelected: (value) {
                if (value == 'json') {
                  _exportBenchmarksAsJson();
                } else if (value == 'csv') {
                  _exportBenchmarksAsCsv();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'json',
                  child: Row(
                    children: [
                      Icon(Icons.code),
                      SizedBox(width: 8),
                      Text('Export as JSON'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'csv',
                  child: Row(
                    children: [
                      Icon(Icons.table_chart),
                      SizedBox(width: 8),
                      Text('Export as CSV'),
                    ],
                  ),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'All'),
              Tab(text: 'Sent'),
              Tab(text: 'Received'),
            ],
          ),
        ),
        body: Column(
          children: [
            _buildBenchmarkSummary(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAllTransfers(),
                  _buildSentTransfers(),
                  _buildReceivedTransfers(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllTransfers() {
    final transferHistory = ref.watch(transferHistoryProvider);
    return transferHistory.when(
      data: (transfers) => _buildTransferList(_applyFiltersAndSort(transfers)),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(error.toString()),
    );
  }

  Widget _buildSentTransfers() {
    final transferHistory = ref.watch(transferHistoryProvider);
    return transferHistory.when(
      data: (transfers) => _buildTransferList(_applyFiltersAndSort(transfers.where((t) => t.direction == unified.TransferDirection.sent).toList())),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(error.toString()),
    );
  }

  Widget _buildReceivedTransfers() {
    final transferHistory = ref.watch(transferHistoryProvider);
    return transferHistory.when(
      data: (transfers) => _buildTransferList(_applyFiltersAndSort(transfers.where((t) => t.direction == unified.TransferDirection.received).toList())),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(error.toString()),
    );
  }

  Widget _buildTransferList(List<unified.TransferSession> transfers) {
    if (transfers.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: transfers.length,
      itemBuilder: (context, index) {
        final transfer = transfers[index];
        return _buildTransferCard(transfer);
      },
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            'No transfers yet',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your transfer history will appear here',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenchmarkSummary() {
    final benchmarkData = ref.watch(transferBenchmarksProvider);
    
    return benchmarkData.when(
      data: (report) {
        final totalTransfers = report['total_transfers'] ?? 0;
        final successRate = report['success_rate'] ?? 0.0;
        final averageSpeed = report['average_speed'] ?? 0.0;
        
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transfer Statistics',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem('Total', '$totalTransfers'),
                  ),
                  Expanded(
                    child: _buildStatItem('Success Rate', '${(successRate * 100).toStringAsFixed(1)}%'),
                  ),
                  Expanded(
                    child: _buildStatItem('Avg Speed', _formatSpeed(averageSpeed)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error loading transfers: $error'),
        ],
      ),
    );
  }

  Future<void> _exportBenchmarksAsJson() async {
    try {
      final benchmarkingService = ref.read(transferBenchmarkingServiceProvider);
      final jsonData = await benchmarkingService.exportBenchmarksAsJson();
      await Share.share(jsonData, subject: 'AirLink Transfer Benchmarks (JSON)');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export benchmarks as JSON: $e')),
        );
      }
    }
  }

  Future<void> _exportBenchmarksAsCsv() async {
    try {
      final benchmarkingService = ref.read(transferBenchmarkingServiceProvider);
      final csvData = await benchmarkingService.exportBenchmarksAsCsv();
      await Share.share(csvData, subject: 'AirLink Transfer Benchmarks (CSV)');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export benchmarks as CSV: $e')),
        );
      }
    }
  }

  Widget _buildTransferCard(unified.TransferSession transfer) {
    final theme = Theme.of(context);
    final isCompleted = transfer.status == unified.TransferStatus.completed;
    final isFailed = transfer.status == unified.TransferStatus.failed;
    final fileName = transfer.files.isNotEmpty ? transfer.files.first.name : 'Unknown';
    final totalSize = transfer.files.fold<int>(0, (sum, file) => sum + file.size);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted 
              ? Colors.green.withValues(alpha: 0.3)
              : isFailed 
                  ? Colors.red.withValues(alpha: 0.3)
                  : Colors.grey.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getStatusColor(transfer.status).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getStatusIcon(transfer.status),
              color: _getStatusColor(transfer.status),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${transfer.files.length} file${transfer.files.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatFileSize(totalSize),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted 
                      ? Colors.green.withValues(alpha: 0.1)
                      : isFailed 
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusText(transfer.status),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isCompleted 
                        ? Colors.green
                        : isFailed 
                            ? Colors.red
                            : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatDateTime(transfer.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(unified.TransferStatus status) {
    switch (status) {
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
        return Colors.teal;
    }
  }

  IconData _getStatusIcon(unified.TransferStatus status) {
    switch (status) {
      case unified.TransferStatus.pending:
        return Icons.schedule;
      case unified.TransferStatus.connecting:
        return Icons.sync;
      case unified.TransferStatus.transferring:
        return Icons.sync;
      case unified.TransferStatus.paused:
        return Icons.pause_circle;
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

  String _getStatusText(unified.TransferStatus status) {
    switch (status) {
      case unified.TransferStatus.pending:
        return 'Pending';
      case unified.TransferStatus.connecting:
        return 'Connecting';
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
        return 'Handshaking';
      case unified.TransferStatus.resuming:
        return 'Resuming';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatSpeed(double speed) {
    if (speed < 1024) return '${speed.toStringAsFixed(0)} B/s';
    if (speed < 1024 * 1024) return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
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

  // Removed provider reads inside comparator; speed resolved via precomputed map in _applyFiltersAndSort

  /// Apply filters and sorting to transfer list
  List<unified.TransferSession> _applyFiltersAndSort(List<unified.TransferSession> transfers) {
    var filteredTransfers = transfers;

    // Apply connection method filter
    if (_selectedConnectionMethod != 'All') {
      final methodKey = _connectionMethodMap[_selectedConnectionMethod];
      if (methodKey != null) {
        filteredTransfers = filteredTransfers.where((transfer) {
          return transfer.connectionMethod == methodKey;
        }).toList();
      }
    }

    // Apply status filter
    if (_selectedStatus != 'All') {
      filteredTransfers = filteredTransfers.where((transfer) {
        return transfer.status.name.toLowerCase() == _selectedStatus.toLowerCase();
      }).toList();
    }

    // Apply date range filter
    if (_dateRange != null) {
      filteredTransfers = filteredTransfers.where((transfer) {
        return transfer.createdAt.isAfter(_dateRange!.start) && 
               transfer.createdAt.isBefore(_dateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // Build speed map once to avoid provider reads in comparator
    final speedMap = <String, double>{};
    try {
      final data = ref.read(transferBenchmarksCombinedProvider).maybeWhen(
        data: (d) => d,
        orElse: () => null,
      );
      if (data != null) {
        final List<TransferBenchmark> benchmarks = (data['benchmarks'] as List<TransferBenchmark>);
        for (final b in benchmarks) {
          speedMap[b.transferId] = b.averageSpeed;
        }
      }
    } catch (_) {}

    // Apply sorting
    switch (_selectedSortBy) {
      case 'Date':
        filteredTransfers.sort((a, b) => _sortAscending 
            ? a.createdAt.compareTo(b.createdAt)
            : b.createdAt.compareTo(a.createdAt));
        break;
      case 'Size':
        filteredTransfers.sort((a, b) {
          final aSize = a.files.fold<int>(0, (sum, file) => sum + file.size);
          final bSize = b.files.fold<int>(0, (sum, file) => sum + file.size);
          return _sortAscending 
              ? aSize.compareTo(bSize)
              : bSize.compareTo(aSize);
        });
        break;
      case 'Speed':
        // Sort by precomputed benchmark map if available, otherwise fall back to bytesTransferred
        double resolveSpeed(unified.TransferSession t) {
          // match on prefix of transfer id
          final entry = speedMap.entries.firstWhere(
            (e) => t.id.isNotEmpty && e.key.startsWith(t.id),
            orElse: () => const MapEntry<String, double>('', -1),
          );
          if (entry.value >= 0) return entry.value;
          return t.bytesTransferred.toDouble();
        }
        filteredTransfers.sort((a, b) {
          final aSpeed = resolveSpeed(a);
          final bSpeed = resolveSpeed(b);
          return _sortAscending 
              ? aSpeed.compareTo(bSpeed)
              : bSpeed.compareTo(aSpeed);
        });
        break;
    }

    return filteredTransfers;
  }

  /// Show filter and sort dialog
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Filter & Sort'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Connection Method Filter
                DropdownButtonFormField<String>(
                  initialValue: _selectedConnectionMethod,
                  decoration: const InputDecoration(
                    labelText: 'Connection Method',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All')),
                    DropdownMenuItem(value: 'Wi-Fi Aware', child: Text('Wi-Fi Aware')),
                    DropdownMenuItem(value: 'BLE', child: Text('BLE')),
                    DropdownMenuItem(value: 'Multipeer', child: Text('Multipeer')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedConnectionMethod = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Status Filter
                DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All')),
                    DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'Failed', child: Text('Failed')),
                    DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Sort By
                DropdownButtonFormField<String>(
                  initialValue: _selectedSortBy,
                  decoration: const InputDecoration(
                    labelText: 'Sort By',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Date', child: Text('Date')),
                    DropdownMenuItem(value: 'Size', child: Text('Size')),
                    DropdownMenuItem(value: 'Speed', child: Text('Speed')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedSortBy = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                
                // Sort Order
                Row(
                  children: [
                    Checkbox(
                      value: _sortAscending,
                      onChanged: (value) {
                        setState(() {
                          _sortAscending = value!;
                        });
                      },
                    ),
                    const Text('Ascending'),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Date Range
                ListTile(
                  title: const Text('Date Range'),
                  subtitle: Text(_dateRange == null 
                      ? 'No date filter' 
                      : '${_dateRange!.start.day}/${_dateRange!.start.month} - ${_dateRange!.end.day}/${_dateRange!.end.month}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (range != null) {
                      setState(() {
                        _dateRange = range;
                      });
                    }
                  },
                ),
                
                // Clear Filters
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedConnectionMethod = 'All';
                      _selectedStatus = 'All';
                      _selectedSortBy = 'Date';
                      _sortAscending = false;
                      _dateRange = null;
                    });
                  },
                  child: const Text('Clear Filters'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  // Update the main widget state
                });
                Navigator.of(context).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}