import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/shared/providers/advanced_features_providers.dart';
import 'package:airlink/shared/widgets/media_player_widgets.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;


class MediaPlayerPage extends ConsumerStatefulWidget {
  const MediaPlayerPage({super.key});

  @override
  ConsumerState<MediaPlayerPage> createState() => _MediaPlayerPageState();
}

class _MediaPlayerPageState extends ConsumerState<MediaPlayerPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  
  // Media player controllers
  VideoPlayerController? _videoController;
  AudioPlayer _audioPlayer = AudioPlayer();
  
  // Player state
  bool _isAudioPlaying = false;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  
  // Current media (removed unused fields)

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _setupAudioPlayer();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _setupAudioPlayer() {
    _audioPlayer.onDurationChanged.listen((duration) {
      setState(() {
        _audioDuration = duration;
      });
    });

    _audioPlayer.onPositionChanged.listen((position) {
      setState(() {
        _audioPosition = position;
      });
    });

    _audioPlayer.onPlayerStateChanged.listen((state) {
      setState(() {
        _isAudioPlaying = state == PlayerState.playing;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Media Player'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.video_library), text: 'Videos'),
            Tab(icon: Icon(Icons.audio_file), text: 'Audio'),
            Tab(icon: Icon(Icons.image), text: 'Images'),
            Tab(icon: Icon(Icons.favorite), text: 'Favorites'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildVideoTab(),
          _buildAudioTab(),
          _buildImageTab(),
          _buildFavoritesTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFilePicker,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryTab(FileCategory category, MediaType mediaType, String errorLabel) {
    return Consumer(
      builder: (context, ref, child) {
        final mediaFiles = ref.watch(getFilesByCategoryProvider((category, FileSortBy.name)));
        
        return mediaFiles.when(
          data: (files) => _buildMediaGrid(files, mediaType),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error loading $errorLabel: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(getFilesByCategoryProvider((category, FileSortBy.name))),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVideoTab() {
    return _buildCategoryTab(FileCategory.video, MediaType.video, 'videos');
  }

  Widget _buildAudioTab() {
    return _buildCategoryTab(FileCategory.audio, MediaType.audio, 'audio');
  }

  Widget _buildImageTab() {
    return _buildCategoryTab(FileCategory.image, MediaType.image, 'images');
  }

  Widget _buildFavoritesTab() {
    return Consumer(
      builder: (context, ref, child) {
        final favorites = ref.watch(getFavoritesProvider);
        
        return favorites.when(
          data: (files) => _buildMediaGrid(files, MediaType.unknown),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error loading favorites: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(getFavoritesProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMediaGrid(List<FileItem> files, MediaType mediaType) {
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getEmptyIcon(mediaType),
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _getEmptyMessage(mediaType),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to add media files',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        final favorites = ref.watch(favoritesListProvider);
        final isFavorite = favorites.contains(file.id);
        
        return MediaFileCard(
          file: file,
          onTap: () => _playMedia(file),
          onLongPress: () => _showMediaOptions(file),
          onFavoriteToggle: () => _toggleFavorite(file),
          isFavorite: isFavorite,
        );
      },
    );
  }

  IconData _getEmptyIcon(MediaType mediaType) {
    switch (mediaType) {
      case MediaType.video:
        return Icons.video_library_outlined;
      case MediaType.audio:
        return Icons.audio_file_outlined;
      case MediaType.image:
        return Icons.image_outlined;
      case MediaType.unknown:
        return Icons.favorite_outline;
    }
  }

  String _getEmptyMessage(MediaType mediaType) {
    switch (mediaType) {
      case MediaType.video:
        return 'No videos found';
      case MediaType.audio:
        return 'No audio files found';
      case MediaType.image:
        return 'No images found';
      case MediaType.unknown:
        return 'No favorites yet';
    }
  }

  void _playMedia(FileItem file) async {
    try {
      final fileExtension = path.extension(file.path).toLowerCase();
      
      if (_isVideoFile(fileExtension)) {
        await _playVideo(file);
      } else if (_isAudioFile(fileExtension)) {
        await _playAudio(file);
      } else if (_isImageFile(fileExtension)) {
        await _viewImage(file);
      } else {
        // Try to open with system default app
        await _openWithSystemApp(file);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing media: $e')),
      );
    }
  }

  bool _isVideoFile(String extension) {
    return ['.mp4', '.avi', '.mov', '.mkv', '.wmv', '.flv', '.webm'].contains(extension);
  }

  bool _isAudioFile(String extension) {
    return ['.mp3', '.wav', '.aac', '.flac', '.ogg', '.m4a', '.wma'].contains(extension);
  }

  bool _isImageFile(String extension) {
    return ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg'].contains(extension);
  }

  Future<void> _playVideo(FileItem file) async {
    try {
      // Dispose previous controller
      await _videoController?.dispose();
      
      _videoController = VideoPlayerController.file(File(file.path));
      await _videoController!.initialize();

      // Show video player dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _VideoPlayerDialog(
          controller: _videoController!,
          file: file,
          onClose: () {
            Navigator.of(context).pop();
            _videoController?.pause();
          },
          onPlayPause: () {
            if (_videoController!.value.isPlaying) {
              _videoController!.pause();
            } else {
              _videoController!.play();
            }
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing video: $e')),
      );
    }
  }

  Future<void> _playAudio(FileItem file) async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(DeviceFileSource(file.path));
      
      // no local field tracking needed

      // Show audio player dialog
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => _AudioPlayerDialog(
          file: file,
          audioPlayer: _audioPlayer,
          isPlaying: _isAudioPlaying,
          position: _audioPosition,
          duration: _audioDuration,
          onPlayPause: () async {
            if (_isAudioPlaying) {
              await _audioPlayer.pause();
            } else {
              await _audioPlayer.resume();
            }
          },
          onSeek: (position) async {
            await _audioPlayer.seek(position);
          },
          onClose: () {
            Navigator.of(context).pop();
            _audioPlayer.stop();
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing audio: $e')),
      );
    }
  }

  Future<void> _viewImage(FileItem file) async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => _ImageViewerDialog(
        file: file,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
  }

  Future<void> _openWithSystemApp(FileItem file) async {
    try {
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open file: ${result.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e')),
      );
    }
  }

  void _toggleFavorite(FileItem file) {
    final favorites = ref.read(favoritesListProvider);
    final isFavorite = favorites.contains(file.id);
    
    if (isFavorite) {
      // Remove from favorites
      ref.read(favoritesListProvider.notifier).state = 
          favorites.where((id) => id != file.id).toList();
    } else {
      // Add to favorites
      ref.read(favoritesListProvider.notifier).state = [...favorites, file.id];
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isFavorite ? 'Removed from favorites: ${file.name}' : 'Added to favorites: ${file.name}'),
      ),
    );
  }

  void _shareMedia(FileItem file) async {
    try {
      final xFile = XFile(file.path);
      await Share.shareXFiles(
        [xFile],
        subject: 'Sharing ${file.name}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing media: $e')),
      );
    }
  }

  void _deleteMedia(FileItem file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Media'),
        content: Text('Are you sure you want to delete "${file.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final fileObj = File(file.path);
                await fileObj.delete();
                
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Deleted: ${file.name}')),
                );
                
                // Refresh media lists
                ref.invalidate(getFilesByCategoryProvider((FileCategory.video, FileSortBy.name)));
                ref.invalidate(getFilesByCategoryProvider((FileCategory.audio, FileSortBy.name)));
                ref.invalidate(getFilesByCategoryProvider((FileCategory.image, FileSortBy.name)));
                ref.invalidate(getFavoritesProvider);
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting media: $e')),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Media'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search for media files...',
            prefixIcon: Icon(Icons.search),
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              Navigator.of(context).pop();
              _performSearch(value.trim());
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final query = _searchController.text.trim();
              if (query.isNotEmpty) {
                Navigator.of(context).pop();
                _performSearch(query);
              }
            },
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  void _performSearch(String query) async {
    try {
      // Invalidate and refresh providers with search query
      ref.invalidate(getFilesByCategoryProvider((FileCategory.video, FileSortBy.name)));
      ref.invalidate(getFilesByCategoryProvider((FileCategory.audio, FileSortBy.name)));
      ref.invalidate(getFilesByCategoryProvider((FileCategory.image, FileSortBy.name)));
      
      // Show search results
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Searching for: $query')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching: $e')),
      );
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => const MediaPlayerSettingsDialog(),
    );
  }

  void _showFilePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.video_library),
            title: const Text('Import Videos'),
            onTap: () {
              Navigator.pop(context);
              _importMedia(file_picker.FileType.video);
            },
          ),
          ListTile(
            leading: const Icon(Icons.audio_file),
            title: const Text('Import Audio'),
            onTap: () {
              Navigator.pop(context);
              _importMedia(file_picker.FileType.audio);
            },
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Import Images'),
            onTap: () {
              Navigator.pop(context);
              _importMedia(file_picker.FileType.image);
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Import All Media'),
            onTap: () {
              Navigator.pop(context);
              _importMedia(file_picker.FileType.media);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _importMedia(file_picker.FileType fileType) async {
    try {
      final result = await file_picker.FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: fileType,
      );
      
      if (result == null || result.files.isEmpty) return;
      
      // Get app documents directory (platform-safe)
      final baseDir = await getApplicationDocumentsDirectory();
      final documentsDir = Directory(path.join(baseDir.path, 'AirLink', 'Media'));
      if (!await documentsDir.exists()) {
        await documentsDir.create(recursive: true);
      }
      
      int importedCount = 0;
      for (final file in result.files) {
        if (file.path != null) {
          try {
            final sourceFile = File(file.path!);
            final fileName = path.basename(file.path!);
            final destPath = path.join(documentsDir.path, fileName);
            
            await sourceFile.copy(destPath);
            importedCount++;
          } catch (e) {
            // Continue with next file if one fails
            continue;
          }
        }
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported $importedCount media file(s)')),
      );
      
      // Refresh media lists
      ref.invalidate(getFilesByCategoryProvider((FileCategory.video, FileSortBy.name)));
      ref.invalidate(getFilesByCategoryProvider((FileCategory.audio, FileSortBy.name)));
      ref.invalidate(getFilesByCategoryProvider((FileCategory.image, FileSortBy.name)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing media: $e')),
      );
    }
  }

  void _showMediaOptions(FileItem file) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.favorite),
            title: const Text('Add to Favorites'),
            onTap: () {
              Navigator.pop(context);
              _toggleFavorite(file);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share'),
            onTap: () {
              Navigator.pop(context);
              _shareMedia(file);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Delete'),
            onTap: () {
              Navigator.pop(context);
              _deleteMedia(file);
            },
          ),
        ],
      ),
    );
  }
}

/// Video player dialog widget
class _VideoPlayerDialog extends StatefulWidget {
  final VideoPlayerController controller;
  final FileItem file;
  final VoidCallback onClose;
  final VoidCallback? onPlayPause;

  const _VideoPlayerDialog({
    required this.controller,
    required this.file,
    required this.onClose,
    this.onPlayPause,
  });

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            AppBar(
              title: Text(widget.file.name),
              actions: [
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),
            VideoProgressIndicator(
              widget.controller,
              allowScrubbing: true,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    widget.onPlayPause?.call();
                  },
                  icon: Icon(
                    widget.controller.value.isPlaying
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Audio player dialog widget
class _AudioPlayerDialog extends StatefulWidget {
  final FileItem file;
  final AudioPlayer audioPlayer;
  final bool isPlaying;
  final Duration position;
  final Duration duration;
  final VoidCallback onPlayPause;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onClose;

  const _AudioPlayerDialog({
    required this.file,
    required this.audioPlayer,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.onPlayPause,
    required this.onSeek,
    required this.onClose,
  });

  @override
  State<_AudioPlayerDialog> createState() => _AudioPlayerDialogState();
}

class _AudioPlayerDialogState extends State<_AudioPlayerDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text(widget.file.name),
              actions: [
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    Icons.music_note,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.file.name,
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: widget.position.inMilliseconds.toDouble(),
                    max: widget.duration.inMilliseconds.toDouble(),
                    onChanged: (value) {
                      widget.onSeek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(widget.position)),
                      Text(_formatDuration(widget.duration)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: widget.onPlayPause,
                        icon: Icon(
                          widget.isPlaying ? Icons.pause : Icons.play_arrow,
                        ),
                        iconSize: 48,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

/// Image viewer dialog widget
class _ImageViewerDialog extends StatelessWidget {
  final FileItem file;
  final VoidCallback onClose;

  const _ImageViewerDialog({
    required this.file,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            AppBar(
              title: Text(file.name),
              actions: [
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Expanded(
              child: InteractiveViewer(
                child: Image.file(
                  File(file.path),
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
