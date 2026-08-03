import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/animated_counter.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/entities/cart_item_entity.dart';
import '../../domain/helpers/price_helper.dart';
import '../../../settings/domain/entities/app_settings_entity.dart';
import '../bloc/checkout_bloc.dart';
import '../bloc/checkout_state.dart';
import 'cash_drawer_assistant.dart';

class CheckoutTowerPanel extends StatelessWidget {
  final ValueNotifier<int>? discountFocusTrigger;
  final ValueNotifier<int>? cartFocusTrigger;

  const CheckoutTowerPanel({super.key, this.discountFocusTrigger, this.cartFocusTrigger});

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select<SettingsBloc, String>((s) => s.state.settings.languageCode);
    final settings = context.select<SettingsBloc, AppSettingsEntity>((s) => s.state.settings);

    return Column(
      children: [
        Expanded(
          child: SectionCard(
            title: t.translate('receiptTower', languageCode: langCode),
            mainAxisSize: MainAxisSize.max,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const _ReceiptHeader(),
                const _ReceiptBody(),
                _ReceiptSummary(
                  langCode: langCode,
                  taxPercent: settings.taxEnabled ? settings.taxPercent : 0,
                ),
                if (settings.receiptFootnote.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: Spacing.xs),
                    child: Text(
                      settings.receiptFootnote,
                      style: TextStyles.caption.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Spacing.sm),
        SectionCard(
          title: t.translate('checkout.cashDrawer', languageCode: langCode),
          child: CashDrawerAssistant(
            discountFocusTrigger: discountFocusTrigger,
            cartFocusTrigger: cartFocusTrigger,
          ),
        ),
      ],
    );
  }
}

class _ReceiptHeader extends StatelessWidget {
  const _ReceiptHeader();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final storeName = context.select<SettingsBloc, String>((s) => s.state.settings.storeName);
    final t = LocalizationService();
    final langCode = context.select<SettingsBloc, String>((s) => s.state.settings.languageCode);

    return BlocSelector<CheckoutBloc, CheckoutState, _HeaderData>(
      selector: (s) => _HeaderData(s.orderNumber, s.status),
      builder: (context, data) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.only(bottom: Spacing.md),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (data.orderNumber != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: Spacing.xs),
                  child: Text(
                    '#${data.orderNumber}',
                    style: TextStyles.caption.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (storeName.isNotEmpty)
                Text(
                  storeName,
                  style: TextStyles.heading2,
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  PhosphorIcon(
                    PhosphorIcons.receiptDuotone,
                    size: 20,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text(
                    t.translate('receiptTower', languageCode: langCode),
                    style: TextStyles.title,
                  ),
                  if (data.status == CheckoutStatus.confirmed) ...[
                    const Spacer(),
                    PhosphorIcon(
                      PhosphorIcons.checkCircle,
                      color: colorScheme.primary,
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ReceiptBody extends StatelessWidget {
  const _ReceiptBody();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final t = LocalizationService();
    final langCode = context.select<SettingsBloc, String>((s) => s.state.settings.languageCode);

    return BlocSelector<CheckoutBloc, CheckoutState, List<CartItemEntity>?>(
      selector: (s) => s.cart?.items,
      builder: (context, items) {
        if (items == null || items.isEmpty) {
          return Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PhosphorIcon(
                    PhosphorIcons.receiptDuotone,
                    size: 48,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: Spacing.md),
                  Text(
                    t.translate('receiptPlaceholder', languageCode: langCode),
                    style: TextStyles.body.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
        return Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
            itemCount: items.length,
            separatorBuilder: (_, _) => Divider(height: 1, color: colorScheme.outlineVariant),
            itemBuilder: (context, index) {
              final item = items[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                child: Row(
                  children: [
                    Text(
                      '${index + 1}.',
                      style: TextStyles.body.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyles.body.copyWith(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Spacing.sm),
                    Text(
                      '${item.quantity} x ${PriceHelper.format(item.unitPricePiastres, languageCode: langCode)}',
                      style: TextStyles.caption.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: Spacing.sm),
                    AnimatedCounter(
                      value: PriceHelper.format(item.totalPiastres, languageCode: langCode),
                      style: TextStyles.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ReceiptSummary extends StatelessWidget {
  const _ReceiptSummary({
    required this.langCode,
    required this.taxPercent,
  });

  final String langCode;
  final int taxPercent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final t = LocalizationService();

    return BlocSelector<CheckoutBloc, CheckoutState, _SummaryData?>(
      selector: (s) {
        if (s.cart == null || s.cart!.items.isEmpty) return null;
        return _SummaryData(
          itemCount: s.cart!.items.length,
          subtotal: s.subtotalPiastres,
          discountPercent: s.discountPercent,
          discountAmount: s.discountAmount,
          taxAmount: s.taxAmount,
          total: s.totalPiastres,
        );
      },
      builder: (context, data) {
        if (data == null) return const SizedBox.shrink();
        return Column(
          children: [
            Divider(height: 1, color: colorScheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t.translate('checkout.items', languageCode: langCode, params: [data.itemCount.toString()]),
                        style: TextStyles.body.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      AnimatedCounter(
                        value: PriceHelper.format(data.subtotal, languageCode: langCode),
                        style: TextStyles.title,
                      ),
                    ],
                  ),
                  if (data.discountAmount > 0) ...[
                    const SizedBox(height: Spacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${t.translate('discount', languageCode: langCode)} (${data.discountPercent}%)',
                          style: TextStyles.bodySmall.copyWith(color: colorScheme.error),
                        ),
                        Text(
                          '-${PriceHelper.format(data.discountAmount, languageCode: langCode)}',
                          style: TextStyles.bodySmall.copyWith(color: colorScheme.error),
                        ),
                      ],
                    ),
                  ],
                  if (taxPercent > 0) ...[
                    const SizedBox(height: Spacing.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${t.translate('tax', languageCode: langCode)} ($taxPercent%)',
                          style: TextStyles.bodySmall.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '+${PriceHelper.format(data.taxAmount, languageCode: langCode)}',
                          style: TextStyles.bodySmall.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: Spacing.xs),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t.translate('checkout.total', languageCode: langCode),
                        style: TextStyles.body.copyWith(fontWeight: FontWeight.w600),
                      ),
                      AnimatedCounter(
                        value: PriceHelper.format(data.total, languageCode: langCode),
                        style: TextStyles.title.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeaderData {
  final String? orderNumber;
  final CheckoutStatus status;

  const _HeaderData(this.orderNumber, this.status);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HeaderData &&
          runtimeType == other.runtimeType &&
          orderNumber == other.orderNumber &&
          status == other.status;

  @override
  int get hashCode => orderNumber.hashCode ^ status.hashCode;
}

class _SummaryData {
  final int itemCount;
  final int subtotal;
  final int discountPercent;
  final int discountAmount;
  final int taxAmount;
  final int total;

  const _SummaryData({
    required this.itemCount,
    required this.subtotal,
    required this.discountPercent,
    required this.discountAmount,
    required this.taxAmount,
    required this.total,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _SummaryData &&
          runtimeType == other.runtimeType &&
          itemCount == other.itemCount &&
          subtotal == other.subtotal &&
          discountPercent == other.discountPercent &&
          discountAmount == other.discountAmount &&
          taxAmount == other.taxAmount &&
          total == other.total;

  @override
  int get hashCode =>
      itemCount.hashCode ^
      subtotal.hashCode ^
      discountPercent.hashCode ^
      discountAmount.hashCode ^
      taxAmount.hashCode ^
      total.hashCode;
}
