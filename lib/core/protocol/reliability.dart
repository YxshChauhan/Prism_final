import 'dart:typed_data';
import 'dart:async';
import 'package:airlink/core/protocol/frame.dart';
import 'package:airlink/core/protocol/protocol_constants.dart';
import 'package:airlink/core/protocol/airlink_protocol_simplified.dart';

/// Sliding Window Reliability Protocol
/// 
/// Implements per-chunk ACK with sliding window for reliable data transfer
class ReliabilityProtocol {
  final int windowSize;
  final int chunkSize;
  final Duration ackTimeout;
  
  // Sliding window state
  final Map<int, ChunkState> _chunks = {};
  final Map<int, Timer> _timers = {};
  int _nextSequenceNumber = 0;
  int _windowStart = 0;
  
  // Callbacks
  final Function(ProtocolFrame) onFrameSend;
  final Function(AckFrame) onAckReceived;
  final Function(int, int) onChunkDelivered;
  AirLinkProtocolSimplified? _protocol;

  ReliabilityProtocol({
    this.windowSize = ProtocolConstants.defaultWindowSize,
    this.chunkSize = ProtocolConstants.defaultChunkSize,
    this.ackTimeout = ProtocolConstants.ackTimeout,
    required this.onFrameSend,
    required this.onAckReceived,
    required this.onChunkDelivered,
  });

  /// Send a chunk with reliability
  Future<void> sendChunk({
    required int transferId,
    required int offset,
    required Uint8List data,
    required Uint8List iv,
    required Uint8List hash,
  }) async {
    final sequenceNumber = _nextSequenceNumber++;
    final frame = ProtocolFrame.data(
      transferId: transferId,
      offset: offset,
      payload: data,
      iv: iv,
      hash: hash,
    );

    // Store chunk state
    _chunks[sequenceNumber] = ChunkState(
      sequenceNumber: sequenceNumber,
      frame: frame,
      isAcked: false,
      isInFlight: true,
      retryCount: 0,
      timestamp: DateTime.now(),
    );

    // Send frame
    onFrameSend(frame);

    // Start ACK timeout timer
    _startAckTimer(sequenceNumber);

    // Check if we can send more chunks
    _updateWindow();
  }

  /// Process received ACK
  void processAck(AckFrame ack) {
    // Find and mark chunk as ACKed
    for (final entry in _chunks.entries) {
      final chunk = entry.value;
      if (chunk.frame.transferId == ack.transferId &&
          chunk.frame.offset == ack.offset &&
          chunk.frame.payloadLength == ack.length) {
        
        chunk.isAcked = true;
        chunk.isInFlight = false;
        
        // Cancel timeout timer
        _timers[chunk.sequenceNumber]?.cancel();
        _timers.remove(chunk.sequenceNumber);
        
        // Notify delivery
        onChunkDelivered(chunk.frame.transferId, chunk.frame.offset);
        
        // Update window
        _updateWindow();
        break;
      }
    }
  }

  /// Retry unacknowledged chunks
  void retryUnacknowledgedChunks() {
    final now = DateTime.now();
    
    for (final entry in _chunks.entries) {
      final chunk = entry.value;
      
      if (!chunk.isAcked && 
          chunk.isInFlight &&
          now.difference(chunk.timestamp) > ackTimeout) {
        
        if (chunk.retryCount < ProtocolConstants.maxRetries) {
          // Retry chunk
          chunk.retryCount++;
          chunk.timestamp = now;
          
          onFrameSend(chunk.frame);
          _startAckTimer(chunk.sequenceNumber);
        } else {
          // Max retries exceeded, mark as failed
          chunk.isInFlight = false;
          _timers[chunk.sequenceNumber]?.cancel();
          _timers.remove(chunk.sequenceNumber);
        }
      }
    }
  }

  /// Update sliding window
  void _updateWindow() {
    // Remove ACKed chunks from window start
    while (_chunks.containsKey(_windowStart) && 
           _chunks[_windowStart]!.isAcked) {
      _chunks.remove(_windowStart);
      _windowStart++;
    }

    // Send more chunks if window has space
    final inFlightCount = _chunks.values
        .where((chunk) => chunk.isInFlight && !chunk.isAcked)
        .length;

    if (inFlightCount < windowSize) {
      // Can send more chunks
      _sendPendingChunks();
    }
  }

  /// Send pending chunks within window
  void _sendPendingChunks() {
    final inFlightCount = _chunks.values
        .where((chunk) => chunk.isInFlight && !chunk.isAcked)
        .length;

    if (inFlightCount >= windowSize) return;

    // Find next chunk to send
    for (int i = _windowStart; i < _nextSequenceNumber; i++) {
      if (!_chunks.containsKey(i)) {
        // This chunk hasn't been sent yet
        // Implementation would depend on having pending chunks
        break;
      }
    }
  }

  /// Start ACK timeout using protocol events
  void _startAckTimer(int sequenceNumber) {
    _timers[sequenceNumber]?.cancel();
    
    // Use protocol events to handle ACK timeouts
    _protocol?.eventStream.listen((event) {
      if (event.type == 'chunk_ack_timeout' && 
          event.data['sequenceNumber'] == sequenceNumber) {
        if (_chunks.containsKey(sequenceNumber)) {
          final chunk = _chunks[sequenceNumber]!;
          if (!chunk.isAcked && chunk.isInFlight) {
            // Retry chunk
            retryUnacknowledgedChunks();
          }
        }
      }
    });
  }

  /// Get transfer statistics
  TransferStats getStats() {
    final totalChunks = _chunks.length;
    final ackedChunks = _chunks.values.where((chunk) => chunk.isAcked).length;
    final inFlightChunks = _chunks.values.where((chunk) => chunk.isInFlight).length;
    final failedChunks = _chunks.values.where((chunk) => 
        !chunk.isAcked && !chunk.isInFlight).length;

    return TransferStats(
      totalChunks: totalChunks,
      ackedChunks: ackedChunks,
      inFlightChunks: inFlightChunks,
      failedChunks: failedChunks,
      windowSize: windowSize,
      windowStart: _windowStart,
    );
  }

  /// Clean up resources
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _chunks.clear();
  }
}

/// Chunk state for reliability tracking
class ChunkState {
  final int sequenceNumber;
  final ProtocolFrame frame;
  bool isAcked;
  bool isInFlight;
  int retryCount;
  DateTime timestamp;

  ChunkState({
    required this.sequenceNumber,
    required this.frame,
    required this.isAcked,
    required this.isInFlight,
    required this.retryCount,
    required this.timestamp,
  });
}

/// Transfer statistics
class TransferStats {
  final int totalChunks;
  final int ackedChunks;
  final int inFlightChunks;
  final int failedChunks;
  final int windowSize;
  final int windowStart;
  
  // Enhanced connection stats
  final int bytesTransferred;
  final int bytesReceived;
  final double transferRate;
  final double averageRTT;
  final double packetLoss;
  final int reconnectionAttempts;
  final bool isConnected;
  final bool isHandshakeComplete;

  const TransferStats({
    required this.totalChunks,
    required this.ackedChunks,
    required this.inFlightChunks,
    required this.failedChunks,
    required this.windowSize,
    required this.windowStart,
    this.bytesTransferred = 0,
    this.bytesReceived = 0,
    this.transferRate = 0.0,
    this.averageRTT = 0.0,
    this.packetLoss = 0.0,
    this.reconnectionAttempts = 0,
    this.isConnected = false,
    this.isHandshakeComplete = false,
  });

  double get successRate {
    if (totalChunks == 0) return 0.0;
    return ackedChunks / totalChunks;
  }

  double get failureRate {
    if (totalChunks == 0) return 0.0;
    return failedChunks / totalChunks;
  }

  @override
  String toString() {
    return 'TransferStats(total: $totalChunks, acked: $ackedChunks, '
           'inFlight: $inFlightChunks, failed: $failedChunks, '
           'successRate: ${(successRate * 100).toStringAsFixed(1)}%)';
  }
}
