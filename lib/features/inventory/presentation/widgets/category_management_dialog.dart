import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../features/settings/data/services/localization_service.dart';
import '../../../../features/settings/presentation/bloc/settings_bloc.dart';
import '../bloc/category_bloc.dart';
import '../bloc/category_event.dart';

class CategoryManagementDialog extends StatefulWidget {
  const CategoryManagementDialog({super.key});

  @override
  State<CategoryManagementDialog> createState() =>
      _CategoryManagementDialogState();
}

class _CategoryManagementDialogState extends State<CategoryManagementDialog> {
  final _newCategoryController = TextEditingController();
  final _renameController = TextEditingController();
  String? _renaming;
  String? _deleting;

  @override
  void initState() {
    super.initState();
    _newCategoryController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _newCategoryController.dispose();
    _renameController.dispose();
    super.dispose();
  }

  void _addCategory(BuildContext context) {
    final name = _newCategoryController.text.trim();
    if (name.isEmpty) return;
    _newCategoryController.clear();
    context.read<CategoryBloc>().add(AddCategory(name));
  }

  void _confirmRename(BuildContext context, String oldName) {
    final newName = _renameController.text.trim();
    if (newName.isEmpty || newName == oldName) {
      setState(() => _renaming = null);
      return;
    }
    context.read<CategoryBloc>().add(
      RenameCategory(oldName: oldName, newName: newName),
    );
    setState(() => _renaming = null);
    _renameController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.read<SettingsBloc>().state.settings.languageCode;
    final t = LocalizationService();
    final categories = context.watch<CategoryBloc>().state.categories;

    return AlertDialog(
      title: Text(
        t.translate('inventory.category.manage', languageCode: langCode),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCategoryController,
                    decoration: InputDecoration(
                      labelText: t.translate(
                        'inventory.category.addHint',
                        languageCode: langCode,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _addCategory(context),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _addCategory(context),
                  child: Text(
                    t.translate(
                      'inventory.category.add',
                      languageCode: langCode,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: categories.isEmpty
                  ? const SizedBox.shrink()
                  : ListView(
                      shrinkWrap: true,
                      children: categories
                          .map(
                            (category) =>
                                _buildRow(context, category.name, t, langCode),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    String name,
    LocalizationService t,
    String langCode,
  ) {
    if (_deleting == name) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.translate(
                'inventory.category.deleteConfirm',
                languageCode: langCode,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    context.read<CategoryBloc>().add(DeleteCategory(name));
                    setState(() => _deleting = null);
                  },
                  child: Text(
                    t.translate('inventory.delete.btn', languageCode: langCode),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _deleting = null),
                  child: Text(t.translate('cancel', languageCode: langCode)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (_renaming == name) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _renameController,
                autofocus: true,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _confirmRename(context, name),
              ),
            ),
            IconButton(
              tooltip: t.translate(
                'inventory.category.save',
                languageCode: langCode,
              ),
              icon: const Icon(PhosphorIcons.check),
              onPressed: () => _confirmRename(context, name),
            ),
            IconButton(
              tooltip: t.translate('cancel', languageCode: langCode),
              icon: const Icon(PhosphorIcons.x),
              onPressed: () {
                _renameController.clear();
                setState(() => _renaming = null);
              },
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: Theme.of(context).textTheme.bodyLarge),
          ),
          IconButton(
            tooltip: t.translate(
              'inventory.category.rename',
              languageCode: langCode,
            ),
            icon: const Icon(PhosphorIcons.pencil),
            onPressed: () {
              _renameController.text = name;
              setState(() => _renaming = name);
            },
          ),
          IconButton(
            tooltip: t.translate(
              'inventory.category.deleteConfirm',
              languageCode: langCode,
            ),
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() => _deleting = name),
          ),
        ],
      ),
    );
  }
}
