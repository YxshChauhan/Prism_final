import 'package:flutter/material.dart';
import 'package:airlink/shared/models/app_state.dart';

class FilePreviewWidget extends StatelessWidget {
  const FilePreviewWidget({
    super.key,
    required this.file,
    this.onRemove,
    this.onTap,
  });

  final TransferFile file;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: _buildFileIcon(),
        title: Text(
          file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatFileSize(file.size),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (file.mimeType.isNotEmpty)
              Text(
                file.mimeType,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
          ],
        ),
        trailing: onRemove != null
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: onRemove,
              )
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildFileIcon() {
    IconData iconData;
    Color iconColor;

    switch (file.type) {
      case FileType.image:
        iconData = Icons.image;
        iconColor = Colors.blue;
        break;
      case FileType.video:
        iconData = Icons.videocam;
        iconColor = Colors.purple;
        break;
      case FileType.document:
        iconData = Icons.description;
        iconColor = Colors.orange;
        break;
      case FileType.audio:
        iconData = Icons.audiotrack;
        iconColor = Colors.green;
        break;
      case FileType.other:
        iconData = Icons.insert_drive_file;
        iconColor = Colors.grey;
        break;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 24,
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
