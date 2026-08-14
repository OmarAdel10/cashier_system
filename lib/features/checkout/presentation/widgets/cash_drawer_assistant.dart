import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../../shortcuts/presentation/focus_controller.dart';
import '../../domain/entities/payment_type.dart';
import '../../domain/helpers/price_helper.dart';
import '../bloc/checkout_bloc.dart';
import '../bloc/checkout_event.dart';
import '../bloc/checkout_state.dart';

class CashDrawerAssistant extends StatefulWidget {
  final ValueNotifier<int>? discountFocusTrigger;
  final FocusController? focusController;

  const CashDrawerAssistant({
    super.key,
    this.discountFocusTrigger,
    this.focusController,
  });

  @override
  State<CashDrawerAssistant> createState() => _CashDrawerAssistantState();
}

class _CashDrawerAssistantState extends State<CashDrawerAssistant> {
  final _discountFocusNode = FocusNode();
  final _discountController = TextEditingController();
  final _discountError = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    widget.discountFocusTrigger?.addListener(_onDiscountFocusTrigger);
  }

  @override
  void dispose() {
    widget.discountFocusTrigger?.removeListener(_onDiscountFocusTrigger);
    _discountFocusNode.dispose();
    _discountController.dispose();
    _discountError.dispose();
    super.dispose();
  }

  void _onDiscountFocusTrigger() {
    final controller = widget.focusController;
    if (controller != null) {
      controller.requestFocusLoan(FocusZone.discount, _discountFocusNode);
    } else {
      _discountFocusNode.requestFocus();
    }
    _discountController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _discountController.text.length,
    );
  }

  static const _denominations = [500, 1000, 2000, 5000, 10000, 20000];

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );
    final total = context.select<CheckoutBloc, int>(
      (s) => s.state.totalPiastres,
    );
    final change = context.select<CheckoutBloc, int>(
      (s) => s.state.changePiastres,
    );
    final isPaid = context.select<CheckoutBloc, bool>((s) => s.state.isPaid);
    final amountPaid = context.select<CheckoutBloc, int?>(
      (s) => s.state.amountPaidPiastres,
    );
    final paymentType = context.select<CheckoutBloc, String>(
      (s) => s.state.paymentType,
    );
    final shownPaymentTypeIds = context.select<SettingsBloc, List<String>>(
      (s) => s.state.settings.shownPaymentTypeIds,
    );
    final availableTypes = PaymentType.fromIds(shownPaymentTypeIds);

    return Padding(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.translate('checkout.amountDue', languageCode: langCode),
            style: TextStyles.title,
          ),
          const SizedBox(height: Spacing.xs),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Text(
              PriceHelper.format(total, languageCode: langCode),
              key: ValueKey(total),
              style: TextStyles.heading1,
            ),
          ),
          if (amountPaid != null) ...[
            const SizedBox(height: Spacing.xs),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: Text(
                '${t.translate('checkout.paid', languageCode: langCode)}: ${PriceHelper.format(amountPaid, languageCode: langCode)}',
                key: ValueKey(amountPaid),
                style: TextStyles.body,
              ),
            ),
          ],
          const SizedBox(height: Spacing.sm),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  ..._denominations
                      .sublist(0, 4)
                      .map(
                        (denom) => Expanded(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              end: Spacing.xs,
                            ),
                            child: _CashButton(
                              label: PriceHelper.format(
                                denom,
                                languageCode: langCode,
                              ),
                              onTap: () {
                                final current = amountPaid ?? 0;
                                context.read<CheckoutBloc>().add(
                                  SetAmountPaid(current + denom),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                ],
              ),
              const SizedBox(height: Spacing.xs),
              Row(
                children: [
                  ..._denominations
                      .sublist(4)
                      .map(
                        (denom) => Expanded(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(
                              end: Spacing.xs,
                            ),
                            child: _CashButton(
                              label: PriceHelper.format(
                                denom,
                                languageCode: langCode,
                              ),
                              onTap: () {
                                final current = amountPaid ?? 0;
                                context.read<CheckoutBloc>().add(
                                  SetAmountPaid(current + denom),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                  Expanded(
                    child: _CashButton(
                      label: 'C',
                      onTap: () => context.read<CheckoutBloc>().add(
                        const ClearAmountPaid(),
                      ),
                      isClear: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            '${t.translate('checkout.paymentType', languageCode: langCode)}:',
            style: TextStyles.body,
          ),
          const SizedBox(height: Spacing.xs),
          Row(
            children: [
              for (final type in availableTypes)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: Spacing.xs),
                    child: ChoiceChip(
                      label: Text(
                        t.translate(
                          'paymentType.${type.id}',
                          languageCode: langCode,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      selected: type.id == paymentType,
                      showCheckmark: false,
                      onSelected: (_) => context.read<CheckoutBloc>().add(
                        SetPaymentType(type.id),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          if (isPaid && change > 0) ...[
            const SizedBox(height: Spacing.md),
            Text(
              t.translate('checkout.change', languageCode: langCode),
              style: TextStyles.body,
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: Text(
                PriceHelper.format(change, languageCode: langCode),
                key: ValueKey(change),
                style: TextStyles.heading2,
              ),
            ),
          ],
          const SizedBox(height: Spacing.sm),
          Row(
            children: [
              Text(
                '${t.translate('discount', languageCode: langCode)}:',
                style: TextStyles.body,
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _discountError,
                  builder: (context, hasError, _) {
                    final errorColor = Theme.of(context).colorScheme.error;
                    return TextField(
                      focusNode: _discountFocusNode,
                      controller: _discountController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onSubmitted: (_) {
                        _discountFocusNode.unfocus();
                        widget.focusController?.returnToScanner();
                      },
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sm,
                          vertical: Spacing.xs,
                        ),
                        border: hasError
                            ? OutlineInputBorder(
                                borderSide: BorderSide(color: errorColor),
                              )
                            : InputBorder.none,
                        hintText: t.translate(
                          'checkout.discount.hint',
                          languageCode: langCode,
                        ),
                        hintStyle: TextStyles.bodySmall.copyWith(
                          color: hasError
                              ? errorColor
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      style: TextStyles.body,
                      onChanged: (value) {
                        final percent = int.tryParse(value) ?? 0;
                        _discountError.value = percent > 100;
                        context.read<CheckoutBloc>().add(
                          SetDiscount(percent.clamp(0, 100)),
                        );
                      },
                    );
                  },
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: _discountError,
                builder: (context, hasError, _) {
                  if (!hasError) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: Spacing.xs,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  );
                },
              ),
              Text(
                context.select<CheckoutBloc, int>(
                          (s) => s.state.discountPercent,
                        ) >
                        0
                    ? '-${PriceHelper.format(context.select<CheckoutBloc, int>((s) => s.state.discountAmount), languageCode: langCode)}'
                    : '',
                style: TextStyles.body.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),
          SizedBox(
            width: double.infinity,
            child: Builder(
              builder: (context) {
                final isActive =
                    total > 0 &&
                    context.select<CheckoutBloc, CheckoutStatus>(
                          (s) => s.state.status,
                        ) !=
                        CheckoutStatus.confirmed;
                return ElevatedButton(
                  clipBehavior: Clip.antiAlias,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
                    alignment: Alignment.center,
                    backgroundColor: isActive
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.3)
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Spacing.md),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  onPressed: isActive
                      ? () => context.read<CheckoutBloc>().add(
                          const ConfirmSale(),
                        )
                      : null,
                  child: Text(
                    t.translate('checkout.confirmSale', languageCode: langCode),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CashButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isClear;

  const _CashButton({
    required this.label,
    required this.onTap,
    this.isClear = false,
  });

  @override
  State<_CashButton> createState() => _CashButtonState();
}

class _CashButtonState extends State<_CashButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(scale: _animation.value, child: child);
      },
      child: SizedBox(
        height: 56,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color: widget.isClear
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.label,
                style: widget.isClear
                    ? TextStyles.bodySmall.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      )
                    : TextStyles.bodySmall,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
