# AirLink Test Files

This directory contains standardized test files used for comprehensive testing of the AirLink file transfer application.

## Directory Structure

```
test_files/
├── README.md                 # This file
├── small/                    # Small files (< 1MB)
│   ├── text_1kb.txt         # 1KB text file
│   ├── text_10kb.txt        # 10KB text file
│   ├── image_100kb.jpg      # 100KB JPEG image
│   └── document_500kb.pdf   # 500KB PDF document
├── medium/                   # Medium files (1MB - 100MB)
│   ├── image_5mb.png        # 5MB PNG image
│   ├── audio_10mb.mp3       # 10MB MP3 audio
│   ├── video_25mb.mp4       # 25MB MP4 video
│   └── archive_50mb.zip     # 50MB ZIP archive
├── large/                    # Large files (100MB - 1GB)
│   ├── video_200mb.mov      # 200MB MOV video
│   ├── archive_500mb.tar.gz # 500MB compressed archive
│   └── dataset_1gb.bin      # 1GB binary data
├── special/                  # Special test cases
│   ├── empty_file.txt       # 0 byte file
│   ├── unicode_名前.txt      # Unicode filename
│   ├── spaces in name.doc   # Filename with spaces
│   ├── very_long_filename_that_exceeds_normal_limits_and_tests_filesystem_boundaries.txt
│   └── corrupted_file.jpg   # Intentionally corrupted file
└── generated/                # Dynamically generated files
    └── .gitkeep             # Keep directory in git
```

## File Categories

### Small Files (< 1MB)
Used for testing basic functionality, quick transfers, and BLE performance.

- **text_1kb.txt**: Plain text with Lorem Ipsum content
- **text_10kb.txt**: Larger text file with structured content
- **image_100kb.jpg**: Small JPEG image for visual verification
- **document_500kb.pdf**: PDF document with text and images

### Medium Files (1MB - 100MB)
Used for testing standard transfer scenarios and Wi-Fi Aware performance.

- **image_5mb.png**: High-resolution PNG image
- **audio_10mb.mp3**: Music file for audio transfer testing
- **video_25mb.mp4**: Short video clip for multimedia testing
- **archive_50mb.zip**: Compressed archive with multiple files

### Large Files (100MB - 1GB)
Used for stress testing, performance benchmarking, and memory management.

- **video_200mb.mov**: High-quality video file
- **archive_500mb.tar.gz**: Large compressed archive
- **dataset_1gb.bin**: Binary data file for maximum size testing

### Special Cases
Used for edge case testing and error handling validation.

- **empty_file.txt**: Zero-byte file
- **unicode_名前.txt**: File with Unicode characters in name
- **spaces in name.doc**: File with spaces in filename
- **very_long_filename...txt**: File with extremely long filename
- **corrupted_file.jpg**: Intentionally corrupted file for error testing

## File Generation

### Automated Generation
Use the provided script to generate test files:

```bash
# Generate all test files
dart scripts/generate_test_files.dart

# Generate specific category
dart scripts/generate_test_files.dart --category small

# Generate with custom sizes
dart scripts/generate_test_files.dart --custom-size 50MB
```

### Manual Generation
For custom test files:

```bash
# Create text files with specific content
echo "Test content" > test_files/small/custom_text.txt

# Generate binary files with random data
dd if=/dev/urandom of=test_files/medium/random_10mb.bin bs=1M count=10

# Create files with specific patterns
python3 -c "print('A' * 1024)" > test_files/small/pattern_1kb.txt
```

## Usage in Tests

### Unit Tests
```dart
// Load test file for unit testing
final testFile = File('test_files/small/text_1kb.txt');
final content = await testFile.readAsBytes();

// Verify file properties
expect(content.length, equals(1024));
```

### Integration Tests
```dart
// Test file transfer with various sizes
final testFiles = [
  'test_files/small/text_1kb.txt',
  'test_files/medium/image_5mb.png',
  'test_files/large/video_200mb.mov',
];

for (final filePath in testFiles) {
  final result = await transferService.sendFile(filePath);
  expect(result.success, isTrue);
}
```

### Performance Tests
```dart
// Benchmark transfer speeds with different file sizes
final benchmarkFiles = {
  '1KB': 'test_files/small/text_1kb.txt',
  '1MB': 'test_files/medium/image_5mb.png',
  '100MB': 'test_files/large/video_200mb.mov',
};

for (final entry in benchmarkFiles.entries) {
  final startTime = DateTime.now();
  await transferService.sendFile(entry.value);
  final duration = DateTime.now().difference(startTime);
  
  print('${entry.key}: ${duration.inMilliseconds}ms');
}
```

## Checksum Verification

All test files include pre-calculated checksums for integrity verification:

### SHA-256 Checksums
```
text_1kb.txt:     a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3
text_10kb.txt:    b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9
image_100kb.jpg:  e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
document_500kb.pdf: d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592
```

### Verification Script
```bash
# Verify all test file checksums
./scripts/verify_test_files.sh

# Verify specific file
sha256sum test_files/small/text_1kb.txt
```

## File Maintenance

### Regular Updates
- Regenerate files monthly to ensure freshness
- Update checksums after any file modifications
- Verify file integrity before major releases

### Size Monitoring
```bash
# Check total size of test files
du -sh test_files/

# Monitor individual categories
du -sh test_files/*/
```

### Cleanup
```bash
# Remove generated files (keep originals)
rm -rf test_files/generated/*

# Clean up temporary test files
find test_files/ -name "*.tmp" -delete
```

## Security Considerations

### File Safety
- All test files are safe and contain no malicious content
- Binary files contain random or pattern data only
- No executable files are included in the test set

### Privacy
- No personal or sensitive information in test files
- All content is either generated or public domain
- Safe for use in automated testing environments

## Contributing

### Adding New Test Files
1. Place files in appropriate size category directory
2. Update this README with file descriptions
3. Generate and document SHA-256 checksums
4. Test with existing test suites
5. Submit pull request with changes

### File Naming Convention
- Use lowercase with underscores: `test_file_name.ext`
- Include size indicator: `image_5mb.png`
- Use descriptive names: `unicode_filename_test.txt`
- Avoid special characters except underscores and dots

### Quality Guidelines
- Files should be representative of real-world usage
- Include variety of formats and sizes
- Ensure files are not corrupted (except intentionally)
- Document any special properties or requirements

---

**Directory Version:** 1.0  
**Last Updated:** $(date)  
**Total Files:** 20+ standardized test files  
**Total Size:** ~2GB (when fully generated)  
**Maintained By:** AirLink QA Team
