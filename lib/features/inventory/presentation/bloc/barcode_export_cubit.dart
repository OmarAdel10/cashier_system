import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/services/barcode_export_service.dart';
import '../../domain/entities/product_entity.dart';

sealed class BarcodeExportState {
  const BarcodeExportState();
}

final class BarcodeExportIdle extends BarcodeExportState {
  const BarcodeExportIdle();
}

final class BarcodeExporting extends BarcodeExportState {
  const BarcodeExporting();
}

final class BarcodeExportSuccess extends BarcodeExportState {
  final String filePath;
  const BarcodeExportSuccess(this.filePath);
}

final class BarcodeExportFailure extends BarcodeExportState {
  final String message;
  const BarcodeExportFailure(this.message);
}

class BarcodeExportCubit extends Cubit<BarcodeExportState> {
  final BarcodeExportService _service;

  BarcodeExportCubit({required BarcodeExportService service})
    : _service = service,
      super(const BarcodeExportIdle());

  Future<void> export({
    required GlobalKey repaintKey,
    required String barcode,
    required String downloadPath,
  }) async {
    if (state is BarcodeExporting) return;
    emit(const BarcodeExporting());

    final result = await _service.exportLabel(
      repaintKey: repaintKey,
      barcode: barcode,
      downloadPath: downloadPath,
    );

    result.fold(
      (failure) => emit(BarcodeExportFailure(failure.message)),
      (filePath) => emit(BarcodeExportSuccess(filePath)),
    );
  }

  Future<void> exportCsv({
    required List<ProductEntity> products,
    required String exportPath,
  }) async {
    if (state is BarcodeExporting) return;
    emit(const BarcodeExporting());

    final result = await _service.exportCsv(
      products: products,
      exportPath: exportPath,
    );

    result.fold(
      (failure) => emit(BarcodeExportFailure(failure.message)),
      (filePath) => emit(BarcodeExportSuccess(filePath)),
    );
  }

  Future<void> exportPdf({
    required List<ProductEntity> products,
    required String exportPath,
  }) async {
    if (state is BarcodeExporting) return;
    emit(const BarcodeExporting());

    final result = await _service.exportPdf(
      products: products,
      exportPath: exportPath,
    );

    result.fold(
      (failure) => emit(BarcodeExportFailure(failure.message)),
      (filePath) => emit(BarcodeExportSuccess(filePath)),
    );
  }

  void reset() {
    emit(const BarcodeExportIdle());
  }
}
