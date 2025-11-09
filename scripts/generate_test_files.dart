#!/usr/bin/env dart

import 'dart:io';
import 'dart:math';

void main(List<String> args) async {
  print('🚀 AirLink Test File Generator\n');

  final category = _parseCategory(args);
  final customSize = _parseCustomSize(args);

  if (customSize != null) {
    await _generateCustomFile(customSize);
    return;
  }

  switch (category) {
    case 'small':
      await _generateSmallFiles();
      break;
    case 'medium':
      await _generateMediumFiles();
      break;
    case 'large':
      await _generateLargeFiles();
      break;
    case 'special':
      await _generateSpecialFiles();
      break;
    case 'all':
    default:
      await _generateAllFiles();
      break;
  }

  print('\n✅ Test file generation complete!');
  print('📝 Update checksums with: dart scripts/update_checksums.dart');
}

String? _parseCategory(List<String> args) {
  final index = args.indexOf('--category');
  if (index != -1 && index + 1 < args.length) {
    return args[index + 1];
  }
  return 'all';
}

int? _parseCustomSize(List<String> args) {
  final index = args.indexOf('--custom-size');
  if (index != -1 && index + 1 < args.length) {
    final sizeStr = args[index + 1].toUpperCase();
    if (sizeStr.endsWith('KB')) {
      return int.parse(sizeStr.replaceAll('KB', '')) * 1024;
    } else if (sizeStr.endsWith('MB')) {
      return int.parse(sizeStr.replaceAll('MB', '')) * 1024 * 1024;
    } else if (sizeStr.endsWith('GB')) {
      return int.parse(sizeStr.replaceAll('GB', '')) * 1024 * 1024 * 1024;
    }
  }
  return null;
}

Future<void> _generateAllFiles() async {
  await _generateSmallFiles();
  await _generateMediumFiles();
  await _generateLargeFiles();
  await _generateSpecialFiles();
}

Future<void> _generateSmallFiles() async {
  print('📁 Generating small files...');
  final dir = Directory('test_files/small');
  await dir.create(recursive: true);

  await _generateTextFile('${dir.path}/text_1kb.txt', 1024);
  await _generateTextFile('${dir.path}/text_10kb.txt', 10 * 1024);
  await _generateRandomFile('${dir.path}/image_100kb.jpg', 100 * 1024);
  await _generateRandomFile('${dir.path}/document_500kb.pdf', 500 * 1024);

  print('  ✓ Small files generated');
}

Future<void> _generateMediumFiles() async {
  print('📁 Generating medium files...');
  final dir = Directory('test_files/medium');
  await dir.create(recursive: true);

  await _generateRandomFile('${dir.path}/image_5mb.png', 5 * 1024 * 1024);
  await _generateRandomFile('${dir.path}/audio_10mb.mp3', 10 * 1024 * 1024);
  await _generateRandomFile('${dir.path}/video_25mb.mp4', 25 * 1024 * 1024);
  await _generateRandomFile('${dir.path}/archive_50mb.zip', 50 * 1024 * 1024);

  print('  ✓ Medium files generated');
}

Future<void> _generateLargeFiles() async {
  print('📁 Generating large files (this may take a while)...');
  final dir = Directory('test_files/large');
  await dir.create(recursive: true);

  await _generateRandomFile('${dir.path}/video_200mb.mov', 200 * 1024 * 1024);
  await _generateRandomFile(
    '${dir.path}/archive_500mb.tar.gz',
    500 * 1024 * 1024,
  );
  await _generateRandomFile('${dir.path}/dataset_1gb.bin', 1024 * 1024 * 1024);

  print('  ✓ Large files generated');
}

Future<void> _generateSpecialFiles() async {
  print('📁 Generating special test files...');
  final dir = Directory('test_files/special');
  await dir.create(recursive: true);

  // Empty file
  await File('${dir.path}/empty_file.txt').writeAsBytes([]);

  // Unicode filename
  await _generateTextFile('${dir.path}/unicode_名前.txt', 1024);

  // Spaces in filename
  await _generateTextFile('${dir.path}/spaces in name.doc', 1024);

  // Very long filename
  await _generateTextFile(
    '${dir.path}/very_long_filename_that_exceeds_normal_limits_and_tests_filesystem_boundaries.txt',
    1024,
  );

  // Corrupted file (invalid JPEG header)
  final corruptedFile = File('${dir.path}/corrupted_file.jpg');
  await corruptedFile.writeAsBytes([0xFF, 0xD8, 0xFF, 0x00]); // Invalid JPEG

  print('  ✓ Special files generated');
}

Future<void> _generateTextFile(String path, int size) async {
  final file = File(path);
  final buffer = StringBuffer();
  final loremIpsum =
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit. ';

  while (buffer.length < size) {
    buffer.write(loremIpsum);
  }

  await file.writeAsString(buffer.toString().substring(0, size));
  print('  ✓ ${file.path.split('/').last} (${_formatSize(size)})');
}

Future<void> _generateRandomFile(String path, int size) async {
  final file = File(path);
  final random = Random.secure();
  final chunkSize = 1024 * 1024; // 1MB chunks
  final sink = file.openWrite();

  try {
    int remaining = size;
    while (remaining > 0) {
      final currentChunk = remaining > chunkSize ? chunkSize : remaining;
      final bytes = List<int>.generate(
        currentChunk,
        (_) => random.nextInt(256),
      );
      sink.add(bytes);
      remaining -= currentChunk;

      // Progress indicator for large files
      if (size > 50 * 1024 * 1024 && remaining % (50 * 1024 * 1024) == 0) {
        final progress = ((size - remaining) / size * 100).toStringAsFixed(1);
        stdout.write('\r  Generating ${file.path.split('/').last}: $progress%');
      }
    }
    await sink.flush();
  } finally {
    await sink.close();
  }

  if (size > 50 * 1024 * 1024) {
    stdout.write('\r');
  }
  print('  ✓ ${file.path.split('/').last} (${_formatSize(size)})');
}

Future<void> _generateCustomFile(int size) async {
  print('📁 Generating custom file...');
  final dir = Directory('test_files/generated');
  await dir.create(recursive: true);

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final filename =
      'custom_${_formatSize(size).replaceAll(' ', '_')}_$timestamp.bin';
  await _generateRandomFile('${dir.path}/$filename', size);

  print('  ✓ Custom file generated: $filename');
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '${bytes}B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)}GB';
}
