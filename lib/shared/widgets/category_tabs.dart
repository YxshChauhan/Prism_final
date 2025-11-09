import 'package:flutter/material.dart';

/// Horizontal scrollable category tabs inspired by Zapya
class CategoryTabs extends StatefulWidget {
  final List<CategoryItem> categories;
  final int selectedIndex;
  final ValueChanged<int> onCategorySelected;
  final bool showIcons;
  final bool showCounts;

  const CategoryTabs({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.onCategorySelected,
    this.showIcons = true,
    this.showCounts = false,
  });

  @override
  State<CategoryTabs> createState() => _CategoryTabsState();
}

class _CategoryTabsState extends State<CategoryTabs> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.categories.length,
        itemBuilder: (context, index) {
          final category = widget.categories[index];
          final isSelected = index == widget.selectedIndex;
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildCategoryTab(category, index, isSelected),
          );
        },
      ),
    );
  }

  Widget _buildCategoryTab(CategoryItem category, int index, bool isSelected) {
    return GestureDetector(
      onTap: () => widget.onCategorySelected(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showIcons && category.icon != null) ...[
              Icon(
                category.icon,
                size: 20,
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              category.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (widget.showCounts && category.count != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  category.count.toString(),
                  style: TextStyle(
                    color: isSelected 
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Category item model
class CategoryItem {
  final String name;
  final IconData? icon;
  final int? count;
  final String? id;

  const CategoryItem({
    required this.name,
    this.icon,
    this.count,
    this.id,
  });
}

/// Predefined categories for file transfer
class FileCategories {
  static const List<CategoryItem> defaultCategories = [
    CategoryItem(
      name: 'All',
      icon: Icons.folder_outlined,
      id: 'all',
    ),
    CategoryItem(
      name: 'Photos',
      icon: Icons.photo_outlined,
      id: 'photos',
    ),
    CategoryItem(
      name: 'Videos',
      icon: Icons.videocam_outlined,
      id: 'videos',
    ),
    CategoryItem(
      name: 'Music',
      icon: Icons.music_note_outlined,
      id: 'music',
    ),
    CategoryItem(
      name: 'Documents',
      icon: Icons.description_outlined,
      id: 'documents',
    ),
    CategoryItem(
      name: 'Apps',
      icon: Icons.apps_outlined,
      id: 'apps',
    ),
    CategoryItem(
      name: 'Contacts',
      icon: Icons.contacts_outlined,
      id: 'contacts',
    ),
    CategoryItem(
      name: 'Files',
      icon: Icons.folder_outlined,
      id: 'files',
    ),
  ];
}
