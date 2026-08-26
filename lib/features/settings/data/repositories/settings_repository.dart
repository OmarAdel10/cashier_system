import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/error/either.dart';
import '../../../../core/error/failure.dart';
import '../../domain/entities/app_settings_entity.dart';
import '../../domain/repositories/i_settings_repository.dart';
import '../models/app_settings_model.dart';

class SettingsRepository implements ISettingsRepository {
  final Box<AppSettingsModel> _box;
  final Future<String> Function() _defaultExportPathProvider;

  SettingsRepository({
    required Box<AppSettingsModel> box,
    Future<String> Function()? defaultExportPathProvider,
  }) : _box = box,
       _defaultExportPathProvider =
           defaultExportPathProvider ?? _resolveDefaultExportPath;

  static Future<String> _resolveDefaultExportPath() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null && downloads.path.isNotEmpty) {
        return downloads.path;
      }
    } catch (_) {}
    final home = Platform.environment['USERPROFILE'] ?? '';
    if (home.isNotEmpty) return '$home\\Downloads';
    return '';
  }

  Future<String> _effectiveExportPath(String current) async {
    if (current.isNotEmpty) return current;
    return _defaultExportPathProvider();
  }

  @override
  Future<Either<Failure, AppSettingsEntity>> getSettings() async {
    try {
      final model = _box.get('settings');
      if (model == null) {
        final defaults = AppSettingsEntity(
          exportDirectoryPath: await _effectiveExportPath(''),
        );
        return Right(defaults);
      }
      final entity = model.toEntity();
      if (entity.exportDirectoryPath.isEmpty) {
        return Right(
          entity.copyWith(exportDirectoryPath: await _effectiveExportPath('')),
        );
      }
      return Right(entity);
    } catch (e) {
      return Left(DatabaseFailure('Failed to load settings: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveSettings(AppSettingsEntity settings) async {
    try {
      final model = AppSettingsModel(
        languageCode: settings.languageCode,
        isDarkMode: settings.isDarkMode,
        storeName: settings.storeName,
        receiptFootnote: settings.receiptFootnote,
        customBindings: settings.customBindings,
        taxEnabled: settings.taxEnabled,
        taxPercent: settings.taxPercent,
        autoPrintEnabled: settings.autoPrintEnabled,
        orderCounter: settings.orderCounter,
        lastOrderDate: settings.lastOrderDate,
        exportDirectoryPath: settings.exportDirectoryPath,
        saveReceiptAsImage: settings.saveReceiptAsImage,
        saveReceiptAsPdf: settings.saveReceiptAsPdf,
        storeAddress: settings.storeAddress,
        storePhoneNumber: settings.storePhoneNumber,
        receiptPrinterName: settings.receiptPrinterName,
        barcodePrinterName: settings.barcodePrinterName,
        logoSvgData: settings.logoSvgData,
        barcodeActionPreference: settings.barcodeActionPreference,
        shownPaymentTypeIds: settings.shownPaymentTypeIds,
        businessType: settings.businessType,
        minimumGameCost: settings.minimumGameCost,
        favoritesStripEnabled: settings.favoritesStripEnabled,
        roomsEnabled: settings.roomsEnabled,
        serviceChargeEnabled: settings.serviceChargeEnabled,
        serviceChargePercent: settings.serviceChargePercent,
        minChargeEnabled: settings.minChargeEnabled,
        minChargePerTablePiastres: settings.minChargePerTablePiastres,
        kitchenTicketsEnabled: settings.kitchenTicketsEnabled,
        kitchenPrinterName: settings.kitchenPrinterName,
        barTicketsEnabled: settings.barTicketsEnabled,
        barPrinterName: settings.barPrinterName,
        shishaTicketsEnabled: settings.shishaTicketsEnabled,
        shishaPrinterName: settings.shishaPrinterName,
      );
      await _box.put('settings', model);
      return const Right(null);
    } catch (e) {
      return Left(DatabaseFailure('Failed to save settings: $e'));
    }
  }
}
