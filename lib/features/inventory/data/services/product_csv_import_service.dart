import 'package:cashier_system/features/inventory/domain/entities/prep_category.dart';

import '../../../../core/exports/csv_writer.dart';
import '../../domain/entities/product_entity.dart';
import '../../domain/helpers/barcode_generator.dart';

/// Target product fields that can be mapped from CSV columns.
enum ProductCsvField {
  barcode,
  name,
  price,
  stock,
  category,
  notes;

  String get labelKey {
    switch (this) {
      case ProductCsvField.barcode:
        return 'inventory.product.barcode';
      case ProductCsvField.name:
        return 'inventory.product.name';
      case ProductCsvField.price:
        return 'inventory.product.price';
      case ProductCsvField.stock:
        return 'inventory.product.stock';
      case ProductCsvField.category:
        return 'inventory.product.category';
      case ProductCsvField.notes:
        return 'inventory.product.notes';
    }
  }

  bool get isRequired => this == ProductCsvField.name;
}

/// One parsed CSV row with per-row validation results.
class ProductImportRow {
  final int rowNumber;
  final String? name;
  final String? barcode;
  final double? price;
  final int? stock;
  final String? category;
  final String? notes;
  final List<String> errors;
  final List<String> warnings;

  const ProductImportRow({
    required this.rowNumber,
    this.name,
    this.barcode,
    this.price,
    this.stock,
    this.category,
    this.notes,
    this.errors = const [],
    this.warnings = const [],
  });

  bool get isValid => errors.isEmpty && (name?.trim().isNotEmpty ?? false);
}

/// Result of parsing a CSV file: detected mapping + validated rows.
class ProductImportPreview {
  final List<String> headers;
  final Map<ProductCsvField, int> mapping;
  final List<ProductImportRow> rows;

  const ProductImportPreview({
    required this.headers,
    required this.mapping,
    required this.rows,
  });

  int get validCount => rows.where((r) => r.isValid).length;
  int get invalidCount => rows.length - validCount;
  bool get hasErrors => invalidCount > 0;
}

/// Parses a products CSV and performs "smart checking":
/// - auto-detects column mapping from header aliases (English + Arabic)
/// - tolerates formatted numbers (spaces, comma decimals, Arabic-Indic digits)
/// - auto-generates barcodes for missing/blank barcodes
/// - flags missing names, invalid numbers, duplicate barcodes (in-file and
///   against the existing inventory)
class ProductCsvImportService {
  static const Map<ProductCsvField, Set<String>> _aliases = {
    ProductCsvField.name: {
      'name',
      'product',
      'productname',
      'item',
      'title',
      'description',
      'الاسم',
      'اسمالمنتج',
      'المنتج',
      'الصنف',
      'الوصف',
    },
    ProductCsvField.barcode: {
      'barcode',
      'code',
      'barcodeno',
      'sku',
      'الباركود',
      'باركود',
      'الرمز',
      'الرمزالشريطي',
      'الكود',
    },
    ProductCsvField.price: {
      'price',
      'saleprice',
      'sellingprice',
      'unitprice',
      'السعر',
      'سعرالبيع',
      'سعر',
      'سعرالمنتج',
    },
    ProductCsvField.stock: {
      'stock',
      'quantity',
      'qty',
      'count',
      'inventory',
      'available',
      'المخزون',
      'الكمية',
      'كمية',
      'متوفر',
      'العدد',
    },
    ProductCsvField.category: {
      'category',
      'categories',
      'group',
      'قسم',
      'فئة',
      'التصنيف',
      'الفئة',
      'الفئات',
    },
    ProductCsvField.notes: {
      'notes',
      'note',
      'remark',
      'remarks',
      'comments',
      'ملاحظات',
      'ملاحظة',
    },
  };

  /// Normalizes a header for alias matching.
  static String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-\u200f\u200e]'), '');

  /// Auto-detects the column index for each product field from [headers].
  Map<ProductCsvField, int> autoMapHeaders(List<String> headers) {
    final mapping = <ProductCsvField, int>{};
    for (var i = 0; i < headers.length; i++) {
      final normalized = _normalize(headers[i]);
      if (normalized.isEmpty) continue;
      for (final entry in _aliases.entries) {
        if (!mapping.containsKey(entry.key) &&
            entry.value.contains(normalized)) {
          mapping[entry.key] = i;
          break;
        }
      }
    }
    return mapping;
  }

  /// Parses [filePath] and validates rows against [existingInventory].
  /// [mapping] overrides auto-detection (used for manual remapping).
  Future<ProductImportPreview> parse({
    required String filePath,
    required Map<String, ProductEntity> existingInventory,
    Map<ProductCsvField, int>? mapping,
  }) async {
    final rows = await readCsvRows(filePath);
    if (rows.isEmpty) {
      return ProductImportPreview(
        headers: const [],
        mapping: const {},
        rows: const [],
      );
    }
    final headers = rows.first;
    final effectiveMapping = mapping ?? autoMapHeaders(headers);
    final takenBarcodes = {...existingInventory.keys};
    final fileBarcodes = <String>{};
    final parsed = <ProductImportRow>[];

    for (var i = 1; i < rows.length; i++) {
      final cells = rows[i];
      String cell(ProductCsvField field) {
        final idx = effectiveMapping[field];
        return (idx != null && idx < cells.length) ? cells[idx].trim() : '';
      }

      final barcodeCell = cell(ProductCsvField.barcode);
      final name = cell(ProductCsvField.name);
      final price = _parseDouble(cell(ProductCsvField.price));
      final stock = _parseInt(cell(ProductCsvField.stock));

      final errors = <String>[];
      final warnings = <String>[];

      if (name.isEmpty) {
        errors.add('name_required');
      }

      String barcode = barcodeCell;
      if (barcode.isEmpty) {
        barcode = generateNumericBarcode(
          isTaken: (b) => takenBarcodes.contains(b) || fileBarcodes.contains(b),
        );
        takenBarcodes.add(barcode);
        fileBarcodes.add(barcode);
        warnings.add('barcode_auto');
      } else if (fileBarcodes.contains(barcode)) {
        errors.add('barcode_duplicate_file');
      } else if (takenBarcodes.contains(barcode)) {
        warnings.add('barcode_exists');
      }
      fileBarcodes.add(barcode);
      takenBarcodes.add(barcode);

      if (price != null && price < 0) errors.add('price_negative');
      if (stock != null && stock < 0) errors.add('stock_negative');

      // Column present but value unparseable -> explicit error instead of silent 0
      final priceIdx = effectiveMapping[ProductCsvField.price];
      if (priceIdx != null &&
          priceIdx < cells.length &&
          cells[priceIdx].trim().isNotEmpty &&
          price == null) {
        errors.add('price_invalid');
      }
      final stockIdx = effectiveMapping[ProductCsvField.stock];
      if (stockIdx != null &&
          stockIdx < cells.length &&
          cells[stockIdx].trim().isNotEmpty &&
          stock == null) {
        errors.add('stock_invalid');
      }

      parsed.add(
        ProductImportRow(
          rowNumber: i + 1,
          name: name,
          barcode: barcode,
          price: price,
          stock: stock,
          category: cell(ProductCsvField.category).isEmpty
              ? null
              : cell(ProductCsvField.category),
          notes: cell(ProductCsvField.notes),
          errors: errors,
          warnings: warnings,
        ),
      );
    }

    return ProductImportPreview(
      headers: headers,
      mapping: effectiveMapping,
      rows: parsed,
    );
  }

  /// Builds [ProductEntity] list for valid rows. Existing barcodes are
  /// returned separately so the caller can update instead of creating.
  (List<ProductEntity> toCreate, List<ProductEntity> toUpdate) buildEntities(
    ProductImportPreview preview,
    Map<String, ProductEntity> existingInventory,
  ) {
    final toCreate = <ProductEntity>[];
    final toUpdate = <ProductEntity>[];
    for (final row in preview.rows) {
      if (!row.isValid) continue;
      final existing = existingInventory[row.barcode];
      final product = ProductEntity(
        barcode: row.barcode ?? '',
        name: row.name?.trim() ?? '',
        price: row.price ?? existing?.price ?? 0,
        stock: row.stock ?? existing?.stock ?? 0,
        category: row.category ?? existing?.category,
        notes: row.notes ?? existing?.notes ?? '',
        prepCategory: existing?.prepCategory ?? PrepCategory.general,
      );
      if (existing != null) {
        toUpdate.add(product);
      } else {
        toCreate.add(product);
      }
    }
    return (toCreate, toUpdate);
  }

  /// Tolerant number parsing: strips currency suffixes, spaces, thousands
  /// separators; accepts comma decimals and Arabic-Indic digits.
  static double? _parseDouble(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    var normalized = value
        .replaceAllMapped(
          RegExp(r'[٠-٩]'),
          (m) => '${'٠١٢٣٤٥٦٧٨٩'.indexOf(m[0]!)}',
        )
        .replaceAllMapped(
          RegExp(r'[۰-۹]'),
          (m) => '${'۰۱۲۳۴۵۶۷۸۹'.indexOf(m[0]!)}',
        )
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[جJ]\.?م\.?$', caseSensitive: false), '')
        .replaceAll(RegExp(r'EGP$', caseSensitive: false), '')
        .replaceAll(RegExp(r'E£$|£E$', caseSensitive: false), '');
    if (normalized.isEmpty) return null;
    if (normalized.contains('.')) {
      normalized = normalized.replaceAll(',', '');
    } else if (normalized.contains(',')) {
      final parts = normalized.split(',');
      if (parts.length == 2) {
        normalized = '${parts[0]}.${parts[1]}';
      } else if (parts.length > 2) {
        normalized = normalized.replaceAll(',', '');
      }
    }
    return double.tryParse(normalized);
  }

  static int? _parseInt(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final num = _parseDouble(value);
    return num?.round();
  }
}
