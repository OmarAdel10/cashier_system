import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cashier_system/core/business/business_type.dart';
import 'package:cashier_system/core/theme/spacing.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/station_state.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/end_session_dialog.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/start_session_dialog.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/station_addon_dialog.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/station_card.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';

/// Live grid workspace for [BusinessType.playstation] checkout: stations
/// sorted by status (available > active > overtime) with running timers
/// and session start dialog.
class StationWorkspace extends StatelessWidget {
  const StationWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );

    return BlocBuilder<StationBloc, StationState>(
      builder: (context, state) {
        if (state.status == StationBlocStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == StationBlocStatus.error) {
          return Center(
            child: Text(
              t.translate('state.error.checkout', languageCode: langCode),
            ),
          );
        }

        final sortedStations = _sortStationsByStatus(state.stations);

        if (sortedStations.isEmpty) {
          return Center(
            child: Text(
              t.translate('state.empty.inventory', languageCode: langCode),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(Spacing.md),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 280,
            mainAxisSpacing: Spacing.md,
            crossAxisSpacing: Spacing.md,
            mainAxisExtent: 240,
          ),
          itemCount: sortedStations.length,
          itemBuilder: (context, index) {
            final station = sortedStations[index];
            return StationCard(
              station: station,
              onTap: () => _showTapDialog(context, station),
              onOrderAddon: () => showDialog(
                context: context,
                builder: (_) => BlocProvider<StationBloc>.value(
                  value: context.read<StationBloc>(),
                  child: StationAddonDialog(station: station),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<StationEntity> _sortStationsByStatus(List<StationEntity> stations) {
    const order = {
      StationStatus.available: 0,
      StationStatus.active: 1,
      StationStatus.overtime: 2,
    };
    final sorted = [...stations];
    sorted.sort(
      (a, b) => (order[a.status] ?? 3).compareTo(order[b.status] ?? 3),
    );
    return sorted;
  }

  void _showTapDialog(BuildContext context, StationEntity station) {
    switch (station.status) {
      case StationStatus.available:
        showDialog(
          context: context,
          builder: (_) => BlocProvider<StationBloc>.value(
            value: context.read<StationBloc>(),
            child: StartSessionDialog(station: station),
          ),
        );
      case StationStatus.active:
      case StationStatus.overtime:
        showDialog(
          context: context,
          builder: (_) => BlocProvider<StationBloc>.value(
            value: context.read<StationBloc>(),
            child: EndSessionDialog(station: station),
          ),
        );
    }
  }
}
