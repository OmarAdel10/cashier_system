import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../../domain/helpers/price_helper.dart';
import '../bloc/checkout_bloc.dart';
import '../bloc/checkout_event.dart';
import '../bloc/checkout_state.dart';

class CashDrawerAssistant extends StatefulWidget {
  final ValueNotifier<int>? discountFocusTrigger;

  const CashDrawerAssistant({super.key, this.discountFocusTrigger});

  @override
  State<CashDrawerAssistant> createState() => _CashDrawerAssistantState();
}

class _CashDrawerAssistantState extends State<CashDrawerAssistant> {
  final _discountFocusNode = FocusNode();
  final _discountController = TextEditingController();

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
    super.dispose();
  }

  void _onDiscountFocusTrigger() {
    _discountFocusNode.requestFocus();
    _discountController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _discountController.text.length,
    );
  }

  static const _denominations = [500, 1000, 2000, 5000, 10000, 20000];

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;
    final state = context.watch<CheckoutBloc>().state;
    final subtotal = state.subtotalPiastres;
    final change = state.changePiastres;
    final isPaid = state.isPaid;
    final amountPaid = state.amountPaidPiastres;

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
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: child,
            ),
            child: Text(
              PriceHelper.format(subtotal, languageCode: langCode),
              key: ValueKey(subtotal),
              style: TextStyles.heading1,
            ),
          ),
          if (amountPaid != null) ...[
            const SizedBox(height: Spacing.xs),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),
              child: Text(
                '${t.translate('checkout.paid', languageCode: langCode)}: ${PriceHelper.format(amountPaid, languageCode: langCode)}',
                key: ValueKey(amountPaid),
                style: TextStyles.body,
              ),
            ),
          ],
          const SizedBox(height: Spacing.sm),
          BlocSelector<CheckoutBloc, CheckoutState, int?>(
            selector: (state) => state.amountPaidPiastres,
            builder: (context, amountPaid) {
              return Column(
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
              );
            },
          ),
          if (isPaid && change > 0) ...[
            const SizedBox(height: Spacing.md),
            Text(
              t.translate('checkout.change', languageCode: langCode),
              style: TextStyles.body,
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: child,
              ),
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
                child: TextField(
                  focusNode: _discountFocusNode,
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: Spacing.sm,
                      vertical: Spacing.xs,
                    ),
                    border: InputBorder.none,
                    hintText: '0%',
                    hintStyle: TextStyles.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  style: TextStyles.body,
                  onChanged: (value) {
                    final percent = int.tryParse(value) ?? 0;
                    context.read<CheckoutBloc>().add(SetDiscount(percent.clamp(0, 100)));
                  },
                ),
              ),
              Text(
                state.discountPercent > 0
                    ? '-${PriceHelper.format(state.discountAmount, languageCode: langCode)}'
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
            child: ElevatedButton(
              clipBehavior: Clip.antiAlias,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
                alignment: Alignment.center,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Spacing.md),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              onPressed:
                  subtotal > 0 && state.status != CheckoutStatus.confirmed
                  ? () => context.read<CheckoutBloc>().add(const ConfirmSale())
                  : null,
              child: Text(
                t.translate('checkout.confirmSale', languageCode: langCode),
              ),
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
        return Transform.scale(
          scale: _animation.value,
          child: child,
        );
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
