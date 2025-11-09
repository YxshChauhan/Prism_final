import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:airlink/core/protocol/frame.dart';
import 'package:airlink/core/protocol/protocol_constants.dart';

void main() {
  group('ACK Detection Tests', () {
    test('ACK frame should be detected by control subtype, not payload length', () {
      // Create an ACK frame with explicit subtype
      final ackFrame = ProtocolFrame.control(
        transferId: 123,
        offset: 456,
        payload: Uint8List(12), // 12 bytes payload
        iv: Uint8List(ProtocolConstants.ivLength),
        hash: Uint8List(ProtocolConstants.hashLength),
        controlSubtype: ProtocolConstants.controlSubtypeAck,
      );
      
      // Verify it's detected as ACK by subtype
      expect(ackFrame.controlSubtype, equals(ProtocolConstants.controlSubtypeAck));
      expect(ackFrame.frameType, equals(ProtocolConstants.frameTypeControl));
    });
    
    test('Non-ACK control frame with same payload length should not be misclassified', () {
      // Create a non-ACK control frame with 12-byte payload
      final discoveryFrame = ProtocolFrame.control(
        transferId: 0,
        offset: 0,
        payload: Uint8List(12), // Same payload length as ACK
        iv: Uint8List(ProtocolConstants.ivLength),
        hash: Uint8List(ProtocolConstants.hashLength),
        controlSubtype: ProtocolConstants.controlSubtypeDiscovery,
      );
      
      // Verify it's NOT detected as ACK
      expect(discoveryFrame.controlSubtype, equals(ProtocolConstants.controlSubtypeDiscovery));
      expect(discoveryFrame.controlSubtype, isNot(equals(ProtocolConstants.controlSubtypeAck)));
    });
    
    test('Frame serialization and deserialization should preserve control subtype', () {
      final originalFrame = ProtocolFrame.control(
        transferId: 789,
        offset: 101112,
        payload: Uint8List(8),
        iv: Uint8List(ProtocolConstants.ivLength),
        hash: Uint8List(ProtocolConstants.hashLength),
        controlSubtype: ProtocolConstants.controlSubtypeKeyExchange,
      );
      
      // Serialize and deserialize
      final frameBytes = originalFrame.toBytes();
      final deserializedFrame = ProtocolFrame.fromBytes(frameBytes);
      
      // Verify control subtype is preserved
      expect(deserializedFrame.controlSubtype, equals(originalFrame.controlSubtype));
      expect(deserializedFrame.controlSubtype, equals(ProtocolConstants.controlSubtypeKeyExchange));
    });
  });
}
