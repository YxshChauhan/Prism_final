import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:airlink/shared/models/app_state.dart' as app_state;
import 'package:airlink/features/transfer/presentation/widgets/file_preview_widget.dart';
import 'package:airlink/features/transfer/presentation/widgets/device_selector_widget.dart';
import 'package:airlink/shared/models/transfer_models.dart' as unified;
import 'package:airlink/features/transfer/domain/repositories/transfer_repository.dart';
import 'package:airlink/core/services/dependency_injection.dart';

class SendPickerPage extends ConsumerStatefulWidget {
  const SendPickerPage({super.key});

  @override
  ConsumerState<SendPickerPage> createState() => _SendPickerPageState();
}

class _SendPickerPageState extends ConsumerState<SendPickerPage> {
  final List<app_state.TransferFile> _selectedFiles = [];
  bool _isSelectingFiles = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Files'),
        actions: [
          if (_selectedFiles.isNotEmpty)
            TextButton(
              onPressed: _selectedFiles.isNotEmpty ? _showDeviceSelector : null,
              child: const Text('Next'),
            ),
        ],
      ),
      body: Column(
        children: [
          // File Selection Section
          _buildFileSelectionSection(),
          
          // Selected Files List
          if (_selectedFiles.isNotEmpty) ...[
            const Divider(),
            Expanded(
              child: _buildSelectedFilesList(),
            ),
          ],
          
          // Empty State
          if (_selectedFiles.isEmpty)
            Expanded(
              child: _buildEmptyState(),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSelectingFiles ? null : _selectFiles,
        icon: _isSelectingFiles
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add),
        label: Text(_isSelectingFiles ? 'Selecting...' : 'Select Files'),
      ),
    );
  }

  Widget _buildFileSelectionSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Files to Send',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildFileTypeButton(
                    icon: Icons.photo,
                    label: 'Photos',
                    onTap: () => _selectFiles(fileType: file_picker.FileType.image),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFileTypeButton(
                    icon: Icons.videocam,
                    label: 'Videos',
                    onTap: () => _selectFiles(fileType: file_picker.FileType.video),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildFileTypeButton(
                    icon: Icons.description,
                    label: 'Documents',
                    onTap: () => _selectFiles(fileType: file_picker.FileType.any),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildFileTypeButton(
                    icon: Icons.folder,
                    label: 'All Files',
                    onTap: () => _selectFiles(fileType: file_picker.FileType.any),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileTypeButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFilesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _selectedFiles.length,
      itemBuilder: (context, index) {
        final file = _selectedFiles[index];
        return FilePreviewWidget(
          file: file,
          onRemove: () => _removeFile(file),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_upload,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No files selected',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to select files',
            style: TextStyle(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectFiles({file_picker.FileType? fileType}) async {
    setState(() {
      _isSelectingFiles = true;
    });

    try {
      final result = await file_picker.FilePicker.platform.pickFiles(
        type: fileType ?? file_picker.FileType.any,
        allowMultiple: true,
        withData: false,
        withReadStream: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final newFiles = result.files.map((file) {
          return app_state.TransferFile(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: file.name,
            path: file.path ?? '',
            size: file.size,
            mimeType: _getMimeType(file.extension),
            selectedAt: DateTime.now(),
            type: _getFileType(file.extension),
            createdAt: DateTime.now(),
          );
        }).toList();

        setState(() {
          _selectedFiles.addAll(newFiles);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to select files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSelectingFiles = false;
        });
      }
    }
  }

  void _removeFile(app_state.TransferFile file) {
    setState(() {
      _selectedFiles.remove(file);
    });
  }

  void _showDeviceSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DeviceSelectorWidget(
        files: _selectedFiles,
        onSend: (deviceId) {
          Navigator.of(context).pop();
          _sendFiles(deviceId);
        },
      ),
    );
  }

  void _sendFiles(String deviceId) async {
    try {
      // Get selected files
      final selectedFiles = _selectedFiles;
      if (selectedFiles.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select files to send'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Sending files...'),
            ],
          ),
        ),
      );

      // Create transfer files
      final transferFiles = selectedFiles.map((file) => unified.TransferFile(
        id: file.id,
        name: file.name,
        path: file.path,
        size: file.size,
        mimeType: file.mimeType,
      )).toList();

      // Start transfer session
      final transferRepository = getIt<TransferRepository>();
      final sessionId = await transferRepository.startTransferSession(
        targetDeviceId: deviceId,
        connectionMethod: 'wifi_aware',
        files: transferFiles,
      );

      // Send files
      await transferRepository.sendFiles(
        sessionId: sessionId,
        files: transferFiles,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Files sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear selection
      setState(() {
        _selectedFiles.clear();
      });

    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send files: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  String _getMimeType(String? extension) {
    if (extension == null) return 'application/octet-stream';
    
    switch (extension.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'pdf':
        return 'application/pdf';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  app_state.FileType _getFileType(String? extension) {
    if (extension == null) return app_state.FileType.other;
    
    final ext = extension.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp'].contains(ext)) {
      return app_state.FileType.image;
    } else if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext)) {
      return app_state.FileType.video;
    } else if (['pdf', 'doc', 'docx', 'txt', 'rtf'].contains(ext)) {
      return app_state.FileType.document;
    } else if (['mp3', 'wav', 'aac', 'flac'].contains(ext)) {
      return app_state.FileType.audio;
    } else {
      return app_state.FileType.other;
    }
  }
}
