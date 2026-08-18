import 'dart:io';

import '../../../../core/exports/csv_writer.dart';
import '../../../../core/exports/pdf_generator.dart';
import '../../domain/entities/product_entity.dart';

/// Exports the current inventory products to a CSV or PDF file in the
/// unified export directory (fetched from Settings).
class ProductDocumentExportService {
  /// Builds CSV-style rows: header + one row per product (sorted by name).
  List<List<String>> buildRows(Map<String, ProductEntity> products) {
    final rows = <List<String>>[
      [
        'Barcode',
        'Name',
        'Price (EGP)',
        'Cost (EGP)',
        'Stock',
        'Category',
        'Notes',
      ],
    ];
    final sorted = products.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    for (final p in sorted) {
      rows.add([
        p.barcode,
        p.name,
        p.price.toStringAsFixed(2),
        p.stock.toString(),
        p.category ?? '',
        p.notes,
      ]);
    }
    return rows;
  }

  /// Writes the export file and returns its path.
  Future<String> export({
    required Map<String, ProductEntity> products,
    required String format,
    required String exportDirectoryPath,
    String title = 'Products Export',
  }) async {
    final dir = Directory(exportDirectoryPath);
    await dir.create(recursive: true);
    final now = DateTime.now();
    final stamp =
        '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
    final isCsv = format == 'csv';
    final path = '${dir.path}/products_$stamp.${isCsv ? 'csv' : 'pdf'}';
    final rows = buildRows(products);
    if (isCsv) {
      await writeCsvRows(rows, path);
    } else {
      final bytes = await generateTablePdf(rows, title: title);
      await File(path).writeAsBytes(bytes);
    }
    return path;
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}
