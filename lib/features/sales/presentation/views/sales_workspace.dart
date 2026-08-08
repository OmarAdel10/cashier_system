import 'package:cashier_system/core/theme/spacing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/domain/entities/user_role.dart';
import '../../../auth/presentation/bloc/shift_bloc.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_error.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../checkout/presentation/bloc/station_bloc.dart';
import '../../../checkout/presentation/bloc/station_state.dart';
import '../../../receipts/presentation/bloc/receipts_bloc.dart';
import '../../../receipts/presentation/bloc/receipts_state.dart';
import '../../../settings/data/services/localization_service.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../bloc/sales_bloc.dart';
import '../bloc/sales_event.dart';
import '../bloc/sales_state.dart';
import '../widgets/month_browser.dart';
import '../widgets/session_record_card.dart';
import '../widgets/shift_receipt_list.dart';
import '../widgets/summary_bar.dart';

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
      context.read<SalesBloc>().add(
        LoadShiftReceipts(shiftId: shiftState.shift!.id),
      );
    }
    context.read<SalesBloc>().add(const LoadSessionRecords(limit: 20));
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.read<SettingsBloc>().state.settings.languageCode;
    final isAdmin = widget.user.role == UserRole.admin;

    return BlocListener<StationBloc, StationState>(
      listenWhen: (previous, current) =>
          previous.lastCompletedSession != current.lastCompletedSession &&
          current.lastCompletedSession != null,
      listener: (context, state) {
        context.read<SalesBloc>().add(const LoadSessionRecords(limit: 20));
      },
      child: BlocListener<ReceiptsBloc, ReceiptsState>(
        listenWhen: (previous, current) =>
            previous.status == ReceiptBlocStatus.loading &&
            current.status == ReceiptBlocStatus.ready,
        listener: (context, state) {
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
          buildWhen: (prev, curr) =>
              prev.status != curr.status ||
              prev.todaySummary != curr.todaySummary ||
              prev.shiftReceipts != curr.shiftReceipts ||
              !listEquals(prev.months, curr.months),
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

            if (state.status == SalesStatus.error &&
                state.todaySummary == null) {
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

            final now = DateTime.now();
            final currentMonth = state.months
                .cast<MonthGroupedData?>()
                .firstWhere(
                  (m) => m?.year == now.year && m?.month == now.month,
                  orElse: () => null,
                );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.sessionRecords != null) ...[
                  SectionCard(
                    title: t.translate(
                      'station.sessionRecords',
                      languageCode: langCode,
                    ),
                    child: SizedBox(
                      height: 240,
                      child: state.sessionRecords!.isEmpty
                          ? AppEmpty(
                              icon: PhosphorIcons.gameControllerDuotone,
                              body: t.translate(
                                'state.empty.session',
                                languageCode: langCode,
                              ),
                            )
                          : ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: state.sessionRecords!.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: Spacing.sm),
                              itemBuilder: (context, index) =>
                                  SessionRecordCard(
                                    record: state.sessionRecords![index],
                                    langCode: langCode,
                                    t: t,
                                  ),
                            ),
                    ),
                  ),
                  const SizedBox(height: Spacing.md),
                ],
                if (isAdmin)
                  Expanded(
                    child: SectionCard(
                      mainAxisSize: MainAxisSize.max,
                      title: t.translate(
                        'sales.history',
                        languageCode: langCode,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SummaryBar(
                            totalPiastres:
                                state.todaySummary?.totalPiastres ?? 0,
                            receiptCount: state.todaySummary?.receiptCount ?? 0,
                            itemsSold: state.todaySummary?.itemsSold ?? 0,
                            monthlyOrderCount: currentMonth?.receiptCount ?? 0,
                            monthlyTotalPiastres:
                                currentMonth?.totalPiastres ?? 0,
                            monthlyItemsSold: currentMonth?.itemsSold ?? 0,
                            langCode: langCode,
                            t: t,
                          ),
                          const SizedBox(height: Spacing.md),
                          Expanded(
                            child: MonthBrowser(
                              user: widget.user,
                              langCode: langCode,
                              t: t,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!isAdmin)
                  Expanded(
                    child: ShiftReceiptList(
                      user: widget.user,
                      receipts: state.shiftReceipts,
                      langCode: langCode,
                      t: t,
                      shiftStartedAt: context
                          .read<ShiftBloc>()
                          .state
                          .shift
                          ?.startedAt,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
