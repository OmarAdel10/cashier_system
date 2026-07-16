import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../inventory/domain/entities/product_entity.dart';
import '../../../inventory/presentation/bloc/inventory_bloc.dart';
import '../../../inventory/presentation/bloc/inventory_state.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/helpers/price_helper.dart';
import '../bloc/checkout_bloc.dart';
import '../bloc/checkout_event.dart';

class QuickTilesGrid extends StatelessWidget {
  const QuickTilesGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;

    return BlocBuilder<InventoryBloc, InventoryState>(
      builder: (context, state) {
        final tiles = state.quickTileList;
        if (tiles.isEmpty) {
          return const SizedBox.shrink();
        }

        return SectionCard(
          title: t.translate('checkout.quickItems', languageCode: langCode),
          child: Wrap(
            spacing: Spacing.sm,
            runSpacing: Spacing.sm,
            alignment: WrapAlignment.start,
            children: tiles
                .map(
                  (product) => TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.scale(scale: value, child: child),
                      );
                    },
                    child: _QuickTile(product: product),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _QuickTile extends StatelessWidget {
  final ProductEntity product;

  const _QuickTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;
    final bgColor = product.tileColorHex != null
        ? Color(int.parse(product.tileColorHex!.replaceFirst('#', '0xFF')))
        : Theme.of(context).colorScheme.primaryContainer;

    return InkWell(
      onTap: () {
        context.read<CheckoutBloc>().add(
          AddToCart(
            barcode: product.barcode,
            name: product.name,
            unitPricePiastres: PriceHelper.fromDouble(product.price),
          ),
        );
      },
      borderRadius: BorderRadius.circular(Spacing.md),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: bgColor.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(Spacing.md),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AutoSizeText(
              product.name,
              style: TextStyles.heading2.copyWith(fontWeight: FontWeight.w500),
              maxLines: 2,
              minFontSize: 10,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              PriceHelper.format(PriceHelper.fromDouble(product.price), languageCode: langCode),
              style: TextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}
