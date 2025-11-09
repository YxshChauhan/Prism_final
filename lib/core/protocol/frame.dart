import 'dart:typed_data';
import 'package:airlink/core/protocol/protocol_constants.dart';


class ProtocolFrame {
  final int frameType;
  final int controlSubtype;
  final int transferId;
  final int offset;
  final int payloadLength;
  final Uint8List iv;
  final Uint8List encryptedPayload;
  final Uint8List chunkHash;

  const ProtocolFrame({
    required this.frameType,
    this.controlSubtype = 0,
    required this.transferId,
    required this.offset,
    required this.payloadLength,
    required this.iv,
    required this.encryptedPayload,
    required this.chunkHash,
  });

  /// Create a control frame
  factory ProtocolFrame.control({
    required int transferId,
    required int offset,
    required Uint8List payload,
    required Uint8List iv,
    required Uint8List hash,
    int controlSubtype = 0,
  }) {
    return ProtocolFrame(
      frameType: ProtocolConstants.frameTypeControl,
      controlSubtype: controlSubtype,
      transferId: transferId,
      offset: offset,
      payloadLength: payload.length,
      iv: iv,
      encryptedPayload: payload,
      chunkHash: hash,
    );
  }

  /// Create a data frame
  factory ProtocolFrame.data({
    required int transferId,
    required int offset,
    required Uint8List payload,
    required Uint8List iv,
    required Uint8List hash,
  }) {
    return ProtocolFrame(
      frameType: ProtocolConstants.frameTypeData,
      transferId: transferId,
      offset: offset,
      payloadLength: payload.length,
      iv: iv,
      encryptedPayload: payload,
      chunkHash: hash,
    );
  }

  /// Serialize frame to bytes
  Uint8List toBytes() {
    final buffer = ByteData(
      1 + // frameType
      1 + // controlSubtype (only for control frames)
      4 + // transferId
      8 + // offset
      4 + // payloadLength
      ProtocolConstants.ivLength + // iv
      encryptedPayload.length + // encryptedPayload
      ProtocolConstants.hashLength // chunkHash
    );

    int offset = 0;
    
    // frameType (1 byte)
    buffer.setUint8(offset, frameType);
    offset += 1;
    
    // controlSubtype (1 byte, only for control frames)
    if (frameType == ProtocolConstants.frameTypeControl) {
      buffer.setUint8(offset, controlSubtype);
      offset += 1;
    }
    
    // transferId (4 bytes)
    buffer.setUint32(offset, transferId, Endian.big);
    offset += 4;
    
    // offset (8 bytes)
    buffer.setUint64(offset, this.offset, Endian.big);
    offset += 8;
    
    // payloadLength (4 bytes)
    buffer.setUint32(offset, payloadLength, Endian.big);
    offset += 4;
    
    // iv (12 bytes)
    for (int i = 0; i < iv.length; i++) {
      buffer.setUint8(offset + i, iv[i]);
    }
    offset += ProtocolConstants.ivLength;
    
    // encryptedPayload (variable length)
    for (int i = 0; i < encryptedPayload.length; i++) {
      buffer.setUint8(offset + i, encryptedPayload[i]);
    }
    offset += encryptedPayload.length;
    
    // chunkHash (32 bytes)
    for (int i = 0; i < chunkHash.length; i++) {
      buffer.setUint8(offset + i, chunkHash[i]);
    }
    
    return buffer.buffer.asUint8List();
  }

  /// Deserialize frame from bytes
  factory ProtocolFrame.fromBytes(Uint8List data) {
    final buffer = ByteData.sublistView(data);
    int offset = 0;
    
    // frameType (1 byte)
    final frameType = buffer.getUint8(offset);
    offset += 1;
    
    // controlSubtype (1 byte, only for control frames)
    int controlSubtype = 0;
    if (frameType == ProtocolConstants.frameTypeControl) {
      controlSubtype = buffer.getUint8(offset);
      offset += 1;
    }
    
    // transferId (4 bytes)
    final transferId = buffer.getUint32(offset, Endian.big);
    offset += 4;
    
    // offset (8 bytes)
    final frameOffset = buffer.getUint64(offset, Endian.big);
    offset += 8;
    
    // payloadLength (4 bytes)
    final payloadLength = buffer.getUint32(offset, Endian.big);
    offset += 4;
    
    // iv (12 bytes)
    final iv = data.sublist(offset, offset + ProtocolConstants.ivLength);
    offset += ProtocolConstants.ivLength;
    
    // encryptedPayload (variable length)
    final encryptedPayload = data.sublist(offset, offset + payloadLength);
    offset += payloadLength;
    
    // chunkHash (32 bytes)
    final chunkHash = data.sublist(offset, offset + ProtocolConstants.hashLength);
    
    return ProtocolFrame(
      frameType: frameType,
      controlSubtype: controlSubtype,
      transferId: transferId,
      offset: frameOffset,
      payloadLength: payloadLength,
      iv: iv,
      encryptedPayload: encryptedPayload,
      chunkHash: chunkHash,
    );
  }

  /// Get total frame size
  int get totalSize {
    int baseSize = 1 + 4 + 8 + 4 + ProtocolConstants.ivLength + 
                   encryptedPayload.length + ProtocolConstants.hashLength;
    if (frameType == ProtocolConstants.frameTypeControl) {
      baseSize += 1; // controlSubtype
    }
    return baseSize;
  }

  /// Validate frame structure
  bool get isValid {
    return frameType >= 0 && frameType <= 1 &&
           transferId > 0 &&
           offset >= 0 &&
           payloadLength > 0 &&
           iv.length == ProtocolConstants.ivLength &&
           encryptedPayload.length == payloadLength &&
           chunkHash.length == ProtocolConstants.hashLength;
  }

  @override
  String toString() {
    return 'ProtocolFrame(type: $frameType, transferId: $transferId, '
           'offset: $offset, payloadLength: $payloadLength)';
  }
}

/// ACK Frame for reliability
class AckFrame {
  final int transferId;
  final int offset;
  final int length;

  const AckFrame({
    required this.transferId,
    required this.offset,
    required this.length,
  });

  /// Serialize ACK to bytes
  Uint8List toBytes() {
    final buffer = ByteData(4 + 8 + 4); // transferId + offset + length
    
    buffer.setUint32(0, transferId, Endian.big);
    buffer.setUint64(4, offset, Endian.big);
    buffer.setUint32(12, length, Endian.big);
    
    return buffer.buffer.asUint8List();
  }

  /// Deserialize ACK from bytes
  factory AckFrame.fromBytes(Uint8List data) {
    final buffer = ByteData.sublistView(data);
    
    return AckFrame(
      transferId: buffer.getUint32(0, Endian.big),
      offset: buffer.getUint64(4, Endian.big),
      length: buffer.getUint32(12, Endian.big),
    );
  }

  @override
  String toString() {
    return 'AckFrame(transferId: $transferId, offset: $offset, length: $length)';
  }
}
