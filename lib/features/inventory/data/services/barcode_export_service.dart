import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/either.dart';

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
}
