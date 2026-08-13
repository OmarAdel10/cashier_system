import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../settings/data/services/localization_service.dart';
import '../bloc/sales_bloc.dart';
import '../bloc/sales_event.dart';
import '../bloc/sales_state.dart';
import 'month_card.dart';

class MonthBrowser extends StatefulWidget {
  final UserEntity user;
  final LocalizationService t;
  final String langCode;

  const MonthBrowser({
    super.key,
    required this.user,
    required this.t,
    required this.langCode,
  });

  @override
  State<MonthBrowser> createState() => _MonthBrowserState();
}

class _MonthBrowserState extends State<MonthBrowser> {
  final List<int> _trackedMonths = [];

  @override
  void initState() {
    super.initState();
    _loadInitialMonths();
  }

  void _loadInitialMonths() {
    final now = DateTime.now();
    for (int i = 0; i < 6; i++) {
      final dt = DateTime(now.year, now.month - i, 1);
      final year = dt.year;
      final month = dt.month;
      _trackedMonths.add((year - 1970) * 12 + (month - 1));
      context.read<SalesBloc>().add(LoadMonth(year: year, month: month));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SalesBloc, SalesState>(
      buildWhen: (prev, curr) => !listEquals(prev.months, curr.months),
      builder: (context, state) {
        final monthMap = <int, MonthGroupedData>{
          for (final m in state.months) (m.year - 1970) * 12 + (m.month - 1): m,
        };
        return ListView.builder(
          itemCount: _trackedMonths.length,
          itemBuilder: (context, index) {
            final key = _trackedMonths[index];
            final monthData = monthMap[key];
            final year = key ~/ 12 + 1970;
            final m = key % 12 + 1;
            return (monthData != null && monthData.receiptCount > 0)
                ? MonthCard(
                    year: year,
                    month: m,
                    monthData: monthData,
                    isLoading: false,
                    user: widget.user,
                    langCode: widget.langCode,
                    t: widget.t,
                    isExpanded: index == 0,
                  )
                : const SizedBox.shrink();
          },
        );
      },
    );
  }
}
