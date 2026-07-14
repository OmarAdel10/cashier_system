import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/bloc/shift_bloc.dart';
import '../../../checkout/domain/helpers/price_helper.dart';

import '../../../receipts/domain/entities/receipt_entity.dart';
import '../../../receipts/presentation/bloc/receipts_bloc.dart';
import '../../../receipts/presentation/widgets/receipt_detail_dialog.dart';
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
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    context.read<SalesBloc>().add(const LoadTodaySummary());
    final shiftState = context.read<ShiftBloc>().state;
    if (shiftState.shift != null) {
      context.read<SalesBloc>().add(LoadShiftReceipts(shiftId: shiftState.shift!.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;
    final isAdmin = widget.user.role == UserRole.admin;

    return BlocBuilder<SalesBloc, SalesState>(
      builder: (context, state) {
        if (state.status == SalesStatus.loading && state.todaySummary == null) {
          return AppLoading(message: t.translate('state.loading.loading', languageCode: langCode));
        }

        if (state.status == SalesStatus.error && state.todaySummary == null) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(t.translate('state.error.load', languageCode: langCode)),
                const SizedBox(height: Spacing.sm),
                TextButton(
                  onPressed: _loadData,
                  child: Text(t.translate('state.error.retry', languageCode: langCode)),
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryBar(summary: state.todaySummary, isAdmin: isAdmin),
            const SizedBox(height: Spacing.md),
            Expanded(
              child: isAdmin
                  ? _MonthBrowser(salesBloc: context.read<SalesBloc>(), monthData: state.monthData)
                  : _ShiftReceiptList(receipts: state.shiftReceipts),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryBar extends StatelessWidget {
  final TodaySummary? summary;
  final bool isAdmin;

  const _SummaryBar({required this.summary, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;

    if (summary == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
      child: Row(
        children: [
          _SummaryChip(
            label: t.translate('sales.total', languageCode: langCode),
            value: PriceHelper.format(summary!.totalPiastres, languageCode: langCode),
          ),
          const SizedBox(width: Spacing.sm),
          _SummaryChip(
            label: t.translate('sales.receipts', languageCode: langCode),
            value: summary!.receiptCount.toString(),
          ),
          const SizedBox(width: Spacing.sm),
          _SummaryChip(
            label: t.translate('sales.itemsSold', languageCode: langCode),
            value: summary!.itemsSold.toString(),
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyles.caption),
          const SizedBox(height: 2),
          Text(value, style: TextStyles.title),
        ],
      ),
    );
  }
}

class _MonthBrowser extends StatefulWidget {
  final SalesBloc salesBloc;
  final MonthData? monthData;

  const _MonthBrowser({required this.salesBloc, required this.monthData});

  @override
  State<_MonthBrowser> createState() => _MonthBrowserState();
}

class _MonthBrowserState extends State<_MonthBrowser> {
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedYear = now.year;
    _selectedMonth = now.month;
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(t.translate('sales.monthBrowser', languageCode: langCode), style: TextStyles.heading3),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _prevMonth,
              ),
              Text('$_selectedYear-${_selectedMonth.toString().padLeft(2, '0')}'),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextMonth,
              ),
              const SizedBox(width: Spacing.sm),
              FilledButton.tonalIcon(
                onPressed: _loadMonth,
                icon: const Icon(Icons.search, size: 16),
                label: Text(t.translate('state.error.retry', languageCode: langCode)),
              ),
            ],
          ),
          if (widget.monthData != null) ...[
            const SizedBox(height: Spacing.sm),
            Row(
              children: [
                _SummaryChip(
                  label: t.translate('sales.total', languageCode: langCode),
                  value: PriceHelper.format(widget.monthData!.totalPiastres, languageCode: langCode),
                ),
                const SizedBox(width: Spacing.sm),
                _SummaryChip(
                  label: t.translate('sales.receipts', languageCode: langCode),
                  value: widget.monthData!.receiptCount.toString(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _prevMonth() {
    setState(() {
      if (_selectedMonth == 1) {
        _selectedYear--;
        _selectedMonth = 12;
      } else {
        _selectedMonth--;
      }
    });
    _loadMonth();
  }

  void _nextMonth() {
    final now = DateTime.now();
    final next = _selectedMonth == 12 ? DateTime(_selectedYear + 1, 1) : DateTime(_selectedYear, _selectedMonth + 1);
    if (next.isAfter(DateTime(now.year, now.month + 1))) return;
    setState(() {
      if (_selectedMonth == 12) {
        _selectedYear++;
        _selectedMonth = 1;
      } else {
        _selectedMonth++;
      }
    });
    _loadMonth();
  }

  void _loadMonth() {
    widget.salesBloc.add(LoadMonth(year: _selectedYear, month: _selectedMonth));
  }
}

class _ShiftReceiptList extends StatelessWidget {
  final List<ReceiptEntity>? receipts;

  const _ShiftReceiptList({required this.receipts});

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.watch<SettingsBloc>().state.settings.languageCode;

    if (receipts == null || receipts!.isEmpty) {
      return Center(
        child: Text(
          t.translate('state.empty.checkout', languageCode: langCode),
          style: TextStyles.body,
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
      itemCount: receipts!.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: Spacing.sm, endIndent: Spacing.sm),
      itemBuilder: (context, index) {
        final receipt = receipts![index];
        return ListTile(
          title: Text(receipt.orderNumber, style: TextStyles.title),
          subtitle: Text(
            '${receipt.createdAt.toString().substring(0, 19)}  —  ${PriceHelper.format(receipt.totalPiastres, languageCode: langCode)}',
            style: TextStyles.bodySmall,
          ),
          trailing: Text(
            receipt.items.length.toString(),
            style: TextStyles.bodySmall,
          ),
          onTap: () {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => BlocProvider.value(
                value: context.read<ReceiptsBloc>(),
                child: ReceiptDetailDialog(receipt: receipt),
              ),
            );
          },
        );
      },
    );
  }
}
