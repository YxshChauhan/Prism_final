import 'package:flutter/material.dart';
import 'package:airlink/shared/models/app_state.dart';

/// File picker card widget for selecting files
class FilePickerCard extends StatelessWidget {
  final List<TransferFile> selectedFiles;
  final VoidCallback onFilesSelected;
  final ValueChanged<TransferFile> onFileRemoved;
  final VoidCallback onClearAll;

  const FilePickerCard({
    super.key,
    required this.selectedFiles,
    required this.onFilesSelected,
    required this.onFileRemoved,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: AppTheme.cardElevation,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.paddingMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.attach_file,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Select Files',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (selectedFiles.isNotEmpty)
                  TextButton(
                    onPressed: onClearAll,
                    child: const Text('Clear All'),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // File selection buttons
            _buildFileSelectionButtons(context),
            
            const SizedBox(height: 16),
            
            // Selected files list
            if (selectedFiles.isNotEmpty) ...[
              Text(
                'Selected Files (${selectedFiles.length})',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              _buildSelectedFilesList(context),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildFileSelectionButtons(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildSelectionButton(
          context,
          icon: Icons.photo,
          label: 'Photos',
          onTap: () => _selectFiles(context, AirLinkFileType.image),
        ),
        _buildSelectionButton(
          context,
          icon: Icons.videocam,
          label: 'Videos',
          onTap: () => _selectFiles(context, AirLinkFileType.video),
        ),
        _buildSelectionButton(
          context,
          icon: Icons.audiotrack,
          label: 'Music',
          onTap: () => _selectFiles(context, AirLinkFileType.audio),
        ),
        _buildSelectionButton(
          context,
          icon: Icons.description,
          label: 'Documents',
          onTap: () => _selectFiles(context, AirLinkFileType.document),
        ),
        _buildSelectionButton(
          context,
          icon: Icons.folder,
          label: 'Browse All',
          onTap: () => _selectFiles(context, AirLinkFileType.any),
        ),
      ],
    );
  }
  
  Widget _buildSelectionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSelectedFilesList(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: selectedFiles.length,
        itemBuilder: (context, index) {
          final file = selectedFiles[index];
          return _buildFileItem(context, file);
        },
      ),
    );
  }
  
  Widget _buildFileItem(BuildContext context, TransferFile file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _getFileIcon(file.mimeType),
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _formatFileSize(file.size),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => onFileRemoved(file),
            icon: const Icon(Icons.close, size: 20),
            tooltip: 'Remove file',
          ),
        ],
      ),
    );
  }
  
  void _selectFiles(BuildContext context, AirLinkFileType fileType) {
    // TODO: Implement file selection based on file type
    onFilesSelected();
  }
  
  IconData _getFileIcon(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.videocam;
    if (mimeType.startsWith('audio/')) return Icons.audiotrack;
    if (mimeType.startsWith('text/')) return Icons.description;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('zip') || mimeType.contains('rar')) return Icons.archive;
    return Icons.insert_drive_file;
  }
  
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

enum AirLinkFileType {
  image,
  video,
  audio,
  document,
  any,
}