import 'dart:async';
import 'dart:io';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:airlink/core/services/logger_service.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:injectable/injectable.dart';

/// Advanced Media Player Service
/// Provides unified interface for playing videos, audio, and viewing images
/// Similar to SHAREit/Zapya built-in media players
@injectable
class MediaPlayerService {
  final LoggerService _logger;
  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  
  StreamSubscription<dynamic>? _eventSubscription;
  final StreamController<MediaEvent> _eventController = StreamController<MediaEvent>.broadcast();
  final StreamController<MediaPlayerState> _stateController = StreamController<MediaPlayerState>.broadcast();
  
  // Player state
  String? _currentMediaId;
  MediaType? _currentMediaType;
  PlayerState _playerState = PlayerState.stopped;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  double _playbackSpeed = 1.0;
  double _volume = 1.0;
  bool _isLooping = false;
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  String? _currentMediaPath;
  // Prevent mixed backends within a session
  String _activeBackend = 'flutter'; // 'flutter' | 'native'
  
  // Playlist
  final List<MediaItem> _playlist = [];
  int _currentIndex = -1;
  PlaylistMode _playlistMode = PlaylistMode.sequential;
  
  MediaPlayerService({
    required LoggerService logger,
    @Named('mediaPlayer') required MethodChannel methodChannel,
    @Named('mediaPlayerEvents') required EventChannel eventChannel,
  }) : _logger = logger,
       _methodChannel = methodChannel,
       _eventChannel = eventChannel;
  
  /// Initialize media player
  Future<void> initialize() async {
    try {
      _logger.info('Initializing media player service...');
      
      // Set up event listener
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        _handleEvent,
        onError: (error) => _logger.error('Media player event error: $error'),
      );
      
      _logger.info('Media player service initialized');
    } catch (e) {
      _logger.error('Failed to initialize media player: $e');
      throw MediaPlayerException('Failed to initialize: $e');
    }
  }

  /// Basic play API for local media using native players
  Future<bool> playMedia({required String filePath, required MediaType type}) async {
    try {
      _assertBackend('flutter');
      final bool exists = File(filePath).existsSync();
      if (!exists) {
        _logger.error('Media file does not exist: $filePath');
        return false;
      }
      _currentMediaPath = filePath;
      _currentMediaType = type;
      if (type == MediaType.video) {
        await _videoController?.dispose();
        _videoController = VideoPlayerController.file(File(filePath));
        await _videoController!.initialize();
        await _videoController!.setLooping(_isLooping);
        await _videoController!.play();
        _videoController!.addListener(() {
          try {
            final Duration? d = _videoController?.value.duration;
            final Duration? p = _videoController?.value.position;
            if (d != null) _totalDuration = d;
            if (p != null) _currentPosition = p;
            _emitState();
          } catch (_) {}
        });
        _playerState = PlayerState.playing;
      } else if (type == MediaType.audio) {
        _audioPlayer ??= AudioPlayer();
        await _audioPlayer!.stop();
        await _audioPlayer!.play(DeviceFileSource(filePath));
        _audioPlayer!.onDurationChanged.listen((d) {
          _totalDuration = d;
          _emitState();
        });
        _audioPlayer!.onPositionChanged.listen((p) {
          _currentPosition = p;
          _emitState();
        });
        _playerState = PlayerState.playing;
      } else {
        // For images, update state only
        _playerState = PlayerState.playing;
      }
      _emitState();
      return true;
    } catch (e) {
      _logger.error('Failed to play media: $e');
      return false;
    }
  }

  Future<void> pauseMedia() async {
    try {
      if (_currentMediaType == MediaType.video) {
        await _videoController?.pause();
      } else if (_currentMediaType == MediaType.audio) {
        await _audioPlayer?.pause();
      }
      _playerState = PlayerState.paused;
      _emitState();
    } catch (e) {
      _logger.error('Failed to pause media: $e');
    }
  }

  Future<void> resumeMedia() async {
    try {
      if (_currentMediaType == MediaType.video) {
        await _videoController?.play();
      } else if (_currentMediaType == MediaType.audio) {
        await _audioPlayer?.resume();
      }
      _playerState = PlayerState.playing;
      _emitState();
    } catch (e) {
      _logger.error('Failed to resume media: $e');
    }
  }

  Future<void> stopMedia() async {
    try {
      await _videoController?.dispose();
      _videoController = null;
      if (_audioPlayer != null) {
        await _audioPlayer!.stop();
        await _audioPlayer!.dispose();
        _audioPlayer = null;
      }
      _currentMediaPath = null;
      _currentMediaType = null;
      _playerState = PlayerState.stopped;
      _emitState();
    } catch (e) {
      _logger.error('Failed to stop media: $e');
    }
  }

  Future<void> seekTo(Duration position) async {
    try {
      if (_currentMediaType == MediaType.video) {
        await _videoController?.seekTo(position);
      } else if (_currentMediaType == MediaType.audio) {
        await _audioPlayer?.seek(position);
      }
      _currentPosition = position;
      _emitState();
    } catch (e) {
      _logger.error('Failed to seek media: $e');
    }
  }
  
  /// Play media file
  Future<void> play({
    required String filePath,
    required MediaType mediaType,
    MediaItem? mediaItem,
  }) async {
    try {
      _assertBackend('native');
      _logger.info('Playing media: $filePath');
      
      final Map<String, dynamic> params = {
        'filePath': filePath,
        'mediaType': mediaType.toString().split('.').last,
        'playbackSpeed': _playbackSpeed,
        'volume': _volume,
        'isLooping': _isLooping,
      };
      
      if (mediaItem != null) {
        params['title'] = mediaItem.title;
        params['artist'] = mediaItem.artist;
        params['album'] = mediaItem.album;
        params['thumbnailPath'] = mediaItem.thumbnailPath;
      }
      
      await _methodChannel.invokeMethod('play', params);
      
      _currentMediaId = filePath;
      _currentMediaType = mediaType;
      _playerState = PlayerState.playing;
      
      _logger.info('Media playback started');
    } catch (e) {
      _logger.error('Failed to play media: $e');
      throw MediaPlayerException('Failed to play: $e');
    }
  }
  
  /// Pause playback
  Future<void> pause() async {
    try {
      await _methodChannel.invokeMethod('pause');
      _playerState = PlayerState.paused;
      _logger.info('Playback paused');
    } catch (e) {
      _logger.error('Failed to pause: $e');
    }
  }
  
  /// Resume playback
  Future<void> resume() async {
    try {
      await _methodChannel.invokeMethod('resume');
      _playerState = PlayerState.playing;
      _logger.info('Playback resumed');
    } catch (e) {
      _logger.error('Failed to resume: $e');
    }
  }
  
  /// Stop playback
  Future<void> stop() async {
    try {
      await _methodChannel.invokeMethod('stop');
      _playerState = PlayerState.stopped;
      _currentPosition = Duration.zero;
      _currentMediaId = null;
      _logger.info('Playback stopped');
    } catch (e) {
      _logger.error('Failed to stop: $e');
    }
  }
  
  /// Seek to position
  Future<void> seek(Duration position) async {
    try {
      await _methodChannel.invokeMethod('seek', {
        'position': position.inMilliseconds,
      });
      _currentPosition = position;
      _logger.info('Seeked to: ${position.inSeconds}s');
    } catch (e) {
      _logger.error('Failed to seek: $e');
    }
  }
  
  /// Set playback speed (0.25x to 2.0x)
  Future<void> setPlaybackSpeed(double speed) async {
    try {
      await _methodChannel.invokeMethod('setPlaybackSpeed', {
        'speed': speed,
      });
      _playbackSpeed = speed;
      _logger.info('Playback speed set to: ${speed}x');
    } catch (e) {
      _logger.error('Failed to set playback speed: $e');
    }
  }
  
  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    try {
      await _methodChannel.invokeMethod('setVolume', {
        'volume': volume,
      });
      _volume = volume;
      _logger.info('Volume set to: ${(volume * 100).toInt()}%');
    } catch (e) {
      _logger.error('Failed to set volume: $e');
    }
  }
  
  /// Toggle looping
  Future<void> setLooping(bool isLooping) async {
    try {
      await _methodChannel.invokeMethod('setLooping', {
        'isLooping': isLooping,
      });
      _isLooping = isLooping;
      _logger.info('Looping ${isLooping ? 'enabled' : 'disabled'}');
    } catch (e) {
      _logger.error('Failed to set looping: $e');
    }
  }
  
  /// Load playlist
  Future<void> loadPlaylist(List<MediaItem> items, {int startIndex = 0}) async {
    _playlist.clear();
    _playlist.addAll(items);
    _currentIndex = startIndex;
    
    if (_playlist.isNotEmpty && startIndex < _playlist.length) {
      final item = _playlist[startIndex];
      await play(
        filePath: item.filePath,
        mediaType: item.mediaType,
        mediaItem: item,
      );
    }
    
    _logger.info('Playlist loaded with ${items.length} items');
  }
  
  /// Play next in playlist
  Future<void> playNext() async {
    if (_playlist.isEmpty) return;
    
    switch (_playlistMode) {
      case PlaylistMode.sequential:
        if (_currentIndex < _playlist.length - 1) {
          _currentIndex++;
        } else {
          await stop();
          return;
        }
        break;
      case PlaylistMode.repeat:
        _currentIndex = (_currentIndex + 1) % _playlist.length;
        break;
      case PlaylistMode.shuffle:
        final random = Random();
        _currentIndex = random.nextInt(_playlist.length);
        break;
    }
    
    final item = _playlist[_currentIndex];
    await play(
      filePath: item.filePath,
      mediaType: item.mediaType,
      mediaItem: item,
    );
  }
  
  /// Play previous in playlist
  Future<void> playPrevious() async {
    if (_playlist.isEmpty) return;
    
    if (_currentIndex > 0) {
      _currentIndex--;
      final item = _playlist[_currentIndex];
      await play(
        filePath: item.filePath,
        mediaType: item.mediaType,
        mediaItem: item,
      );
    }
  }
  
  /// Set playlist mode
  void setPlaylistMode(PlaylistMode mode) {
    _playlistMode = mode;
    _logger.info('Playlist mode set to: ${mode.toString().split('.').last}');
  }
  
  /// Get media metadata
  Future<MediaMetadata> getMetadata(String filePath) async {
    try {
      final Map<dynamic, dynamic> result = await _methodChannel.invokeMethod('getMetadata', {
        'filePath': filePath,
      });
      
      return MediaMetadata.fromMap(Map<String, dynamic>.from(result));
    } catch (e) {
      _logger.error('Failed to get metadata: $e');
      throw MediaPlayerException('Failed to get metadata: $e');
    }
  }
  
  /// Generate thumbnail for video
  Future<String> generateThumbnail({
    required String videoPath,
    required String outputPath,
    Duration? position,
  }) async {
    try {
      final String thumbnailPath = await _methodChannel.invokeMethod('generateThumbnail', {
        'videoPath': videoPath,
        'outputPath': outputPath,
        'position': position?.inMilliseconds ?? 0,
      });
      
      _logger.info('Thumbnail generated: $thumbnailPath');
      return thumbnailPath;
    } catch (e) {
      _logger.error('Failed to generate thumbnail: $e');
      throw MediaPlayerException('Failed to generate thumbnail: $e');
    }
  }
  
  /// Extract audio waveform data
  Future<List<double>> getAudioWaveform(String audioPath) async {
    try {
      final List<dynamic> waveform = await _methodChannel.invokeMethod('getAudioWaveform', {
        'audioPath': audioPath,
      });
      
      return waveform.map((e) => (e as num).toDouble()).toList();
    } catch (e) {
      _logger.error('Failed to get audio waveform: $e');
      return [];
    }
  }
  
  /// Get current player state
  MediaPlayerState getState() {
    return MediaPlayerState(
      currentMediaId: _currentMediaId,
      mediaType: _currentMediaType,
      playerState: _playerState,
      currentPosition: _currentPosition,
      totalDuration: _totalDuration,
      playbackSpeed: _playbackSpeed,
      volume: _volume,
      isLooping: _isLooping,
      playlist: List.from(_playlist),
      currentIndex: _currentIndex,
      playlistMode: _playlistMode,
    );
  }
  
  /// Stream of media events
  Stream<MediaEvent> get eventStream => _eventController.stream;
  
  void _handleEvent(dynamic event) {
    try {
      final Map<String, dynamic> eventData = Map<String, dynamic>.from(event);
      final String eventType = eventData['type'] as String;
      
      switch (eventType) {
        case 'positionChanged':
          _currentPosition = Duration(milliseconds: eventData['position'] as int);
          _eventController.add(PositionChangedEvent(
            position: _currentPosition,
            timestamp: DateTime.now(),
          ));
          break;
        case 'durationChanged':
          _totalDuration = Duration(milliseconds: eventData['duration'] as int);
          _eventController.add(DurationChangedEvent(
            duration: _totalDuration,
            timestamp: DateTime.now(),
          ));
          break;
        case 'stateChanged':
          _playerState = PlayerState.values.firstWhere(
            (e) => e.toString().split('.').last == eventData['state'] as String,
          );
          _eventController.add(StateChangedEvent(
            state: _playerState,
            timestamp: DateTime.now(),
          ));
          break;
        case 'completed':
          _eventController.add(PlaybackCompletedEvent(
            timestamp: DateTime.now(),
          ));
          // Auto-play next if in playlist
          if (_playlist.isNotEmpty) {
            playNext();
          }
          break;
        case 'error':
          _eventController.add(PlaybackErrorEvent(
            error: eventData['error'] as String,
            timestamp: DateTime.now(),
          ));
          break;
      }
    } catch (e) {
      _logger.error('Failed to handle media event: $e');
    }
  }
  
  void dispose() {
    _eventSubscription?.cancel();
    _eventController.close();
    _stateController.close();
    stop();
    try { _videoController?.removeListener(() {}); } catch (_) {}
    // AudioPlayer listeners are canceled when disposing the player
    _activeBackend = 'flutter';
  }

  Stream<MediaPlayerState> get stateStream => _stateController.stream;

  void _emitState() {
    _stateController.add(getState());
  }

  void _assertBackend(String backend) {
    if (_activeBackend != backend && (_currentMediaPath != null)) {
      throw MediaPlayerException('Mixed playback backends within a session are not allowed');
    }
    _activeBackend = backend;
  }
}

// MediaType enum moved to app_state.dart

/// Player states
enum PlayerState {
  stopped,
  playing,
  paused,
  buffering,
  error,
}

/// Playlist modes
enum PlaylistMode {
  sequential,
  repeat,
  shuffle,
}

/// Media item model
class MediaItem {
  final String id;
  final String filePath;
  final String title;
  final String? artist;
  final String? album;
  final MediaType mediaType;
  final Duration? duration;
  final String? thumbnailPath;
  final Map<String, dynamic>? metadata;
  
  const MediaItem({
    required this.id,
    required this.filePath,
    required this.title,
    this.artist,
    this.album,
    required this.mediaType,
    this.duration,
    this.thumbnailPath,
    this.metadata,
  });
  
  factory MediaItem.fromFile(File file) {
    final String fileName = file.path.split('/').last;
    final String extension = fileName.split('.').last.toLowerCase();
    
    MediaType mediaType;
    if (['mp4', 'avi', 'mkv', 'mov', 'wmv', 'flv'].contains(extension)) {
      mediaType = MediaType.video;
    } else if (['mp3', 'aac', 'wav', 'flac', 'm4a', 'wma'].contains(extension)) {
      mediaType = MediaType.audio;
    } else if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(extension)) {
      mediaType = MediaType.image;
    } else {
      mediaType = MediaType.video; // Default
    }
    
    return MediaItem(
      id: file.path,
      filePath: file.path,
      title: fileName,
      mediaType: mediaType,
    );
  }
}

/// Media metadata model
class MediaMetadata {
  final String title;
  final String? artist;
  final String? album;
  final Duration? duration;
  final int? width;
  final int? height;
  final int? bitrate;
  final String? codec;
  final String? format;
  final Map<String, dynamic> rawMetadata;
  
  const MediaMetadata({
    required this.title,
    this.artist,
    this.album,
    this.duration,
    this.width,
    this.height,
    this.bitrate,
    this.codec,
    this.format,
    required this.rawMetadata,
  });
  
  factory MediaMetadata.fromMap(Map<String, dynamic> map) {
    return MediaMetadata(
      title: map['title'] as String,
      artist: map['artist'] as String?,
      album: map['album'] as String?,
      duration: map['duration'] != null ? Duration(milliseconds: map['duration'] as int) : null,
      width: map['width'] as int?,
      height: map['height'] as int?,
      bitrate: map['bitrate'] as int?,
      codec: map['codec'] as String?,
      format: map['format'] as String?,
      rawMetadata: map,
    );
  }
}

/// Media player state model
class MediaPlayerState {
  final String? currentMediaId;
  final MediaType? mediaType;
  final PlayerState playerState;
  final Duration currentPosition;
  final Duration totalDuration;
  final double playbackSpeed;
  final double volume;
  final bool isLooping;
  final List<MediaItem> playlist;
  final int currentIndex;
  final PlaylistMode playlistMode;
  final MediaItem? currentMedia;
  
  const MediaPlayerState({
    this.currentMediaId,
    this.mediaType,
    required this.playerState,
    required this.currentPosition,
    required this.totalDuration,
    required this.playbackSpeed,
    required this.volume,
    required this.isLooping,
    required this.playlist,
    required this.currentIndex,
    required this.playlistMode,
    this.currentMedia,
  });
  
  double get progress {
    if (totalDuration.inMilliseconds == 0) return 0.0;
    return currentPosition.inMilliseconds / totalDuration.inMilliseconds;
  }
  
  bool get isPlaying => playerState == PlayerState.playing;
  bool get isPaused => playerState == PlayerState.paused;
  bool get isStopped => playerState == PlayerState.stopped;
  bool get hasPlaylist => playlist.isNotEmpty;
  MediaItem? get currentItem => currentIndex >= 0 && currentIndex < playlist.length
      ? playlist[currentIndex]
      : null;
}

/// Media event base class
abstract class MediaEvent {
  final String type;
  final DateTime timestamp;
  
  const MediaEvent({
    required this.type,
    required this.timestamp,
  });
}

class PositionChangedEvent extends MediaEvent {
  final Duration position;
  
  const PositionChangedEvent({
    required this.position,
    required super.timestamp,
  }) : super(type: 'positionChanged');
}

class DurationChangedEvent extends MediaEvent {
  final Duration duration;
  
  const DurationChangedEvent({
    required this.duration,
    required super.timestamp,
  }) : super(type: 'durationChanged');
}

class StateChangedEvent extends MediaEvent {
  final PlayerState state;
  
  const StateChangedEvent({
    required this.state,
    required super.timestamp,
  }) : super(type: 'stateChanged');
}

class PlaybackCompletedEvent extends MediaEvent {
  const PlaybackCompletedEvent({
    required super.timestamp,
  }) : super(type: 'completed');
}

class PlaybackErrorEvent extends MediaEvent {
  final String error;
  
  const PlaybackErrorEvent({
    required this.error,
    required super.timestamp,
  }) : super(type: 'error');
}

/// Media player specific exception
class MediaPlayerException implements Exception {
  final String message;
  const MediaPlayerException(this.message);
  
  @override
  String toString() => 'MediaPlayerException: $message';
}
