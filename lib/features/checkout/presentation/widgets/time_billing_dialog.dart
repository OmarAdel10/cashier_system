import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../inventory/domain/entities/product_entity.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/helpers/price_helper.dart';
import '../bloc/checkout_event.dart';

Future<AddTimedItem?> showTimeBillingDialog(
  BuildContext context, {
  required ProductEntity product,
  required int minimumGameCostPiastres,
}) {
  return showDialog<AddTimedItem>(
    context: context,
    builder: (_) => TimeBillingDialog(
      product: product,
      minimumGameCostPiastres: minimumGameCostPiastres,
    ),
  );
}

class TimeBillingDialog extends StatefulWidget {
  final ProductEntity product;
  final int minimumGameCostPiastres;

  const TimeBillingDialog({
    super.key,
    required this.product,
    required this.minimumGameCostPiastres,
  });

  @override
  State<TimeBillingDialog> createState() => _TimeBillingDialogState();
}

class _TimeBillingDialogState extends State<TimeBillingDialog> {
  int _quarters = 4;

  int get _quarterUnit =>
      (PriceHelper.fromDouble(widget.product.price) / 4).round();

  int get _effectiveTotal {
    final raw = _quarters * _quarterUnit;
    return raw < widget.minimumGameCostPiastres
        ? widget.minimumGameCostPiastres
        : raw;
  }

  int get _effectiveUnit =>
      _quarterUnit == 0 ? 0 : (_effectiveTotal / _quarters).round();

  @override
  Widget build(BuildContext context) {
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    final t = LocalizationService();

    return AlertDialog(
      title: Text(widget.product.name),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.translate('checkout.time.total', languageCode: langCode),
              style: TextStyles.body,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              PriceHelper.format(_effectiveTotal, languageCode: langCode),
              style: TextStyles.heading1,
            ),
            const SizedBox(height: Spacing.lg),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip: t.translate(
                    'checkout.time.minus',
                    languageCode: langCode,
                  ),
                  onPressed: () {
                    setState(() {
                      if (_quarters > 1) _quarters--;
                    });
                  },
                  icon: const Icon(PhosphorIcons.minus),
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('$_quarters', style: TextStyles.heading1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.translate(
                          'checkout.time.quarters',
                          languageCode: langCode,
                          params: ['$_quarters'],
                        ),
                        style: TextStyles.body,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: Spacing.sm),
                IconButton(
                  tooltip: t.translate(
                    'checkout.time.plus',
                    languageCode: langCode,
                  ),
                  onPressed: () => setState(() => _quarters++),
                  icon: const Icon(PhosphorIcons.plus),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.translate('cancel', languageCode: langCode)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            AddTimedItem(
              barcode: widget.product.barcode,
              name: widget.product.name,
              unitPricePiastres: _effectiveUnit,
              quantity: _quarters,
            ),
          ),
          child: Text(
            t.translate('checkout.time.confirm', languageCode: langCode),
          ),
        ),
      ],
    );
  }
}
