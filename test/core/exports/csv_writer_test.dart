import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/exports/csv_writer.dart';

void main() {
  test('writes a UTF-8 BOM so Excel decodes non-ASCII text', () async {
    final dir = await Directory.systemTemp.createTemp('csv_writer_test');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/bom.csv';

    await writeCsvRows([
      ['Item', 'Amount'],
      ['Pepsi x2', '15.00'],
    ], path);

    final bytes = await File(path).readAsBytes();
    expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
  });

  test('round-trips Arabic and non-ASCII text', () async {
    final dir = await Directory.systemTemp.createTemp('csv_writer_test');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/unicode.csv';

    await writeCsvRows([
      ['الصنف', 'السعر'],
      ['شاي', '5.00'],
    ], path);

    final rows = await readCsvRows(path);
    expect(rows, [
      ['الصنف', 'السعر'],
      ['شاي', '5.00'],
    ]);
  });

  test('quotes cells containing commas and round-trips them', () async {
    final dir = await Directory.systemTemp.createTemp('csv_writer_test');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/quoted.csv';

    await writeCsvRows([
      ['Order #', 'Item'],
      ['ORD-001', 'Pepsi x2, Water x1'],
      ['ORD-002', 'Cola'],
    ], path);

    final rows = await readCsvRows(path);
    expect(rows, [
      ['Order #', 'Item'],
      ['ORD-001', 'Pepsi x2, Water x1'],
      ['ORD-002', 'Cola'],
    ]);
  });
}
