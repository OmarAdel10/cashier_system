import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cashier_system/core/theme/spacing.dart';
import 'package:cashier_system/core/theme/text_styles.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/zone_entity.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/table_state.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/zone_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/zone_state.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/start_tab_dialog.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/table_card.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';

/// Floor map workspace for table billing: zone sections (dine-in first,
/// takeaway last) with a GridView of [TableCard]s.
class TableWorkspace extends StatelessWidget {
  const TableWorkspace({super.key});

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );

    return BlocBuilder<ZoneBloc, ZoneState>(
      builder: (context, zoneState) {
        final zones = _orderedZones(zoneState.zones);
        return BlocBuilder<TableBloc, TablesState>(
          builder: (context, tableState) {
            if (tableState.status == TablesStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (tableState.status == TablesStatus.error) {
              return Center(
                child: Text(
                  t.translate('state.error.checkout', languageCode: langCode),
                ),
              );
            }

            final tables = tableState.tables;
            if (tables.isEmpty) {
              return Center(
                child: Text(t.translate('table.empty', languageCode: langCode)),
              );
            }

            final byZone = <String, List<TableEntity>>{};
            for (final table in tables) {
              byZone.putIfAbsent(table.zoneId, () => []).add(table);
            }

            return ListView(
              padding: const EdgeInsets.all(Spacing.md),
              children: [
                for (final zone in zones)
                  if (byZone.containsKey(zone.id))
                    _ZoneSection(title: zone.name, tables: byZone[zone.id]!),
                if (byZone.containsKey(''))
                  _ZoneSection(
                    title: t.translate(
                      'table.workspace.unassigned',
                      languageCode: langCode,
                    ),
                    tables: byZone['']!,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  List<ZoneEntity> _orderedZones(List<ZoneEntity> zones) {
    final sorted = [...zones];
    sorted.sort((a, b) {
      if (a.kind != b.kind) return a.kind == ZoneKind.dineIn ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return sorted;
  }
}

class _ZoneSection extends StatelessWidget {
  const _ZoneSection({required this.title, required this.tables});

  final String title;
  final List<TableEntity> tables;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyles.heading2),
        const SizedBox(height: Spacing.sm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 280,
            mainAxisSpacing: Spacing.md,
            crossAxisSpacing: Spacing.md,
            mainAxisExtent: 220,
          ),
          itemCount: tables.length,
          itemBuilder: (context, index) {
            final table = tables[index];
            return TableCard(
              table: table,
              onTap: () {
                if (table.status == TableStatus.available) {
                  showDialog(
                    context: context,
                    builder: (_) => StartTabDialog(table: table),
                  );
                } else {
                  // Session dialog (bill + ordering) lands with TableSessionDialog
                  // in P5; non-available tables stay non-navigable until then.
                }
              },
            );
          },
        ),
        const SizedBox(height: Spacing.lg),
      ],
    );
  }
}
