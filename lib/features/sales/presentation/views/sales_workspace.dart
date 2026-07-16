import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_error.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/bloc/shift_bloc.dart';
import '../../../checkout/domain/helpers/price_helper.dart';

import '../../../receipts/domain/entities/receipt_entity.dart';
import '../../../receipts/presentation/bloc/receipts_bloc.dart';
import '../../../receipts/presentation/bloc/receipts_state.dart';
import '../../../receipts/presentation/widgets/receipt_detail_dialog.dart';
import '../../../receipts/presentation/widgets/status_badge.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../bloc/sales_bloc.dart';
import '../bloc/sales_event.dart';
import '../bloc/sales_state.dart';

class SalesWorkspace extends StatefulWidget {
  final UserEntity user;

  const SalesWorkspace({super.key, required this.user});

  @override
  State<SalesWorkspace> createState() => _SalesWorkspaceState();
}

class _SalesWorkspaceState extends State<SalesWorkspace> {
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    context.read<SalesBloc>().add(const LoadTodaySummary());
    final shiftState = context.read<ShiftBloc>().state;
    if (shiftState.shift != null) {
      context.read<SalesBloc>().add(
        LoadShiftReceipts(shiftId: shiftState.shift!.id),
      );
    }
  }

  @override
  void dispose() {
    _hasInitialized = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;
    final isAdmin = widget.user.role == UserRole.admin;

    return BlocListener<ReceiptsBloc, ReceiptsState>(
      listenWhen: (previous, current) =>
          !_hasInitialized &&
          previous.status != ReceiptBlocStatus.ready &&
          current.status == ReceiptBlocStatus.ready,
      listener: (context, state) {
        _hasInitialized = true;
        context.read<SalesBloc>().add(const LoadTodaySummary());
        final shiftState = context.read<ShiftBloc>().state;
        if (shiftState.shift != null) {
          context.read<SalesBloc>().add(
            LoadShiftReceipts(shiftId: shiftState.shift!.id),
          );
        }
        final now = DateTime.now();
        context.read<SalesBloc>().add(
          LoadMonth(year: now.year, month: now.month),
        );
      },
      child: BlocBuilder<SalesBloc, SalesState>(
        builder: (context, state) {
          if (state.status == SalesStatus.loading &&
              state.todaySummary == null) {
            return AppLoading(
              message: t.translate(
                'state.loading.sales',
                languageCode: langCode,
              ),
            );
          }

          if (state.status == SalesStatus.error && state.todaySummary == null) {
            return AppError(
              headline: t.translate(
                'state.error.sales',
                languageCode: langCode,
              ),
              body: state.failure?.message ?? '',
              actionLabel: t.translate(
                'state.error.retry',
                languageCode: langCode,
              ),
              onAction: _loadData,
              severity: ErrorSeverity.recoverable,
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isAdmin)
                Expanded(
                  child: SectionCard(
                    mainAxisSize: MainAxisSize.max,
                    title: t.translate('sales.history', languageCode: langCode),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SummaryBar(
                          totalPiastres: state.todaySummary?.totalPiastres ?? 0,
                          receiptCount: state.todaySummary?.receiptCount ?? 0,
                          itemsSold: state.todaySummary?.itemsSold ?? 0,
                        ),
                        const Divider(height: 1),
                        Expanded(child: _MonthBrowser(user: widget.user)),
                      ],
                    ),
                  ),
                ),
              if (!isAdmin)
                Expanded(
                  child: _ShiftReceiptList(
                    user: widget.user,
                    receipts: state.shiftReceipts,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final int totalPiastres;
  final int receiptCount;
  final int itemsSold;

  const _SummaryBar({
    required this.totalPiastres,
    required this.receiptCount,
    required this.itemsSold,
  });

  @override
  Widget build(BuildContext context) {
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;
    final t = LocalizationService();

    return Row(
      children: [
        _MetricCard(
          icon: PhosphorIcons.receiptDuotone,
          label: t.translate('sales.receipts', languageCode: langCode),
          child: Text(
            receiptCount.toString(),
            style: TextStyles.heading1,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: Spacing.sm),
        _MetricCard(
          icon: PhosphorIcons.currencyCircleDollarDuotone,
          label: t.translate('sales.total', languageCode: langCode),
          child: SizedBox(
            height: 40,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: Text(
                PriceHelper.format(totalPiastres, languageCode: langCode),
                key: ValueKey(totalPiastres),
                style: TextStyles.heading1,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        _MetricCard(
          icon: PhosphorIcons.shoppingBagDuotone,
          label: t.translate('sales.itemsSold', languageCode: langCode),
          child: Text(
            itemsSold.toString(),
            style: TextStyles.heading1,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final Object icon;
  final String label;
  final Widget child;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            children: [
              PhosphorIcon(icon, size: 28),
              const SizedBox(height: Spacing.xs),
              Text(
                label,
                style: TextStyles.heading3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: Spacing.xs),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthBrowser extends StatefulWidget {
  final UserEntity user;

  const _MonthBrowser({required this.user});

  @override
  State<_MonthBrowser> createState() => _MonthBrowserState();
}

class _MonthBrowserState extends State<_MonthBrowser> {
  final List<int> _trackedMonths = [];
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _loadInitialMonths();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _trackedMonths.clear();
    super.dispose();
  }

  void _loadInitialMonths() {
    final now = DateTime.now();
    for (int i = 0; i < 6; i++) {
      final dt = DateTime(now.year, now.month - i, 1);
      final year = dt.year;
      final month = dt.month;
      _trackedMonths.add((year - 1970) * 12 + (month - 1));
      if (!_isDisposed) {
        context.read<SalesBloc>().add(LoadMonth(year: year, month: month));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SalesBloc, SalesState>(
      builder: (context, state) {
        final monthMap = <int, MonthData>{
          for (final m in state.months) (m.year - 1970) * 12 + (m.month - 1): m,
        };
        return ListView.builder(
          itemCount: _trackedMonths.length,
          itemBuilder: (context, index) {
            final key = _trackedMonths[index];
            final monthData = monthMap[key];
            final year = key ~/ 12 + 1970;
            final m = key % 12 + 1;
            return (monthData != null && monthData.receipts.isNotEmpty)
                ? _MonthCard(
                    year: year,
                    month: m,
                    monthData: monthData,
                    isLoading: monthData == null,
                    user: widget.user,
                    isExpanded: index == 0,
                  )
                : const SizedBox.shrink();
          },
        );
      },
    );
  }
}

class _MonthCard extends StatefulWidget {
  final int year;
  final int month;
  final MonthData? monthData;
  final bool isLoading;
  final UserEntity user;
  final bool isExpanded;

  const _MonthCard({
    required this.year,
    required this.month,
    this.monthData,
    required this.isLoading,
    required this.user,
    this.isExpanded = false,
  });

  @override
  State<_MonthCard> createState() => _MonthCardState();
}

class _MonthCardState extends State<_MonthCard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;
    final monthName = _monthName(context, widget.month);
    final md = widget.monthData;

    return Card(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                children: [
                  Icon(
                    _isExpanded
                        ? PhosphorIcons.caretDown
                        : PhosphorIcons.caretRight,
                    size: 20,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Text('$monthName ${widget.year}', style: TextStyles.title),
                  const Spacer(),
                  if (widget.isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else ...[
                    Text(
                      '${md?.receiptCount ?? 0} ${t.translate('sales.receipts', languageCode: langCode)}',
                      style: TextStyles.body,
                    ),
                    const SizedBox(width: Spacing.md),
                    Text(
                      PriceHelper.format(
                        md?.totalPiastres ?? 0,
                        languageCode: langCode,
                      ),
                      style: TextStyles.title,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_isExpanded && md != null)
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                Spacing.md,
                0,
                Spacing.md,
                Spacing.sm,
              ),
              itemCount: md.receipts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final receipt = md.receipts[index];
                final time = _formatTime(receipt.createdAt);
                return InkWell(
                  onTap: () => _showReceiptDetail(context, receipt),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(receipt.orderNumber, style: TextStyles.body),
                              const SizedBox(height: 2),
                              Text(
                                '$time · ${receipt.items.length} ${t.translate('sales.items', languageCode: langCode)}',
                                style: TextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          PriceHelper.format(
                            receipt.totalPiastres,
                            languageCode: langCode,
                          ),
                          style: TextStyles.body,
                        ),
                        const SizedBox(width: Spacing.sm),
                        StatusBadge(receipt.status),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _monthName(BuildContext context, int month) {
    final locale = Localizations.localeOf(context).languageCode;
    if (locale == 'ar') {
      const names = {
        1: 'يناير',
        2: 'فبراير',
        3: 'مارس',
        4: 'أبريل',
        5: 'مايو',
        6: 'يونيو',
        7: 'يوليو',
        8: 'أغسطس',
        9: 'سبتمبر',
        10: 'أكتوبر',
        11: 'نوفمبر',
        12: 'ديسمبر',
      };
      return names[month] ?? '';
    }
    const names = {
      1: 'January',
      2: 'February',
      3: 'March',
      4: 'April',
      5: 'May',
      6: 'June',
      7: 'July',
      8: 'August',
      9: 'September',
      10: 'October',
      11: 'November',
      12: 'December',
    };
    return names[month] ?? '';
  }

  void _showReceiptDetail(BuildContext context, ReceiptEntity receipt) {
    showAdaptiveDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: context.read<ReceiptsBloc>(),
        child: ReceiptDetailDialog(receipt: receipt, user: widget.user),
      ),
    );
  }
}

class _ShiftReceiptList extends StatelessWidget {
  final UserEntity user;
  final List<ReceiptEntity>? receipts;

  const _ShiftReceiptList({required this.user, required this.receipts});

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;

    final headerText = t.translate('sales.mySales', languageCode: langCode);

    if (receipts == null || receipts!.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            child: Text(headerText, style: TextStyles.heading2),
          ),
          const SizedBox(height: Spacing.sm),
          Expanded(
            child: AppEmpty(
              icon: PhosphorIcons.receiptDuotone,
              body: t.translate('state.empty.receipt', languageCode: langCode),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          child: Text(headerText, style: TextStyles.heading2),
        ),
        const SizedBox(height: Spacing.sm),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
            itemCount: receipts!.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1,
              indent: Spacing.sm,
              endIndent: Spacing.sm,
            ),
            itemBuilder: (context, index) {
              final receipt = receipts![index];
              return Card(
                margin: EdgeInsets.zero,
                child: ListTile(
                  title: Text(receipt.orderNumber, style: TextStyles.title),
                  subtitle: Text(
                    '${_formatTime(receipt.createdAt)} · ${receipt.items.length} ${t.translate('sales.items', languageCode: langCode)}',
                    style: TextStyles.bodySmall,
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusBadge(receipt.status),
                      const SizedBox(width: Spacing.sm),
                      Text(
                        PriceHelper.format(
                          receipt.totalPiastres,
                          languageCode: langCode,
                        ),
                        style: TextStyles.body,
                      ),
                    ],
                  ),
                  onTap: () => _showReceiptDialog(context, receipt, user),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

void _showReceiptDialog(
  BuildContext context,
  ReceiptEntity receipt,
  UserEntity user,
) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => BlocProvider.value(
      value: context.read<ReceiptsBloc>(),
      child: ReceiptDetailDialog(receipt: receipt, user: user),
    ),
  );
}

String _formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
