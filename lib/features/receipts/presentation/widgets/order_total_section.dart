import 'package:flutter/material.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../checkout/domain/helpers/price_helper.dart';
import '../../../settings/data/services/localization_service.dart';

class OrderTotalSection extends StatelessWidget {
  final int subtotal;
  final String langCode;
  final bool isProcessing;
  final VoidCallback? onCancel;
  final VoidCallback? onSave;

  const OrderTotalSection({
    super.key,
    required this.subtotal,
    required this.langCode,
    required this.isProcessing,
    this.onCancel,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1),
        const SizedBox(height: Spacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              LocalizationService().translate(
                'checkout.total',
                languageCode: langCode,
              ),
              style: TextStyles.title,
            ),
            Text(
              PriceHelper.format(subtotal, languageCode: langCode),
              style: TextStyles.title,
            ),
          ],
        ),
        const SizedBox(height: Spacing.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: onCancel,
              child: Text(
                LocalizationService().translate(
                  'cancel',
                  languageCode: langCode,
                ),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            FilledButton(
              onPressed: onSave,
              child: isProcessing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      LocalizationService().translate(
                        'save',
                        languageCode: langCode,
                      ),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}
