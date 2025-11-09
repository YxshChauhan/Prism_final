import 'dart:typed_data';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Resume Database for persistent transfer state
/// 
/// Stores received chunk bitmap and last confirmed offset using SQLite
/// Falls back to in-memory storage if SQLite fails
class ResumeDatabase {
  static Database? _database;
  static const String _databaseName = 'airlink_resume.db';
  static const int _databaseVersion = 3;

  // Table names
  static const String _tableResumeStates = 'resume_states';
  static const String _tableChunkStates = 'chunk_states';
  
  // In-memory fallback storage
  static final Map<String, ResumeState> _inMemoryStore = {};
  static bool _useInMemoryFallback = false;

  /// Initialize database
  static Future<void> initialize() async {
    if (_database != null) return;

    try {
      final String databasePath = await getDatabasesPath();
      final String path = join(databasePath, _databaseName);

      _database = await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      _useInMemoryFallback = false;
      print('SQLite database initialized successfully');
    } catch (e) {
      // Fallback to in-memory storage if database fails
      print('Failed to initialize SQLite database: $e');
      print('Using in-memory storage fallback');
      _useInMemoryFallback = true;
      _database = null;
    }
  }

  /// Create database tables
  static Future<void> _onCreate(Database db, int version) async {
    // Create resume_states table
    await db.execute('''
      CREATE TABLE $_tableResumeStates (
        transfer_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        chunk_size INTEGER NOT NULL,
        total_chunks INTEGER NOT NULL,
        last_confirmed_offset INTEGER NOT NULL DEFAULT 0,
        is_complete INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        expected_hash TEXT,
        PRIMARY KEY (transfer_id, device_id)
      )
    ''');

    // Create chunk_states table
    await db.execute('''
      CREATE TABLE $_tableChunkStates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transfer_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        chunk_index INTEGER NOT NULL,
        is_received INTEGER NOT NULL DEFAULT 0,
        received_at INTEGER,
        UNIQUE(transfer_id, device_id, chunk_index),
        FOREIGN KEY(transfer_id, device_id) 
          REFERENCES $_tableResumeStates(transfer_id, device_id)
          ON DELETE CASCADE
      )
    ''');

    // Create indexes for faster queries
    await db.execute('''
      CREATE INDEX idx_chunk_states_lookup 
      ON $_tableChunkStates(transfer_id, device_id, chunk_index)
    ''');

    await db.execute('''
      CREATE INDEX idx_resume_states_updated 
      ON $_tableResumeStates(updated_at)
    ''');
  }

  /// Handle database upgrades
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    print('Database upgrade: $oldVersion -> $newVersion');
    
    // Migration from version 1 to 2: Add last_confirmed_offset column
    if (oldVersion < 2) {
      await _migrateToVersion2(db);
    }
    
    // Migration from version 2 to 3: Add expected_hash column
    if (oldVersion < 3) {
      await _migrateToVersion3(db);
    }
  }

  /// Migrate database to version 2
  static Future<void> _migrateToVersion2(Database db) async {
    try {
      // Check if last_confirmed_offset column already exists
      final List<Map<String, dynamic>> columns = await db.rawQuery(
        "PRAGMA table_info($_tableResumeStates)"
      );
      
      final bool columnExists = columns.any(
        (column) => column['name'] == 'last_confirmed_offset'
      );
      
      if (!columnExists) {
        print('Adding last_confirmed_offset column to resume_states table');
        await db.execute(
          'ALTER TABLE $_tableResumeStates ADD COLUMN last_confirmed_offset INTEGER NOT NULL DEFAULT 0'
        );
        print('Successfully added last_confirmed_offset column');
      } else {
        print('last_confirmed_offset column already exists, skipping migration');
      }
    } catch (e) {
      print('Error during migration to version 2: $e');
      // Don't rethrow - allow app to continue with existing schema
    }
  }
  
  /// Migrate database to version 3
  static Future<void> _migrateToVersion3(Database db) async {
    try {
      // Check if expected_hash column already exists
      final List<Map<String, dynamic>> columns = await db.rawQuery(
        "PRAGMA table_info($_tableResumeStates)"
      );
      
      final bool columnExists = columns.any(
        (column) => column['name'] == 'expected_hash'
      );
      
      if (!columnExists) {
        print('Adding expected_hash column to resume_states table');
        await db.execute(
          'ALTER TABLE $_tableResumeStates ADD COLUMN expected_hash TEXT'
        );
        print('Successfully added expected_hash column');
      } else {
        print('expected_hash column already exists, skipping migration');
      }
    } catch (e) {
      print('Error during migration to version 3: $e');
      // Don't rethrow - allow app to continue with existing schema
    }
  }

  /// Get database instance or throw if using in-memory fallback
  static Future<Database> _getDatabase() async {
    if (_database == null) {
      await initialize();
    }
    if (_database == null || _useInMemoryFallback) {
      throw Exception('Database not available - using in-memory fallback');
    }
    return _database!;
  }

  /// Save transfer resume state
  static Future<void> saveResumeState(ResumeState state) async {
    // Use in-memory fallback if database not available
    if (_useInMemoryFallback || _database == null) {
      final key = '${state.transferId}_${state.deviceId}';
      _inMemoryStore[key] = state;
      print('Saved resume state to in-memory storage: $key');
      return;
    }
    
    try {
      final db = await _getDatabase();
      await db.transaction((txn) async {
        // Insert or update resume state
        await txn.insert(
          _tableResumeStates,
          {
            'transfer_id': state.transferId,
            'device_id': state.deviceId,
            'file_path': state.filePath,
            'file_size': state.fileSize,
            'chunk_size': state.chunkSize,
            'total_chunks': state.totalChunks,
            'last_confirmed_offset': state.lastConfirmedOffset,
            'is_complete': state.isComplete ? 1 : 0,
            'created_at': state.createdAt.millisecondsSinceEpoch,
            'updated_at': DateTime.now().millisecondsSinceEpoch,
            'expected_hash': state.expectedHash,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Save chunk states
        for (int i = 0; i < state.totalChunks; i++) {
          final byteIndex = i ~/ 8;
          final bitIndex = i % 8;
          final isReceived = byteIndex < state.receivedChunks.length &&
              (state.receivedChunks[byteIndex] & (1 << bitIndex)) != 0;

          if (isReceived) {
            await txn.insert(
              _tableChunkStates,
              {
                'transfer_id': state.transferId,
                'device_id': state.deviceId,
                'chunk_index': i,
                'is_received': 1,
                'received_at': DateTime.now().millisecondsSinceEpoch,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      });
    } catch (e) {
      print('Error saving resume state: $e');
      rethrow;
    }
  }

  /// Load transfer resume state
  static Future<ResumeState?> loadResumeState(
    String transferId,
    String deviceId,
  ) async {
    // Use in-memory fallback if database not available
    if (_useInMemoryFallback || _database == null) {
      final key = '${transferId}_$deviceId';
      final state = _inMemoryStore[key];
      if (state != null) {
        print('Loaded resume state from in-memory storage: $key');
      }
      return state;
    }
    
    try {
      final db = await _getDatabase();

      // Load resume state
      final List<Map<String, dynamic>> stateResults = await db.query(
        _tableResumeStates,
        where: 'transfer_id = ? AND device_id = ?',
        whereArgs: [transferId, deviceId],
        limit: 1,
      );

      if (stateResults.isEmpty) return null;

      final stateData = stateResults.first;
      final int totalChunks = stateData['total_chunks'] as int;

      // Load chunk states
      final List<Map<String, dynamic>> chunkResults = await db.query(
        _tableChunkStates,
        where: 'transfer_id = ? AND device_id = ? AND is_received = 1',
        whereArgs: [transferId, deviceId],
      );

      // Reconstruct received chunks bitmap
      final receivedChunks = Uint8List((totalChunks + 7) ~/ 8);
      for (final chunk in chunkResults) {
        final int chunkIndex = chunk['chunk_index'] as int;
        final byteIndex = chunkIndex ~/ 8;
        final bitIndex = chunkIndex % 8;
        if (byteIndex < receivedChunks.length) {
          receivedChunks[byteIndex] |= (1 << bitIndex);
        }
      }

      return ResumeState(
        transferId: stateData['transfer_id'] as String,
        deviceId: stateData['device_id'] as String,
        filePath: stateData['file_path'] as String,
        fileSize: stateData['file_size'] as int,
        chunkSize: stateData['chunk_size'] as int,
        totalChunks: totalChunks,
        receivedChunks: receivedChunks,
        lastConfirmedOffset: stateData['last_confirmed_offset'] as int? ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          stateData['created_at'] as int,
        ),
        expectedHash: stateData['expected_hash'] as String?,
      );
    } catch (e) {
      print('Error loading resume state: $e');
      return null;
    }
  }

  /// Mark chunk as received
  static Future<void> markChunkReceived(
    String transferId,
    String deviceId,
    int chunkIndex,
  ) async {
    // Use in-memory fallback if database not available
    if (_useInMemoryFallback || _database == null) {
      final key = '${transferId}_$deviceId';
      final state = _inMemoryStore[key];
      if (state != null) {
        final byteIndex = chunkIndex ~/ 8;
        final bitIndex = chunkIndex % 8;
        if (byteIndex < state.receivedChunks.length) {
          state.receivedChunks[byteIndex] |= (1 << bitIndex);
        }
        print('Marked chunk as received in in-memory storage: $key, chunk $chunkIndex');
      }
      return;
    }
    
    try {
      final db = await _getDatabase();
      await db.insert(
        _tableChunkStates,
        {
          'transfer_id': transferId,
          'device_id': deviceId,
          'chunk_index': chunkIndex,
          'is_received': 1,
          'received_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Update resume state timestamp
      await db.update(
        _tableResumeStates,
        {'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'transfer_id = ? AND device_id = ?',
        whereArgs: [transferId, deviceId],
      );
    } catch (e) {
      print('Error marking chunk as received: $e');
    }
  }

  /// Check if chunk is received
  static Future<bool> isChunkReceived(
    String transferId,
    String deviceId,
    int chunkIndex,
  ) async {
    // Use in-memory fallback if database not available
    if (_useInMemoryFallback || _database == null) {
      final key = '${transferId}_$deviceId';
      final state = _inMemoryStore[key];
      if (state != null) {
        final byteIndex = chunkIndex ~/ 8;
        final bitIndex = chunkIndex % 8;
        if (byteIndex < state.receivedChunks.length) {
          return (state.receivedChunks[byteIndex] & (1 << bitIndex)) != 0;
        }
      }
      return false;
    }
    
    try {
      final db = await _getDatabase();
      final List<Map<String, dynamic>> results = await db.query(
        _tableChunkStates,
        where: 'transfer_id = ? AND device_id = ? AND chunk_index = ? AND is_received = 1',
        whereArgs: [transferId, deviceId, chunkIndex],
        limit: 1,
      );
      return results.isNotEmpty;
    } catch (e) {
      print('Error checking chunk received: $e');
      return false;
    }
  }

  /// Get missing chunks
  static Future<List<int>> getMissingChunks(
    String transferId,
    String deviceId,
  ) async {
    // Use in-memory fallback if database not available
    if (_useInMemoryFallback || _database == null) {
      final key = '${transferId}_$deviceId';
      final state = _inMemoryStore[key];
      if (state == null) return [];

      final List<int> missingChunks = [];
      for (int i = 0; i < state.totalChunks; i++) {
        final byteIndex = i ~/ 8;
        final bitIndex = i % 8;
        final isReceived = byteIndex < state.receivedChunks.length &&
            (state.receivedChunks[byteIndex] & (1 << bitIndex)) != 0;
        if (!isReceived) {
          missingChunks.add(i);
        }
      }
      return missingChunks;
    }
    
    try {
      final state = await loadResumeState(transferId, deviceId);
      if (state == null) return [];

      final db = await _getDatabase();
      final List<Map<String, dynamic>> receivedChunks = await db.query(
        _tableChunkStates,
        columns: ['chunk_index'],
        where: 'transfer_id = ? AND device_id = ? AND is_received = 1',
        whereArgs: [transferId, deviceId],
      );

      final Set<int> receivedIndices =
          receivedChunks.map((row) => row['chunk_index'] as int).toSet();

      final List<int> missingChunks = [];
      for (int i = 0; i < state.totalChunks; i++) {
        if (!receivedIndices.contains(i)) {
          missingChunks.add(i);
        }
      }

      return missingChunks;
    } catch (e) {
      print('Error getting missing chunks: $e');
      return [];
    }
  }

  /// Get transfer progress
  static Future<double> getTransferProgress(
    String transferId,
    String deviceId,
  ) async {
    // Use in-memory fallback if database not available
    if (_useInMemoryFallback || _database == null) {
      final key = '${transferId}_$deviceId';
      final state = _inMemoryStore[key];
      if (state == null) return 0.0;
      return state.progressPercentage;
    }
    
    try {
      final state = await loadResumeState(transferId, deviceId);
      if (state == null) return 0.0;

      final db = await _getDatabase();
      final List<Map<String, dynamic>> result = await db.rawQuery('''
        SELECT COUNT(*) as received_count
        FROM $_tableChunkStates
        WHERE transfer_id = ? AND device_id = ? AND is_received = 1
      ''', [transferId, deviceId]);

      final int receivedCount = result.first['received_count'] as int;
      return receivedCount / state.totalChunks;
    } catch (e) {
      print('Error getting transfer progress: $e');
      return 0.0;
    }
  }

  /// Delete transfer state
  static Future<void> deleteTransferState(
    String transferId,
    String deviceId,
  ) async {
    // Use in-memory fallback if database not available
    if (_useInMemoryFallback || _database == null) {
      final key = '${transferId}_$deviceId';
      _inMemoryStore.remove(key);
      print('Deleted transfer state from in-memory storage: $key');
      return;
    }
    
    try {
      final db = await _getDatabase();
      await db.transaction((txn) async {
        // Delete chunk states (cascading delete should handle this)
        await txn.delete(
          _tableChunkStates,
          where: 'transfer_id = ? AND device_id = ?',
          whereArgs: [transferId, deviceId],
        );
        
        // Delete resume state
        await txn.delete(
          _tableResumeStates,
          where: 'transfer_id = ? AND device_id = ?',
          whereArgs: [transferId, deviceId],
        );
      });
    } catch (e) {
      print('Error deleting transfer state: $e');
    }
  }

  /// Clean up old transfer states
  static Future<void> cleanupOldStates({
    Duration maxAge = const Duration(days: 7),
  }) async {
    // Use in-memory fallback if database not available
    if (_useInMemoryFallback || _database == null) {
      final cutoffTime = DateTime.now().subtract(maxAge);
      final keysToRemove = <String>[];
      
      for (final entry in _inMemoryStore.entries) {
        if (entry.value.createdAt.isBefore(cutoffTime)) {
          keysToRemove.add(entry.key);
        }
      }
      
      for (final key in keysToRemove) {
        _inMemoryStore.remove(key);
      }
      
      print('Cleaned up ${keysToRemove.length} old states from in-memory storage');
      return;
    }
    
    try {
      final db = await _getDatabase();
      final cutoffTime = DateTime.now().subtract(maxAge).millisecondsSinceEpoch;

      await db.transaction((txn) async {
        // Get old transfer IDs
        final List<Map<String, dynamic>> oldStates = await txn.query(
          _tableResumeStates,
          columns: ['transfer_id', 'device_id'],
          where: 'updated_at < ?',
          whereArgs: [cutoffTime],
        );

        // Delete old states
        for (final state in oldStates) {
          await txn.delete(
            _tableChunkStates,
            where: 'transfer_id = ? AND device_id = ?',
            whereArgs: [state['transfer_id'], state['device_id']],
          );
        }

        await txn.delete(
          _tableResumeStates,
          where: 'updated_at < ?',
          whereArgs: [cutoffTime],
        );
      });
    } catch (e) {
      print('Error cleaning up old states: $e');
    }
  }

  /// Get all transfer states
  static Future<List<ResumeState>> getAllTransferStates() async {
    // Use in-memory fallback if database not available
    if (_useInMemoryFallback || _database == null) {
      final states = _inMemoryStore.values.toList();
      // Sort by creation time (newest first)
      states.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      print('Retrieved ${states.length} transfer states from in-memory storage');
      return states;
    }
    
    try {
      final db = await _getDatabase();
      final List<Map<String, dynamic>> results = await db.query(
        _tableResumeStates,
        orderBy: 'updated_at DESC',
      );

      final List<ResumeState> states = [];
      for (final stateData in results) {
        final state = await loadResumeState(
          stateData['transfer_id'] as String,
          stateData['device_id'] as String,
        );
        if (state != null) {
          states.add(state);
        }
      }

      return states;
    } catch (e) {
      print('Error getting all transfer states: $e');
      return [];
    }
  }

  /// Close database
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

/// Resume state model
class ResumeState {
  final String transferId;
  final String deviceId;
  final String filePath;
  final int fileSize;
  final int chunkSize;
  final int totalChunks;
  final Uint8List receivedChunks; // Bitmap of received chunks
  final int lastConfirmedOffset;
  final DateTime createdAt;
  final String? expectedHash; // Expected file hash for verification

  const ResumeState({
    required this.transferId,
    required this.deviceId,
    required this.filePath,
    required this.fileSize,
    required this.chunkSize,
    required this.totalChunks,
    required this.receivedChunks,
    required this.lastConfirmedOffset,
    required this.createdAt,
    this.expectedHash,
  });

  /// Create initial resume state
  factory ResumeState.initial({
    required String transferId,
    required String deviceId,
    required String filePath,
    required int fileSize,
    required int chunkSize,
  }) {
    final totalChunks = (fileSize / chunkSize).ceil();
    final receivedChunks = Uint8List((totalChunks + 7) ~/ 8); // Bitmap size

    return ResumeState(
      transferId: transferId,
      deviceId: deviceId,
      filePath: filePath,
      fileSize: fileSize,
      chunkSize: chunkSize,
      totalChunks: totalChunks,
      receivedChunks: receivedChunks,
      lastConfirmedOffset: 0,
      createdAt: DateTime.now(),
    );
  }

  /// Get received chunks count
  int get receivedChunksCount {
    int count = 0;
    for (int i = 0; i < totalChunks; i++) {
      final byteIndex = i ~/ 8;
      final bitIndex = i % 8;
      if (byteIndex < receivedChunks.length &&
          (receivedChunks[byteIndex] & (1 << bitIndex)) != 0) {
        count++;
      }
    }
    return count;
  }

  /// Get progress percentage
  double get progressPercentage {
    if (totalChunks == 0) return 0.0;
    return receivedChunksCount / totalChunks;
  }

  /// Check if transfer is complete
  bool get isComplete {
    return receivedChunksCount == totalChunks;
  }
}
