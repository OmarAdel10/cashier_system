import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../features/settings/data/services/localization_service.dart';

class DeviceIdQr extends StatelessWidget {
  final String deviceId;
  final String langCode;

  const DeviceIdQr({super.key, required this.deviceId, this.langCode = 'en'});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: QrImageView(
            data: deviceId,
            version: QrVersions.auto,
            size: 200,
            eyeStyle: QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: theme.colorScheme.primary,
            ),
            dataModuleStyle: QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          LocalizationService().translate('licensing.deviceId', languageCode: langCode),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            deviceId,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
    );
  }
}
