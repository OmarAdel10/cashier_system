@TestOn('linux')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/features/settings/data/models/app_settings_model.dart';

void main() {
  group('AppSettingsModel Linux', () {
    test('defaultExportDirectoryPath follows XDG spec', () {
      // Create instance to access instance getter
      final settings = AppSettingsModel();
      expect(settings.defaultExportDirectoryPath, isNotEmpty);
      expect(
        settings.defaultExportDirectoryPath,
        contains('.local/share/cashier-system/exports'),
      );
    });
  });
}
