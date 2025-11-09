import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../../../transfer_engine/chunker.dart';

void main() {
  group('FileChunker Tests', () {
    late FileChunker chunker;
    late File testFile;
    
    setUp(() async {
      // Create a temporary test file
      testFile = File('test_file.txt');
      await testFile.writeAsString('Hello World! This is a test file for chunking.');
      
      chunker = FileChunker(
        file: testFile,
        fileId: 'test-file-1',
        chunkSize: 10, // Small chunk size for testing
      );
    });

    tearDown(() async {
      // Clean up test file
      if (await testFile.exists()) {
        await testFile.delete();
      }
    });

    test('should get chunk count correctly', () async {
      final chunkCount = await chunker.getChunkCount();
      expect(chunkCount, greaterThan(0));
    });

    test('should get chunk at specific index', () async {
      final chunk = await chunker.getChunk(0);
      expect(chunk, isNotNull);
      expect(chunk!.fileId, equals('test-file-1'));
      expect(chunk.chunkIndex, equals(0));
      expect(chunk.data, isNotEmpty);
    });

    test('should handle out of range chunk index', () async {
      final chunk = await chunker.getChunk(999); // Large index
      expect(chunk, isNull);
    });

    test('should get all chunks for file', () async {
      final chunks = await chunker.getAllChunks();
      expect(chunks, isNotEmpty);
      expect(chunks.length, equals(await chunker.getChunkCount()));
    });

    test('should handle chunk with correct properties', () async {
      final chunk = await chunker.getChunk(0);
      expect(chunk, isNotNull);
      expect(chunk!.fileId, equals('test-file-1'));
      expect(chunk.chunkIndex, equals(0));
      expect(chunk.data, isNotEmpty);
      expect(chunk.timestamp, isA<DateTime>());
    });

    test('should handle last chunk correctly', () async {
      final chunkCount = await chunker.getChunkCount();
      final lastChunk = await chunker.getChunk(chunkCount - 1);
      
      if (lastChunk != null) {
        expect(lastChunk.isLastChunk, isTrue);
      }
    });
  });
}
