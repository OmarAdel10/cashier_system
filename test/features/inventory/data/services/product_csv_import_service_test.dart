import 'dart:io';

import 'package:cashier_system/features/inventory/data/services/product_csv_import_service.dart';
import 'package:cashier_system/features/inventory/domain/entities/product_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProductCsvImportService service;

  setUp(() => service = ProductCsvImportService());

  Future<String> writeCsv(String content) async {
    final file = File(
      '${Directory.systemTemp.createTempSync('import_test').path}/products.csv',
    );
    await file.writeAsString(content);
    return file.path;
  }

  test('auto-maps English headers', () {
    final mapping = service.autoMapHeaders([
      'Barcode',
      'Product Name',
      'Sale Price',
      'Cost',
      'Stock',
      'Category',
      'Notes',
    ]);
    expect(mapping[ProductCsvField.barcode], 0);
    expect(mapping[ProductCsvField.name], 1);
    expect(mapping[ProductCsvField.price], 2);
    expect(mapping[ProductCsvField.purchasePrice], 3);
    expect(mapping[ProductCsvField.stock], 4);
    expect(mapping[ProductCsvField.category], 5);
    expect(mapping[ProductCsvField.notes], 6);
  });

  test('auto-maps Arabic headers', () {
    final mapping = service.autoMapHeaders([
      'الباركود',
      'اسم المنتج',
      'السعر',
      'سعر الشراء',
      'الكمية',
      'الفئة',
    ]);
    expect(mapping[ProductCsvField.barcode], 0);
    expect(mapping[ProductCsvField.name], 1);
    expect(mapping[ProductCsvField.price], 2);
    expect(mapping[ProductCsvField.purchasePrice], 3);
    expect(mapping[ProductCsvField.stock], 4);
    expect(mapping[ProductCsvField.category], 5);
  });

  test(
    'parses and validates rows, treats existing barcode as update',
    () async {
      final path = await writeCsv(
        'name,barcode,price,cost,stock\n'
        'Pen,123,10.50,5,100\n'
        ',456,,,,\n'
        'Bad,000,-5,2,3\n'
        'Book,789,20,2,3\n',
      );
      final preview = await service.parse(
        filePath: path,
        existingInventory: {'789': ProductEntity(barcode: '789', name: 'Book')},
      );
      expect(preview.rows.length, 4);

      expect(preview.rows[0].isValid, isTrue);
      expect(preview.rows[0].barcode, '123');

      // Missing name -> invalid, but barcode auto-generated
      expect(preview.rows[1].isValid, isFalse);
      expect(preview.rows[1].barcode, isNotNull);

      // Negative price -> invalid
      expect(preview.rows[2].isValid, isFalse);
      expect(preview.rows[2].errors, contains('price_negative'));

      // Valid row whose barcode exists in inventory -> update candidate
      expect(preview.rows[3].isValid, isTrue);
      expect(preview.rows[3].warnings, contains('barcode_exists'));

      final (toCreate, toUpdate) = service.buildEntities(preview, {
        '789': ProductEntity(barcode: '789', name: 'Book'),
      });
      expect(toCreate.length, 1);
      expect(toCreate.first.barcode, '123');
      expect(toUpdate.length, 1);
      expect(toUpdate.first.barcode, '789');
      expect(toUpdate.first.price, 20);
    },
  );

  test('tolerates formatted numbers and Arabic-Indic digits', () async {
    final path = await writeCsv(
      'name,barcode,price,stock\n'
      'Max,1,"1,234.50","5٠"\n'
      'Comma,2,"12,50",2\n',
    );
    final preview = await service.parse(
      filePath: path,
      existingInventory: const {},
    );
    expect(preview.rows[0].price, 1234.50);
    expect(preview.rows[0].stock, 50);
    expect(preview.rows[1].price, 12.50);
  });

  test('flags duplicate barcodes inside the file', () async {
    final path = await writeCsv('name,barcode\nA,111\nB,111\n');
    final preview = await service.parse(
      filePath: path,
      existingInventory: const {},
    );
    expect(preview.rows[0].isValid, isTrue);
    expect(preview.rows[1].errors, contains('barcode_duplicate_file'));
  });

  test('maps fields even when required column missing', () async {
    final path = await writeCsv('name\nSolo\n');
    final preview = await service.parse(
      filePath: path,
      existingInventory: const {},
    );
    expect(preview.rows.single.isValid, isTrue);
    expect(preview.rows.single.price, isNull);
    expect(preview.rows.single.barcode, isNotNull);
  });
}
