import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../domain/entities/product_entity.dart';
import '../../data/services/product_csv_import_service.dart';
import '../bloc/inventory_bloc.dart';
import '../bloc/inventory_event.dart';

class ProductImportDialog extends StatefulWidget {
  final Map<String, ProductEntity> existingInventory;
  final LocalizationService t;
  final String langCode;

  const ProductImportDialog({
    super.key,
    required this.existingInventory,
    required this.t,
    required this.langCode,
  });

  @override
  State<ProductImportDialog> createState() => _ProductImportDialogState();
}

class _ProductImportDialogState extends State<ProductImportDialog> {
  final ProductCsvImportService _service = ProductCsvImportService();
  ProductImportPreview? _preview;
  String? _filePath;
  Map<ProductCsvField, int>? _userMapping;
  bool _loading = false;

  String _tr(String key, {List<String> params = const []}) =>
      widget.t.translate(key, languageCode: widget.langCode, params: params);

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );
    if (result != null && result.files.single.path != null) {
      _filePath = result.files.single.path!;
      await _parse();
    }
  }

  Future<void> _parse() async {
    if (_filePath == null) return;
    setState(() => _loading = true);
    try {
      _preview = await _service.parse(
        filePath: _filePath!,
        existingInventory: widget.existingInventory,
        mapping: _userMapping,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _remap(ProductCsvField field, int? newIdx) {
    setState(() {
      _userMapping = Map<ProductCsvField, int>.from(
        _userMapping ?? _service.autoMapHeaders(_preview?.headers ?? []),
      );
      if (newIdx != null) {
        _userMapping![field] = newIdx;
      } else {
        _userMapping!.remove(field);
      }
      _parse();
    });
  }

  Future<void> _commit() async {
    if (_preview == null) return;
    final (toCreate, toUpdate) = _service.buildEntities(
      _preview!,
      widget.existingInventory,
    );
    if (toCreate.isEmpty && toUpdate.isEmpty) return;
    context.read<InventoryBloc>().add(
      ImportProducts(toCreate: toCreate, toUpdate: toUpdate),
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          const PhosphorIcon(PhosphorIcons.uploadSimple, size: 24),
          const SizedBox(width: Spacing.sm),
          Flexible(
            child: Text(
              _tr('inventory.import.title'),
              style: TextStyles.heading3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_preview == null)
                Center(
                  child: Column(
                    children: [
                      const SizedBox(height: Spacing.lg),
                      OutlinedButton.icon(
                        icon: const Icon(PhosphorIcons.fileCsv),
                        label: Text(_tr('inventory.import.pick')),
                        onPressed: _pickFile,
                      ),
                      const SizedBox(height: Spacing.sm),
                      Text(
                        _tr('inventory.import.pickHint'),
                        style: TextStyles.caption,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else ...[
                // Summary row
                Row(
                  children: [
                    _StatChip(
                      label: _tr('inventory.import.rows'),
                      value: '${_preview!.rows.length}',
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: Spacing.sm),
                    _StatChip(
                      label: _tr('inventory.import.valid'),
                      value: '${_preview!.validCount}',
                      color: Colors.green,
                    ),
                    const SizedBox(width: Spacing.sm),
                    _StatChip(
                      label: _tr('inventory.import.invalid'),
                      value: '${_preview!.invalidCount}',
                      color: Colors.red,
                    ),
                  ],
                ),
                const Divider(height: 24),
                // Column mapping
                Text(_tr('inventory.import.mapping'), style: TextStyles.body),
                const SizedBox(height: Spacing.xs),
                ..._mappingTiles(),
                const Divider(height: 24),
                // Sample rows
                if (_preview!.rows.isNotEmpty) ...[
                  Text(_tr('inventory.import.preview'), style: TextStyles.body),
                  const SizedBox(height: Spacing.xs),
                  _PreviewTable(
                    preview: _preview!,
                    t: widget.t,
                    langCode: widget.langCode,
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(_tr('cancel')),
        ),
        if (_preview == null)
          FilledButton.icon(
            icon: const Icon(PhosphorIcons.fileCsv, size: 18),
            label: Text(_tr('inventory.import.pick')),
            onPressed: _pickFile,
          )
        else ...[
          TextButton.icon(
            icon: const Icon(PhosphorIcons.arrowClockwise, size: 18),
            label: Text(_tr('inventory.import.reparse')),
            onPressed: _loading ? null : _parse,
          ),
          FilledButton.icon(
            key: const Key('inventoryImportConfirm'),
            icon: const Icon(PhosphorIcons.uploadSimple, size: 18),
            label: Text(_tr('inventory.import.import')),
            onPressed: _preview!.validCount > 0 && !_loading ? _commit : null,
          ),
        ],
      ],
    );
  }

  List<Widget> _mappingTiles() {
    final preview = _preview!;
    return ProductCsvField.values.map((field) {
      final idx = _userMapping?[field] ?? preview.mapping[field];
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 140,
              child: Text(_tr(field.labelKey), style: TextStyles.body),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: DropdownButton<int>(
                isExpanded: true,
                value: idx,
                hint: Text(_tr('inventory.import.unmapped')),
                items: [
                  DropdownMenuItem<int>(
                    value: null,
                    child: Text(_tr('inventory.import.unmapped')),
                  ),
                  ...List.generate(
                    preview.headers.length,
                    (i) => DropdownMenuItem(
                      value: i,
                      child: Text(preview.headers[i]),
                    ),
                  ),
                ],
                onChanged: (v) => _remap(field, v),
              ),
            ),
            if (field.isRequired && idx == null)
              PhosphorIcon(PhosphorIcons.warning, size: 16, color: Colors.red),
          ],
        ),
      );
    }).toList();
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyles.heading3.copyWith(color: color)),
          Text(label, style: TextStyles.caption.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _PreviewTable extends StatelessWidget {
  final ProductImportPreview preview;
  final LocalizationService t;
  final String langCode;

  const _PreviewTable({
    required this.preview,
    required this.t,
    required this.langCode,
  });

  String _tr(String key, {List<String> params = const []}) =>
      t.translate(key, languageCode: langCode, params: params);

  @override
  Widget build(BuildContext context) {
    final displayRows = preview.rows.take(15).toList();
    final headers = [
      '#',
      _tr(ProductCsvField.name.labelKey),
      _tr(ProductCsvField.barcode.labelKey),
      _tr(ProductCsvField.price.labelKey),
      _tr(ProductCsvField.stock.labelKey),
      _tr(ProductCsvField.category.labelKey),
      'Status',
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: headers
            .map((h) => DataColumn(label: Text(h, style: TextStyles.caption)))
            .toList(),
        rows: displayRows.map((row) {
          return DataRow(
            color: WidgetStateProperty.resolveWith((states) {
              if (row.errors.isNotEmpty)
                return Colors.red.withValues(alpha: 0.05);
              if (row.warnings.isNotEmpty)
                return Colors.amber.withValues(alpha: 0.05);
              return null;
            }),
            cells: [
              DataCell(Text('${row.rowNumber}')),
              DataCell(Text(row.name ?? '')),
              DataCell(Text(row.barcode ?? '')),
              DataCell(Text(row.price?.toStringAsFixed(2) ?? '')),
              DataCell(Text(row.stock?.toString() ?? '')),
              DataCell(Text(row.category ?? '')),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (row.errors.isNotEmpty)
                      PhosphorIcon(
                        PhosphorIcons.warningCircle,
                        size: 16,
                        color: Colors.red,
                      ),
                    if (row.errors.isEmpty && row.warnings.isNotEmpty)
                      PhosphorIcon(
                        PhosphorIcons.warning,
                        size: 16,
                        color: Colors.amber,
                      ),
                    if (row.errors.isEmpty && row.warnings.isEmpty)
                      PhosphorIcon(
                        PhosphorIcons.checkCircle,
                        size: 16,
                        color: Colors.green,
                      ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
