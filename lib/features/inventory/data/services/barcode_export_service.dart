import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/either.dart';
import '../../domain/entities/product_entity.dart';

class BarcodeExportService {
  Future<Either<Failure, String>> exportLabel({
    required GlobalKey repaintKey,
    required String barcode,
    required String downloadPath,
  }) async {
    try {
      final boundary =
          repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        return Left(
          DatabaseFailure('Failed to find barcode label render object'),
        );
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        return Left(DatabaseFailure('Failed to encode barcode image'));
      }

      final pngBytes = byteData.buffer.asUint8List();

      final dir = Directory(downloadPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final sanitized = barcode.replaceAll(RegExp(r'[^\w]'), '_');
      var timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      var suffix = timestamp.toString();
      if (suffix.length > 6) {
        suffix = suffix.substring(suffix.length - 6);
      }
      final filename = 'barcode_${sanitized}_$suffix.png';
      final filePath = '${dir.path}/$filename';

      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      return Right(filePath);
    } catch (e) {
      return Left(DatabaseFailure('Barcode export failed: $e'));
    }
  }

  Future<Either<Failure, String>> exportCsv({
    required List<ProductEntity> products,
    required String exportPath,
  }) async {
    try {
      final dir = Directory(exportPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final filename = 'inventory_$timestamp.csv';
      final filePath = '${dir.path}/$filename';

      final lines = <String>['Barcode,Name,Price,Stock,Notes'];
      for (final product in products) {
        final notes = product.notes.isNotEmpty
            ? product.notes.replaceAll(',', ';')
            : '';
        final line =
            '${product.barcode},${product.name},${product.price},${product.stock},$notes';
        lines.add(line);
      }

      final csvContent = lines.join('\n');
      final file = File(filePath);
      await file.writeAsBytes(csvContent.codeUnits);

      return Right(filePath);
    } catch (e) {
      return Left(DatabaseFailure('CSV export failed: $e'));
    }
  }

  Future<Either<Failure, String>> exportPdf({
    required List<ProductEntity> products,
    required String exportPath,
  }) async {
    try {
      final dir = Directory(exportPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final filename = 'inventory_$timestamp.pdf';
      final filePath = '${dir.path}/$filename';

      final pdfBytes = _buildMinimalPdfBytes(products);
      final file = File(filePath);
      await file.writeAsBytes(pdfBytes);

      return Right(filePath);
    } catch (e) {
      return Left(DatabaseFailure('PDF export failed: $e'));
    }
  }

  List<int> _buildMinimalPdfBytes(List<ProductEntity> products) {
    // Build a minimal valid PDF that displays product information.
    // Uses a proven minimal PDF structure that works with common readers.
    final bytes = <int>[];

    // PDF header
    bytes.addAll('%PDF-1.4\n'.codeUnits);

    // Object 1: Catalog
    final obj1 = '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n';
    bytes.addAll(utf8.encode(obj1));

    // Object 2: Pages
    final obj2 = '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n';
    bytes.addAll(utf8.encode(obj2));

    // Object 3: Page (Letter size: 612x792 points)
    // Resources with Helvetica font reference
    // Contents reference (will be object 5)
    final obj3 =
        '3 0 obj\n'
        '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792]'
        ' /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R>>\n'
        'endobj\n';
    bytes.addAll(utf8.encode(obj3));

    // Object 4: Helvetica font
    final obj4 =
        '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n';
    bytes.addAll(utf8.encode(obj4));

    // Object 5: Content stream with product text
    final stream = StringBuffer();
    stream.write('BT /F1 24 Tf 100 750 Td');
    for (int i = 0; i < products.length; i++) {
      final p = products[i];
      final text = '${p.name}: \$${p.price} (Stock: ${p.stock})';
      final escaped = text.replaceAll('(', '\\(').replaceAll(')', '\\)');
      stream.write(' ($escaped) Tj 0 -20 Td');
    }
    stream.write(' ET');

    final streamContent = stream.toString();
    final streamBytes = streamContent.codeUnits;
    final length = streamBytes.length;

    bytes.addAll('5 0 obj\n<< /Length $length >>\nstream\n'.codeUnits);
    bytes.addAll(streamBytes);
    bytes.addAll('endstream\nendobj\n'.codeUnits);

    // xref table with offsets
    // Object 1 starts at byte 9 (after "%PDF-1.4\n")
    // Object 2 starts at byte 9 + obj1.length
    // Object 3 starts at byte 9 + obj1.length + obj2.length
    // Object 4 starts at byte 9 + obj1.length + obj2.length + obj3.length
    // Object 5 starts at byte 9 + obj1.length + obj2.length + obj3.length + obj4.length

    int offset1 = 9;
    int offset2 = offset1 + obj1.length;
    int offset3 = offset2 + obj2.length;
    int offset4 = offset3 + obj3.length;
    int offset5 = offset4 + obj4.length;

    // Build xref
    final xref = StringBuffer();
    xref.write('xref\n');
    xref.write('0 6\n'); // 6 objects: 0-5
    xref.write('0000000000 65535 f \n');
    xref.write('${offset1.toString().padLeft(10, '0')} 00000 00000 n \n');
    xref.write('${offset2.toString().padLeft(10, '0')} 00000 00000 n \n');
    xref.write('${offset3.toString().padLeft(10, '0')} 00000 00000 n \n');
    xref.write('${offset4.toString().padLeft(10, '0')} 00000 00000 n \n');
    xref.write('${offset5.toString().padLeft(10, '0')} 00000 00000 n \n');

    bytes.addAll(xref.toString().codeUnits);

    // trailer
    final startxrefPos = offset5 + obj4.length; // position of object 5
    bytes.addAll('trailer\n'.codeUnits);
    bytes.addAll('<< /Size 6 /Root 1 0 R >>\n'.codeUnits);
    bytes.addAll('startxref\n'.codeUnits);
    bytes.addAll(startxrefPos.toString().padLeft(10, '0').codeUnits);
    bytes.addAll('\n%%EOF\n'.codeUnits);

    return bytes;
  }
}
