import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../settings/data/services/localization_service.dart';

class ReceiptDetailActions extends StatelessWidget {
  final bool canModify;
  final bool viewOnly;
  final String langCode;
  final VoidCallback onRefund;
  final VoidCallback onModify;
  final VoidCallback? onReprint;

  const ReceiptDetailActions({
    super.key,
    required this.canModify,
    required this.viewOnly,
    required this.langCode,
    required this.onRefund,
    required this.onModify,
    this.onReprint,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onReprint != null)
          TextButton.icon(
            onPressed: onReprint,
            icon: const PhosphorIcon(
              PhosphorIcons.printer,
              size: 16,
            ),
            label: Text(
              LocalizationService().translate(
                'sales.reprint',
                languageCode: langCode,
              ),
            ),
          ),
        if (onReprint != null) const SizedBox(height: Spacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (canModify && !viewOnly)
              TextButton.icon(
                onPressed: onRefund,
                icon: const PhosphorIcon(
                  PhosphorIcons.arrowArcLeft,
                  size: 16,
                ),
                label: Text(
                  LocalizationService().translate(
                    'sales.returnRefund',
                    languageCode: langCode,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
            if (canModify && !viewOnly) const SizedBox(width: Spacing.sm),
            if (canModify && !viewOnly)
              TextButton.icon(
                onPressed: onModify,
                icon: const PhosphorIcon(
                  PhosphorIcons.pencilSimple,
                  size: 16,
                ),
                label: Text(
                  LocalizationService().translate(
                    'sales.modify',
                    languageCode: langCode,
                  ),
                ),
              ),
            if (canModify && !viewOnly)
              const SizedBox(width: Spacing.sm),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                LocalizationService().translate('cancel', languageCode: langCode),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
