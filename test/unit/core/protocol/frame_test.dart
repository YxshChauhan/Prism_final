import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:airlink/core/protocol/frame.dart';
import 'package:airlink/core/protocol/protocol_constants.dart';

void main() {
  group('ProtocolFrame Tests', () {
    test('should create control frame correctly', () {
      final payload = Uint8List.fromList([1, 2, 3, 4]);
      final iv = Uint8List.fromList(List.generate(12, (i) => i));
      final hash = Uint8List.fromList(List.generate(32, (i) => i));
      
      final frame = ProtocolFrame.control(
        transferId: 123,
        offset: 0,
        payload: payload,
        iv: iv,
        hash: hash,
      );
      
      expect(frame.frameType, equals(ProtocolConstants.frameTypeControl));
      expect(frame.transferId, equals(123));
      expect(frame.offset, equals(0));
      expect(frame.payloadLength, equals(4));
      expect(frame.encryptedPayload, equals(payload));
      expect(frame.iv, equals(iv));
      expect(frame.chunkHash, equals(hash));
    });

    test('should create data frame correctly', () {
      final payload = Uint8List.fromList([5, 6, 7, 8, 9]);
      final iv = Uint8List.fromList(List.generate(12, (i) => i + 1));
      final hash = Uint8List.fromList(List.generate(32, (i) => i + 2));
      
      final frame = ProtocolFrame.data(
        transferId: 456,
        offset: 1024,
        payload: payload,
        iv: iv,
        hash: hash,
      );
      
      expect(frame.frameType, equals(ProtocolConstants.frameTypeData));
      expect(frame.transferId, equals(456));
      expect(frame.offset, equals(1024));
      expect(frame.payloadLength, equals(5));
      expect(frame.encryptedPayload, equals(payload));
      expect(frame.iv, equals(iv));
      expect(frame.chunkHash, equals(hash));
    });

    test('should serialize and deserialize correctly', () {
      final payload = Uint8List.fromList([1, 2, 3, 4, 5]);
      final iv = Uint8List.fromList(List.generate(12, (i) => i));
      final hash = Uint8List.fromList(List.generate(32, (i) => i));
      
      final originalFrame = ProtocolFrame.control(
        transferId: 789,
        offset: 2048,
        payload: payload,
        iv: iv,
        hash: hash,
      );
      
      final serialized = originalFrame.toBytes();
      final deserializedFrame = ProtocolFrame.fromBytes(serialized);
      
      expect(deserializedFrame.frameType, equals(originalFrame.frameType));
      expect(deserializedFrame.transferId, equals(originalFrame.transferId));
      expect(deserializedFrame.offset, equals(originalFrame.offset));
      expect(deserializedFrame.payloadLength, equals(originalFrame.payloadLength));
      expect(deserializedFrame.iv, equals(originalFrame.iv));
      expect(deserializedFrame.encryptedPayload, equals(originalFrame.encryptedPayload));
      expect(deserializedFrame.chunkHash, equals(originalFrame.chunkHash));
    });

    test('should handle empty payload', () {
      final payload = Uint8List(0);
      final iv = Uint8List.fromList(List.generate(12, (i) => i));
      final hash = Uint8List.fromList(List.generate(32, (i) => i));
      
      final frame = ProtocolFrame.control(
        transferId: 999,
        offset: 0,
        payload: payload,
        iv: iv,
        hash: hash,
      );
      
      expect(frame.payloadLength, equals(0));
      expect(frame.encryptedPayload, equals(payload));
    });

    test('should handle large payload', () {
      final payload = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      final iv = Uint8List.fromList(List.generate(12, (i) => i));
      final hash = Uint8List.fromList(List.generate(32, (i) => i));
      
      final frame = ProtocolFrame.data(
        transferId: 1000,
        offset: 0,
        payload: payload,
        iv: iv,
        hash: hash,
      );
      
      expect(frame.payloadLength, equals(1000));
      expect(frame.encryptedPayload, equals(payload));
    });
  });
}