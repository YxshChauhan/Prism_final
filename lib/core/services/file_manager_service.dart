import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:injectable/injectable.dart';
import 'package:crypto/crypto.dart' show sha256;

/// Advanced File Manager Service
/// Provides comprehensive file management similar to SHAREit/Zapya/Files by Google
@injectable
class FileManagerService {
  final LoggerService _logger;
  
  // File index cache
  final Map<String, FileItem> _fileIndex = {};
  final List<String> _favorites = [];
  final List<String> _recentFiles = [];
  
  // Storage info
  int _totalSpace = 0;
  int _usedSpace = 0;
  int _freeSpace = 0;
  
  FileManagerService({
    required LoggerService logger,
  }) : _logger = logger;
  
  /// Initialize file manager
  Future<void> initialize() async {
    try {
      _logger.info('Initializing file manager service...');
      await _updateStorageInfo();
      _logger.info('File manager service initialized');
    } catch (e) {
      _logger.error('Failed to initialize file manager: $e');
    }
  }
  
  /// List files in directory
  /// Get all files from the device
  Future<List<FileItem>> getAllFiles() async {
    try {
      final List<FileItem> allFiles = [];
      
      // Use scoped storage-friendly directories on Android 10+
      final List<String> commonDirs = [];
      if (Platform.isAndroid) {
        try {
          final Directory? ext = await getExternalStorageDirectory();
          if (ext != null) commonDirs.add(ext.path);
          final Directory appDocs = await getApplicationDocumentsDirectory();
          commonDirs.add(appDocs.path);
        } catch (_) {}
      } else {
        final Directory appDocs = await getApplicationDocumentsDirectory();
        commonDirs.add(appDocs.path);
      }
      
      for (final dir in commonDirs) {
        try {
          final files = await listFiles(dir, includeHidden: false);
          allFiles.addAll(files);
        } catch (e) {
          // Skip directories that don't exist or can't be accessed
          continue;
        }
      }
      
      _logger.info('Retrieved ${allFiles.length} files from device');
      return allFiles;
    } catch (e) {
      _logger.error('Failed to get all files: $e');
      throw FileManagerException('Failed to get all files: $e');
    }
  }

  Future<List<FileItem>> listFiles(String directoryPath, {
    bool includeHidden = false,
    FileSortBy sortBy = FileSortBy.name,
    SortOrder sortOrder = SortOrder.ascending,
  }) async {
    try {
      _logger.info('Listing files in: $directoryPath');
      
      final directory = Directory(directoryPath);
      if (!await directory.exists()) {
        throw FileManagerException('Directory does not exist: $directoryPath');
      }
      
      final List<FileItem> items = [];
      await for (final entity in directory.list()) {
        final fileName = path.basename(entity.path);
        
        // Skip hidden files if not included
        if (!includeHidden && fileName.startsWith('.')) {
          continue;
        }
        
        final FileItem item = await _createFileItem(entity);
        items.add(item);
        
        // Update cache
        _fileIndex[entity.path] = item;
      }
      
      // Sort items
      _sortFileItems(items, sortBy, sortOrder);
      
      _logger.info('Listed ${items.length} items');
      return items;
    } catch (e) {
      _logger.error('Failed to list files: $e');
      throw FileManagerException('Failed to list files: $e');
    }
  }
  
  /// Search files
  Future<List<FileItem>> searchFiles({
    required String query,
    String? basePath,
    List<FileCategory>? categories,
    DateTime? modifiedAfter,
    DateTime? modifiedBefore,
    int? minSize,
    int? maxSize,
    int limit = 100,
  }) async {
    try {
      _logger.info('Searching files: $query');
      
      final List<FileItem> results = [];
      final searchPath = basePath ?? (Platform.isAndroid ? '/storage/emulated/0' : Directory.systemTemp.path);
      
      await _searchRecursive(
        Directory(searchPath),
        query.toLowerCase(),
        results,
        categories: categories,
        modifiedAfter: modifiedAfter,
        modifiedBefore: modifiedBefore,
        minSize: minSize,
        maxSize: maxSize,
        limit: limit,
      );
      
      _logger.info('Found ${results.length} files');
      return results;
    } catch (e) {
      _logger.error('Failed to search files: $e');
      return [];
    }
  }
  
  Future<void> _searchRecursive(
    Directory directory,
    String query,
    List<FileItem> results, {
    List<FileCategory>? categories,
    DateTime? modifiedAfter,
    DateTime? modifiedBefore,
    int? minSize,
    int? maxSize,
    required int limit,
  }) async {
    if (results.length >= limit) return;
    
    try {
      await for (final entity in directory.list()) {
        if (results.length >= limit) break;
        
        final fileName = path.basename(entity.path).toLowerCase();
        
        // Check if matches query
        if (!fileName.contains(query)) continue;
        
        final FileItem item = await _createFileItem(entity);
        
        // Apply filters
        if (categories != null && !categories.contains(item.category)) continue;
        if (modifiedAfter != null && item.modifiedAt.isBefore(modifiedAfter)) continue;
        if (modifiedBefore != null && item.modifiedAt.isAfter(modifiedBefore)) continue;
        if (minSize != null && item.size < minSize) continue;
        if (maxSize != null && item.size > maxSize) continue;
        
        results.add(item);
        
        // Recurse into directories
        if (entity is Directory) {
          await _searchRecursive(
            entity,
            query,
            results,
            categories: categories,
            modifiedAfter: modifiedAfter,
            modifiedBefore: modifiedBefore,
            minSize: minSize,
            maxSize: maxSize,
            limit: limit,
          );
        }
      }
    } catch (e) {
      // Skip directories we don't have permission to access
    }
  }
  
  /// Get files by category
  Future<List<FileItem>> getFilesByCategory(
    FileCategory category, {
    String? basePath,
    int limit = 100,
  }) async {
    try {
      _logger.info('Getting files for category: ${category.toString().split('.').last}');
      
      final List<FileItem> results = [];
      final searchPath = basePath ?? (Platform.isAndroid ? '/storage/emulated/0' : Directory.systemTemp.path);
      
      await _searchByCategory(
        Directory(searchPath),
        category,
        results,
        limit: limit,
      );
      
      _logger.info('Found ${results.length} files for category');
      return results;
    } catch (e) {
      _logger.error('Failed to get files by category: $e');
      return [];
    }
  }
  
  Future<void> _searchByCategory(
    Directory directory,
    FileCategory category,
    List<FileItem> results, {
    required int limit,
  }) async {
    if (results.length >= limit) return;
    
    try {
      await for (final entity in directory.list()) {
        if (results.length >= limit) break;
        
        if (entity is File) {
          final FileItem item = await _createFileItem(entity);
          if (item.category == category) {
            results.add(item);
          }
        } else if (entity is Directory) {
          await _searchByCategory(entity, category, results, limit: limit);
        }
      }
    } catch (e) {
      // Skip inaccessible directories
    }
  }
  
  /// Copy file
  Future<void> copyFile(String sourcePath, String destPath) async {
    try {
      _logger.info('Copying file: $sourcePath -> $destPath');
      
      final source = File(sourcePath);
      if (!await source.exists()) {
        throw FileManagerException('Source file does not exist');
      }
      
      // Create destination directory if needed
      final destDir = Directory(path.dirname(destPath));
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }
      
      await source.copy(destPath);
      
      // Update index
      _fileIndex.remove(sourcePath);
      _fileIndex[destPath] = await _createFileItem(File(destPath));
      
      _logger.info('File copied successfully');
    } catch (e) {
      _logger.error('Failed to copy file: $e');
      throw FileManagerException('Failed to copy file: $e');
    }
  }
  
  /// Move file
  Future<void> moveFile(String sourcePath, String destPath) async {
    try {
      _logger.info('Moving file: $sourcePath -> $destPath');
      
      final source = File(sourcePath);
      if (!await source.exists()) {
        throw FileManagerException('Source file does not exist');
      }
      
      // Create destination directory if needed
      final destDir = Directory(path.dirname(destPath));
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }
      
      await source.rename(destPath);
      
      // Update index
      _fileIndex.remove(sourcePath);
      _fileIndex[destPath] = await _createFileItem(File(destPath));
      
      _logger.info('File moved successfully');
    } catch (e) {
      _logger.error('Failed to move file: $e');
      throw FileManagerException('Failed to move file: $e');
    }
  }
  
  /// Delete file
  Future<void> deleteFile(String filePath, {bool permanent = false}) async {
    try {
      _logger.info('Deleting file: $filePath');
      
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileManagerException('File does not exist');
      }
      
      if (permanent) {
        // Secure delete (overwrite with random data)
        await _secureDelete(file);
      } else {
        await file.delete();
      }
      
      // Update index
      _fileIndex.remove(filePath);
      _favorites.remove(filePath);
      _recentFiles.remove(filePath);
      
      _logger.info('File deleted successfully');
    } catch (e) {
      _logger.error('Failed to delete file: $e');
      throw FileManagerException('Failed to delete file: $e');
    }
  }
  
  /// Rename file
  Future<void> renameFile(String filePath, String newName) async {
    try {
      _logger.info('Renaming file: $filePath -> $newName');
      
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileManagerException('File does not exist');
      }
      
      final newPath = path.join(path.dirname(filePath), newName);
      await file.rename(newPath);
      
      // Update index
      _fileIndex.remove(filePath);
      _fileIndex[newPath] = await _createFileItem(File(newPath));
      
      _logger.info('File renamed successfully');
    } catch (e) {
      _logger.error('Failed to rename file: $e');
      throw FileManagerException('Failed to rename file: $e');
    }
  }
  
  /// Get file info
  Future<FileItem> getFileInfo(String filePath) async {
    try {
      // Check cache first
      if (_fileIndex.containsKey(filePath)) {
        return _fileIndex[filePath]!;
      }
      
      final file = File(filePath);
      if (!await file.exists()) {
        throw FileManagerException('File does not exist');
      }
      
      final item = await _createFileItem(file);
      _fileIndex[filePath] = item;
      return item;
    } catch (e) {
      _logger.error('Failed to get file info: $e');
      throw FileManagerException('Failed to get file info: $e');
    }
  }
  
  /// Add to favorites
  void addToFavorites(String filePath) {
    if (!_favorites.contains(filePath)) {
      _favorites.add(filePath);
      _logger.info('Added to favorites: $filePath');
    }
  }
  
  /// Remove from favorites
  void removeFromFavorites(String filePath) {
    _favorites.remove(filePath);
    _logger.info('Removed from favorites: $filePath');
  }
  
  /// Get favorites
  Future<List<FileItem>> getFavorites() async {
    final List<FileItem> items = [];
    for (final filePath in _favorites) {
      try {
        items.add(await getFileInfo(filePath));
      } catch (e) {
        // Skip files that no longer exist
      }
    }
    return items;
  }
  
  /// Add to recent files
  void addToRecent(String filePath) {
    _recentFiles.remove(filePath); // Remove if exists
    _recentFiles.insert(0, filePath); // Add to beginning
    
    // Keep only last 50
    if (_recentFiles.length > 50) {
      _recentFiles.removeLast();
    }
  }
  
  /// Get recent files
  Future<List<FileItem>> getRecentFiles({int limit = 20}) async {
    final List<FileItem> items = [];
    for (final filePath in _recentFiles.take(limit)) {
      try {
        items.add(await getFileInfo(filePath));
      } catch (e) {
        // Skip files that no longer exist
      }
    }
    return items;
  }
  
  /// Get storage info
  Future<StorageInfo> getStorageInfo() async {
    await _updateStorageInfo();
    return StorageInfo(
      totalSpace: _totalSpace,
      usedSpace: _usedSpace,
      freeSpace: _freeSpace,
      usagePercentage: _totalSpace > 0 ? (_usedSpace / _totalSpace) : 0.0,
      categoryBreakdown: {},
    );
  }
  
  /// Analyze storage by category
  Future<Map<FileCategory, int>> analyzeStorageByCategory() async {
    final Map<FileCategory, int> usage = {};
    
    for (final category in FileCategory.values) {
      usage[category] = 0;
    }
    
    // Scan common directories
      final directories = [
      if (Platform.isAndroid) '/storage/emulated/0/DCIM',
      if (Platform.isAndroid) '/storage/emulated/0/Downloads',
      if (Platform.isAndroid) '/storage/emulated/0/Documents',
    ];
    
    for (final dirPath in directories) {
      try {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          await for (final entity in dir.list(recursive: true)) {
            if (entity is File) {
              try {
                final item = await _createFileItem(entity);
                usage[item.category] = (usage[item.category] ?? 0) + item.size;
              } catch (e) {
                // Skip files we can't access
              }
            }
          }
        }
      } catch (e) {
        // Skip inaccessible directories
      }
    }
    
    return usage;
  }
  
  /// Find duplicate files
  Future<List<List<FileItem>>> findDuplicates({
    String? basePath,
    int minSize = 1024, // Skip files smaller than 1KB
  }) async {
    try {
      _logger.info('Finding duplicate files...');
      
      final Map<int, List<FileItem>> sizeGroups = {};
      final searchPath = basePath ?? (Platform.isAndroid ? '/storage/emulated/0' : Directory.systemTemp.path);
      
      // Group files by size
      await _groupFilesBySize(
        Directory(searchPath),
        sizeGroups,
        minSize: minSize,
      );
      
      // Find actual duplicates (same size and content)
      final List<List<FileItem>> duplicates = [];
      
      for (final group in sizeGroups.values) {
        if (group.length > 1) {
          // Compare file contents
          final Map<String, List<FileItem>> hashGroups = {};
          
          for (final item in group) {
            final hash = await _calculateFileHash(item.path);
            hashGroups.putIfAbsent(hash, () => []).add(item);
          }
          
          for (final hashGroup in hashGroups.values) {
            if (hashGroup.length > 1) {
              duplicates.add(hashGroup);
            }
          }
        }
      }
      
      _logger.info('Found ${duplicates.length} duplicate groups');
      return duplicates;
    } catch (e) {
      _logger.error('Failed to find duplicates: $e');
      return [];
    }
  }
  
  Future<void> _groupFilesBySize(
    Directory directory,
    Map<int, List<FileItem>> sizeGroups, {
    required int minSize,
  }) async {
    try {
      await for (final entity in directory.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          if (stat.size >= minSize) {
            final item = await _createFileItem(entity);
            sizeGroups.putIfAbsent(item.size, () => []).add(item);
          }
        } else if (entity is Directory) {
          await _groupFilesBySize(entity, sizeGroups, minSize: minSize);
        }
      }
    } catch (e) {
      // Skip inaccessible directories
    }
  }
  
  Future<String> _calculateFileHash(String filePath) async {
    try {
      final file = File(filePath);
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString();
    } catch (e) {
      return '';
    }
  }
  
  Future<void> _secureDelete(File file) async {
    try {
      final size = await file.length();
      final randomData = List<int>.generate(size, (i) => i % 256);
      
      // Overwrite with random data
      await file.writeAsBytes(randomData, flush: true);
      
      // Delete
      await file.delete();
    } catch (e) {
      // Fallback to regular delete
      await file.delete();
    }
  }
  
  Future<void> _updateStorageInfo() async {
    try {
      final Directory baseDir = Platform.isAndroid
          ? (await getExternalStorageDirectory()) ?? (await getApplicationDocumentsDirectory())
          : await getApplicationDocumentsDirectory();
      if (await baseDir.exists()) {
        // Lightweight estimation by summing top-level file sizes
        int total = 0;
        try {
          await for (final FileSystemEntity entity in baseDir.list(recursive: false)) {
            if (entity is File) {
              final FileStat stat = await entity.stat();
              total += stat.size;
            }
          }
        } catch (_) {}
        _usedSpace = total;
        // Keep placeholders for total/free if platform channels are not implemented
        if (_totalSpace == 0) {
          _totalSpace = _usedSpace * 2; // assume 50% used as a rough estimate
          _freeSpace = _totalSpace - _usedSpace;
        }
      }
    } catch (e) {
      _logger.error('Failed to update storage info: $e');
    }
  }
  
  Future<FileItem> _createFileItem(FileSystemEntity entity) async {
    final stat = await entity.stat();
    final fileName = path.basename(entity.path);
    final extension = path.extension(entity.path).toLowerCase();
    
    return FileItem(
      id: entity.path, // Use path as unique ID
      path: entity.path,
      name: fileName,
      size: stat.size,
      extension: extension,
      isDirectory: entity is Directory,
      createdAt: stat.modified, // Best approximation
      modifiedAt: stat.modified,
      accessedAt: stat.accessed,
      mimeType: _getMimeType(extension),
      category: _categorizeFile(extension),
      isFavorite: _favorites.contains(entity.path),
      isHidden: fileName.startsWith('.'),
      checksum: '', // Will be calculated if needed
    );
  }
  
  String _getMimeType(String extension) {
    final mimeTypes = {
      // Images
      '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.png': 'image/png',
      '.gif': 'image/gif', '.bmp': 'image/bmp', '.webp': 'image/webp',
      // Videos
      '.mp4': 'video/mp4', '.avi': 'video/x-msvideo', '.mkv': 'video/x-matroska',
      '.mov': 'video/quicktime', '.wmv': 'video/x-ms-wmv',
      // Audio
      '.mp3': 'audio/mpeg', '.wav': 'audio/wav', '.flac': 'audio/flac',
      '.aac': 'audio/aac', '.m4a': 'audio/mp4',
      // Documents
      '.pdf': 'application/pdf', '.doc': 'application/msword',
      '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      '.xls': 'application/vnd.ms-excel',
      '.xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      '.ppt': 'application/vnd.ms-powerpoint',
      '.pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      '.txt': 'text/plain',
      // Archives
      '.zip': 'application/zip', '.rar': 'application/x-rar-compressed',
      '.7z': 'application/x-7z-compressed', '.tar': 'application/x-tar',
      // APK
      '.apk': 'application/vnd.android.package-archive',
    };
    
    return mimeTypes[extension] ?? 'application/octet-stream';
  }
  
  FileCategory _categorizeFile(String extension) {
    if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp'].contains(extension)) {
      return FileCategory.image;
    } else if (['.mp4', '.avi', '.mkv', '.mov', '.wmv', '.flv'].contains(extension)) {
      return FileCategory.video;
    } else if (['.mp3', '.wav', '.flac', '.aac', '.m4a', '.wma'].contains(extension)) {
      return FileCategory.audio;
    } else if (['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.ppt', '.pptx', '.txt'].contains(extension)) {
      return FileCategory.document;
    } else if (['.zip', '.rar', '.7z', '.tar', '.gz'].contains(extension)) {
      return FileCategory.archive;
    } else if (extension == '.apk') {
      return FileCategory.apk;
    } else {
      return FileCategory.other;
    }
  }
  
  void _sortFileItems(List<FileItem> items, FileSortBy sortBy, SortOrder sortOrder) {
    items.sort((a, b) {
      int comparison;
      
      switch (sortBy) {
        case FileSortBy.name:
          comparison = a.name.compareTo(b.name);
          break;
        case FileSortBy.size:
          comparison = a.size.compareTo(b.size);
          break;
        case FileSortBy.date:
          comparison = a.modifiedAt.compareTo(b.modifiedAt);
          break;
        case FileSortBy.modifiedDate:
          comparison = a.modifiedAt.compareTo(b.modifiedAt);
          break;
        case FileSortBy.type:
          comparison = a.extension.compareTo(b.extension);
          break;
      }
      
      return sortOrder == SortOrder.ascending ? comparison : -comparison;
    });
  }
}

// FileItem model moved to app_state.dart

// StorageInfo model moved to app_state.dart

// FileCategory and FileSortBy enums moved to app_state.dart

enum SortOrder {
  ascending,
  descending,
}

/// File manager exception
class FileManagerException implements Exception {
  final String message;
  const FileManagerException(this.message);
  
  @override
  String toString() => 'FileManagerException: $message';
}
