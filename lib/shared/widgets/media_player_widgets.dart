import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/core/services/media_player_service.dart';
import 'package:airlink/shared/providers/advanced_features_providers.dart';
import 'package:airlink/shared/models/app_state.dart';

/// Represents a radio option item with a value and label
class RadioItem<T> {
  final T value;
  final String label;
  
  const RadioItem({
    required this.value,
    required this.label,
  });
}

/// Media Player Control Widget
/// Provides playback controls for the media player
class MediaPlayerControls extends StatefulWidget {
  final MediaPlayerState state;
  final VoidCallback onPlay;
  final VoidCallback onPause;
  final VoidCallback onStop;
  final Function(Duration) onSeek;
  final Function(double) onVolumeChange;
  final Function(double) onSpeedChange;

  const MediaPlayerControls({
    super.key,
    required this.state,
    required this.onPlay,
    required this.onPause,
    required this.onStop,
    required this.onSeek,
    required this.onVolumeChange,
    required this.onSpeedChange,
  });

  @override
  State<MediaPlayerControls> createState() => _MediaPlayerControlsState();
}

class _MediaPlayerControlsState extends State<MediaPlayerControls> {
  MediaPlayerState get state => widget.state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(red: 0, green: 0, blue: 0, alpha: 0x1A),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar
          _buildProgressBar(),
          const SizedBox(height: 12),
          
          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: widget.onStop,
                icon: const Icon(Icons.stop),
                tooltip: 'Stop',
              ),
              IconButton(
                onPressed: state.isPlaying ? widget.onPause : widget.onPlay,
                icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
                tooltip: state.isPlaying ? 'Pause' : 'Play',
              ),
              IconButton(
                onPressed: () => _showSpeedDialog(context),
                icon: const Icon(Icons.speed),
                tooltip: 'Speed',
              ),
              IconButton(
                onPressed: () => _showVolumeDialog(context),
                icon: const Icon(Icons.volume_up),
                tooltip: 'Volume',
              ),
            ],
          ),
          
          // Media info
          if (state.currentMedia != null) ...[
            const SizedBox(height: 8),
            Text(
              state.currentMedia!.title,
              style: Theme.of(context).textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${_formatDuration(state.currentPosition)} / ${_formatDuration(state.totalDuration)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final progress = state.totalDuration.inMilliseconds > 0
        ? state.currentPosition.inMilliseconds / state.totalDuration.inMilliseconds
        : 0.0;

    return Column(
      children: [
        Slider(
          value: progress.clamp(0.0, 1.0),
          onChanged: (value) {
            final newPosition = Duration(
              milliseconds: (value * state.totalDuration.inMilliseconds).round(),
            );
            widget.onSeek(newPosition);
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(state.currentPosition)),
            Text(_formatDuration(state.totalDuration)),
          ],
        ),
      ],
    );
  }

  // ignore: deprecated_member_use
  // ignore: deprecated_member_use
  void _showSpeedDialog(BuildContext context) {
    final currentSpeed = state.playbackSpeed;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Playback Speed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var speed in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                  ListTile(
                    title: Text('${speed}x'),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    leading: Radio<double>(
                      value: speed,
                      // ignore: deprecated_member_use
                      groupValue: currentSpeed,
                      // ignore: deprecated_member_use
                      onChanged: (value) {
                        if (value != null) {
                          widget.onSpeedChange(value);
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ignore: deprecated_member_use
  void _showVolumeDialog(BuildContext context) {
    final currentVolume = state.volume;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Volume'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Slider(
                  value: currentVolume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  label: '${(currentVolume * 100).round()}%',
                  onChanged: widget.onVolumeChange,
                ),
                Text('${(currentVolume * 100).round()}%'),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Video Thumbnail Card
class VideoThumbnailCard extends StatelessWidget {
  final FileItem file;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const VideoThumbnailCard({
    super.key,
    required this.file,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Thumbnail placeholder
                  Container(
                    color: const Color(0xFFE0E0E0),
                    child: const Icon(
                      Icons.video_library,
                      size: 48,
                      color: const Color(0xFF9E9E9E),
                    ),
                  ),
                  // Duration overlay
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xB3000000),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatFileSize(file.size),
                        style: const TextStyle(
                          color: const Color(0xFFFFFFFF),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _formatFileSize(file.size),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Audio File Card
class AudioFileCard extends StatelessWidget {
  final FileItem file;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const AudioFileCard({
    super.key,
    required this.file,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.audiotrack),
        title: Text(file.name),
        subtitle: Text(_formatFileSize(file.size)),
        trailing: const Icon(Icons.play_arrow),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Image Thumbnail Card
class ImageThumbnailCard extends StatelessWidget {
  final FileItem file;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const ImageThumbnailCard({
    super.key,
    required this.file,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          color: const Color(0xFFE0E0E0),
          child: const Icon(
            Icons.image,
            size: 32,
            color: const Color(0xFF9E9E9E),
          ),
        ),
      ),
    );
  }
}

/// Media File Card
class MediaFileCard extends StatelessWidget {
  final FileItem file;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback? onFavoriteToggle;
  final bool isFavorite;

  const MediaFileCard({
    super.key,
    required this.file,
    required this.onTap,
    required this.onLongPress,
    this.onFavoriteToggle,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: _getFileIcon(),
        title: Text(file.name),
        subtitle: Text('${_formatFileSize(file.size)} • ${_formatDate(file.modifiedAt)}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onFavoriteToggle != null)
              IconButton(
                onPressed: onFavoriteToggle,
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? const Color(0xFFF44336) : null,
                ),
              ),
            const Icon(Icons.more_vert),
          ],
        ),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );
  }

  Widget _getFileIcon() {
    switch (file.category) {
      case FileCategory.video:
        return const Icon(Icons.video_library);
      case FileCategory.audio:
        return const Icon(Icons.audiotrack);
      case FileCategory.image:
        return const Icon(Icons.image);
      case FileCategory.document:
        return const Icon(Icons.description);
      default:
        return const Icon(Icons.insert_drive_file);
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

/// Playlist Widget
class PlaylistWidget extends ConsumerWidget {
  const PlaylistWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlist = ref.watch(currentPlaylistProvider);
    final mediaPlayerState = ref.watch(mediaPlayerStateProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Playlist (${playlist.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: playlist.length,
              itemBuilder: (context, index) {
                final item = playlist[index];
                final isCurrent = mediaPlayerState?.currentMedia?.id == item.id;
                
                return ListTile(
                  leading: _getMediaIcon(item.mediaType),
                  title: Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(_formatDuration(item.duration ?? Duration.zero)),
                  trailing: isCurrent
                      ? const Icon(Icons.equalizer, color: Color(0xFF2196F3))
                      : null,
                  onTap: () {
                    // TODO: Play selected item
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _getMediaIcon(MediaType type) {
    switch (type) {
      case MediaType.video:
        return const Icon(Icons.video_library);
      case MediaType.audio:
        return const Icon(Icons.audiotrack);
      case MediaType.image:
        return const Icon(Icons.image);
      default:
        return const Icon(Icons.insert_drive_file);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Media Player Settings Dialog
class MediaPlayerSettingsDialog extends ConsumerWidget {
  const MediaPlayerSettingsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volume = ref.watch(mediaPlayerVolumeProvider);
    final speed = ref.watch(mediaPlayerSpeedProvider);
    final isLooping = ref.watch(isMediaPlayerLoopingProvider);

    return AlertDialog(
      title: const Text('Media Player Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Volume setting
          ListTile(
            title: const Text('Volume'),
            subtitle: Slider(
              value: volume,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              label: '${(volume * 100).round()}%',
              onChanged: (value) {
                ref.read(mediaPlayerVolumeProvider.notifier).state = value;
              },
            ),
          ),
          
          // Speed setting
          ListTile(
            title: const Text('Playback Speed'),
            subtitle: Slider(
              value: speed,
              min: 0.25,
              max: 2.0,
              divisions: 7,
              label: '${speed}x',
              onChanged: (value) {
                ref.read(mediaPlayerSpeedProvider.notifier).state = value;
              },
            ),
          ),
          
          // Loop setting
          SwitchListTile(
            title: const Text('Loop Playlist'),
            subtitle: const Text('Repeat playlist when finished'),
            value: isLooping,
            onChanged: (value) {
              ref.read(isMediaPlayerLoopingProvider.notifier).state = value;
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

/// Media File Options Sheet
class MediaFileOptionsSheet extends StatelessWidget {
  final FileItem file;
  final VoidCallback onPlay;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  const MediaFileOptionsSheet({
    super.key,
    required this.file,
    required this.onPlay,
    required this.onAddToPlaylist,
    required this.onShare,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('Play'),
            onTap: () {
              Navigator.pop(context);
              onPlay();
            },
          ),
          ListTile(
            leading: const Icon(Icons.playlist_add),
            title: const Text('Add to Playlist'),
            onTap: () {
              Navigator.pop(context);
              onAddToPlaylist();
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share'),
            onTap: () {
              Navigator.pop(context);
              onShare();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Color(0xFFF44336)),
            title: const Text('Delete', style: TextStyle(color: Color(0xFFF44336))),
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
        ],
      ),
    );
  }
}
