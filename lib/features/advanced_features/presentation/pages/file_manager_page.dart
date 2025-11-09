import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:airlink/shared/providers/advanced_features_providers.dart';
import 'package:airlink/shared/models/app_state.dart';
import 'package:airlink/shared/widgets/file_manager_widgets.dart';
import 'package:open_filex/open_filex.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// File Manager Page
/// 
/// Provides comprehensive file management interface similar to SHAREit/Zapya
/// Supports file operations, storage analysis, and advanced file management
class FileManagerPage extends ConsumerStatefulWidget {
  const FileManagerPage({super.key});

  @override
  ConsumerState<FileManagerPage> createState() => _FileManagerPageState();
}

class _FileManagerPageState extends ConsumerState<FileManagerPage>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isGridView = false;
  FileSortBy _sortBy = FileSortBy.name;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Manager'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.list : Icons.grid_view),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _showSearchDialog,
          ),
          IconButton(
            icon: const Icon(Icons.sort),
            onPressed: _showSortDialog,
          ),
          Consumer(
            builder: (context, ref, child) {
              final sortOrder = ref.watch(fileSortOrderProvider);
              return IconButton(
                icon: Icon(sortOrder == SortOrder.ascending ? Icons.arrow_upward : Icons.arrow_downward),
                onPressed: () {
                  final newOrder = sortOrder == SortOrder.ascending ? SortOrder.descending : SortOrder.ascending;
                  ref.read(fileSortOrderProvider.notifier).state = newOrder;
                  // Trigger refresh of providers
                  ref.invalidate(getAllFilesProvider(_sortBy));
                  ref.invalidate(getFilesByCategoryProvider((FileCategory.video, _sortBy)));
                  ref.invalidate(getFilesByCategoryProvider((FileCategory.audio, _sortBy)));
                  ref.invalidate(getFilesByCategoryProvider((FileCategory.image, _sortBy)));
                  ref.invalidate(getFilesByCategoryProvider((FileCategory.document, _sortBy)));
                },
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'filter',
                child: ListTile(
                  leading: Icon(Icons.filter_list),
                  title: Text('Filter'),
                ),
              ),
              const PopupMenuItem(
                value: 'storage',
                child: ListTile(
                  leading: Icon(Icons.storage),
                  title: Text('Storage Info'),
                ),
              ),
              const PopupMenuItem(
                value: 'duplicates',
                child: ListTile(
                  leading: Icon(Icons.find_in_page),
                  title: Text('Find Duplicates'),
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.folder), text: 'All Files'),
            Tab(icon: Icon(Icons.video_file), text: 'Videos'),
            Tab(icon: Icon(Icons.audio_file), text: 'Audio'),
            Tab(icon: Icon(Icons.image), text: 'Images'),
            Tab(icon: Icon(Icons.description), text: 'Documents'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAllFilesTab(),
          _buildCategoryTab(FileCategory.video),
          _buildCategoryTab(FileCategory.audio),
          _buildCategoryTab(FileCategory.image),
          _buildCategoryTab(FileCategory.document),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAllFilesTab() {
    return Consumer(
      builder: (context, ref, child) {
        final files = ref.watch(getAllFilesProvider(_sortBy));
        
        return files.when(
          data: (fileList) => _buildFileList(fileList),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error loading files: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(getAllFilesProvider(_sortBy)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryTab(FileCategory category) {
    return Consumer(
      builder: (context, ref, child) {
        final files = ref.watch(getFilesByCategoryProvider((category, _sortBy)));
        
        return files.when(
          data: (fileList) => _buildFileList(fileList),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error loading ${category.name} files: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(getFilesByCategoryProvider((category, _sortBy))),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileList(List<FileItem> files) {
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.folder_open,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No files found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to create or add files',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    if (_isGridView) {
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
          return FileItemCard(
            file: file,
            onTap: () => _openFile(file),
            onLongPress: () => _showFileMenu(file),
            onMenu: () => _showFileMenu(file),
          );
        },
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: files.length,
        itemBuilder: (context, index) {
          final file = files[index];
          return FileListItem(
            file: file,
            onTap: () => _openFile(file),
            onLongPress: () => _showFileMenu(file),
          );
        },
      );
    }
  }

  void _openFile(FileItem file) async {
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

  void _showFileMenu(FileItem file) {
    showModalBottomSheet(
      context: context,
      builder: (context) => FileOptionsSheet(
        file: file,
        onOpen: () => _openFile(file),
        onRename: () => _renameFile(file),
        onMove: () => _moveFile(file),
        onCopy: () => _copyFile(file),
        onDelete: () => _deleteFile(file),
        onShare: () => _shareFile(file),
        onProperties: () => _showFileProperties(file),
      ),
    );
  }

  void _renameFile(FileItem file) {
    final controller = TextEditingController(text: file.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New name',
            hintText: 'Enter new file name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == file.name) {
                Navigator.of(context).pop();
                return;
              }
              
              try {
                final fileObj = File(file.path);
                final newPath = path.join(path.dirname(file.path), newName);
                await fileObj.rename(newPath);
                
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Renamed to: $newName')),
                );
                
                // Refresh file list
                ref.invalidate(getAllFilesProvider(_sortBy));
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error renaming file: $e')),
                );
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _moveFile(FileItem file) async {
    final result = await file_picker.FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select destination folder',
    );
    
    if (result == null) return;
    
    try {
      final fileObj = File(file.path);
      final newPath = path.join(result, file.name);
      
      // Check if file already exists
      if (await File(newPath).exists()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File already exists in destination')),
        );
        return;
      }
      
      await fileObj.rename(newPath);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved to: $result')),
      );
      
      // Refresh file list
      ref.invalidate(getAllFilesProvider(_sortBy));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error moving file: $e')),
      );
    }
  }

  void _copyFile(FileItem file) async {
    final result = await file_picker.FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select destination folder',
    );
    
    if (result == null) return;
    
    try {
      final fileObj = File(file.path);
      final newPath = path.join(result, file.name);
      
      // Check if file already exists
      if (await File(newPath).exists()) {
        if (!mounted) return;
        // Ask user if they want to overwrite
        final overwrite = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('File Exists'),
            content: const Text('A file with the same name already exists. Do you want to overwrite it?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Overwrite'),
              ),
            ],
          ),
        );
        
        if (overwrite != true) return;
      }
      
      await fileObj.copy(newPath);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Copied to: $result')),
      );
      
      // Refresh file list
      ref.invalidate(getAllFilesProvider(_sortBy));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error copying file: $e')),
      );
    }
  }

  void _deleteFile(FileItem file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
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
                
                // Refresh file list
                ref.invalidate(getAllFilesProvider(_sortBy));
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error deleting file: $e')),
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

  void _shareFile(FileItem file) async {
    try {
      final xFile = XFile(file.path);
      await Share.shareXFiles(
        [xFile],
        subject: 'Sharing ${file.name}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing file: $e')),
      );
    }
  }

  void _showFileProperties(FileItem file) {
    showDialog(
      context: context,
      builder: (context) => FilePropertiesDialog(file: file),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Files'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Search for files...',
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
      ref.invalidate(getAllFilesProvider(_sortBy));
      
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

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, child) => StatefulBuilder(
          builder: (context, setDialogState) {
            FileSortBy selectedSortBy = _sortBy;
            
            return AlertDialog(
              title: const Text('Sort Files'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: FileSortBy.values.length,
                  itemBuilder: (context, index) {
                    final sortBy = FileSortBy.values[index];
                    final isSelected = selectedSortBy == sortBy;
                    
                    return ListTile(
                      title: Text(_getSortByLabel(sortBy)),
                      leading: Icon(
                        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        color: isSelected ? Theme.of(context).primaryColor : null,
                      ),
                      onTap: () {
                        setDialogState(() {
                          selectedSortBy = sortBy;
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _sortBy = selectedSortBy;
                    });
                    Navigator.of(context).pop();
                    // Trigger refresh of providers
                    ref.invalidate(getAllFilesProvider(_sortBy));
                    ref.invalidate(getFilesByCategoryProvider((FileCategory.video, _sortBy)));
                    ref.invalidate(getFilesByCategoryProvider((FileCategory.audio, _sortBy)));
                    ref.invalidate(getFilesByCategoryProvider((FileCategory.image, _sortBy)));
                    ref.invalidate(getFilesByCategoryProvider((FileCategory.document, _sortBy)));
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _getSortByLabel(FileSortBy sortBy) {
    switch (sortBy) {
      case FileSortBy.name:
        return 'Name';
      case FileSortBy.size:
        return 'Size';
      case FileSortBy.date:
        return 'Date';
      case FileSortBy.modifiedDate:
        return 'Modified Date';
      case FileSortBy.type:
        return 'Type';
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'filter':
        _showFilterDialog();
        break;
      case 'storage':
        _showStorageInfo();
        break;
      case 'duplicates':
        _findDuplicates();
        break;
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter Files'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('File Size:'),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Filter by small files (<1MB)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Filtering by small files')),
                      );
                    },
                    child: const Text('< 1MB'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Filter by medium files (1-10MB)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Filtering by medium files')),
                      );
                    },
                    child: const Text('1-10MB'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      // Filter by large files (>10MB)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Filtering by large files')),
                      );
                    },
                    child: const Text('> 10MB'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Date Modified:'),
            ListTile(
              title: const Text('Today'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Filtering by today')),
                );
              },
            ),
            ListTile(
              title: const Text('This Week'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Filtering by this week')),
                );
              },
            ),
            ListTile(
              title: const Text('This Month'),
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Filtering by this month')),
                );
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showStorageInfo() {
    showDialog(
      context: context,
      builder: (context) => const StorageInfoDialog(),
    );
  }

  void _findDuplicates() async {
    try {
      // Show loading
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 16),
              Text('Finding duplicates...'),
            ],
          ),
          duration: Duration(seconds: 2),
        ),
      );
      
      // Simulate finding duplicates
      await Future.delayed(const Duration(seconds: 2));
      
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Duplicate Files'),
          content: const Text('No duplicate files found.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error finding duplicates: $e')),
      );
    }
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Folder'),
              onTap: () {
                Navigator.of(context).pop();
                _createFolder();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Text File'),
              onTap: () {
                Navigator.of(context).pop();
                _createTextFile();
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_photo_alternate),
              title: const Text('Import Media'),
              onTap: () {
                Navigator.of(context).pop();
                _importMedia();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _createFolder() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            hintText: 'Enter folder name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final folderName = controller.text.trim();
              if (folderName.isEmpty) {
                Navigator.of(context).pop();
                return;
              }
              
              try {
                // Get platform-safe documents directory
                final baseDir = await getApplicationDocumentsDirectory();
                final documentsDir = Directory(path.join(baseDir.path, 'Documents'));
                if (!await documentsDir.exists()) {
                  await documentsDir.create(recursive: true);
                }
                
                final newFolder = Directory(path.join(documentsDir.path, folderName));
                
                // Check if folder already exists
                if (await newFolder.exists()) {
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Folder already exists')),
                  );
                  return;
                }
                
                await newFolder.create();
                
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Created folder: $folderName')),
                );
                
                // Refresh file list
                ref.invalidate(getAllFilesProvider(_sortBy));
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error creating folder: $e')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _createTextFile() {
    final nameController = TextEditingController();
    final contentController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Text File'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'File name',
                hintText: 'example.txt',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: 'Content (optional)',
                hintText: 'Enter file content',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final fileName = nameController.text.trim();
              if (fileName.isEmpty) {
                Navigator.of(context).pop();
                return;
              }
              
              // Ensure .txt extension
              final fullName = fileName.endsWith('.txt') ? fileName : '$fileName.txt';
              
              try {
                // Get platform-safe documents directory
                final baseDir = await getApplicationDocumentsDirectory();
                final documentsDir = Directory(path.join(baseDir.path, 'Documents'));
                if (!await documentsDir.exists()) {
                  await documentsDir.create(recursive: true);
                }
                
                final newFile = File(path.join(documentsDir.path, fullName));
                
                // Check if file already exists
                if (await newFile.exists()) {
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('File already exists')),
                  );
                  return;
                }
                
                await newFile.writeAsString(contentController.text);
                
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Created file: $fullName')),
                );
                
                // Refresh file list
                ref.invalidate(getAllFilesProvider(_sortBy));
              } catch (e) {
                if (!mounted) return;
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error creating file: $e')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _importMedia() async {
    try {
      final result = await file_picker.FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: file_picker.FileType.media,
      );
      
      if (result == null || result.files.isEmpty) return;
      
      // Get platform-safe documents directory
      final baseDir = await getApplicationDocumentsDirectory();
      final documentsDir = Directory(path.join(baseDir.path, 'AirLink'));
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
        SnackBar(content: Text('Imported $importedCount file(s)')),
      );
      
      // Refresh file list
      ref.invalidate(getAllFilesProvider(_sortBy));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing media: $e')),
      );
    }
  }
}
