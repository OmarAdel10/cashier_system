import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cashier_system/core/widgets/app_empty.dart';
import 'package:cashier_system/features/checkout/domain/entities/zone_entity.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/zone_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/zone_event.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/zone_state.dart';
import 'package:cashier_system/features/checkout/presentation/widgets/zone_form_dialog.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';

/// Management dialog listing zones with add/edit/delete actions.
class ZoneManagementDialog extends StatelessWidget {
  const ZoneManagementDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );

    return AlertDialog(
      title: Text(t.translate('zone.manage.title', languageCode: langCode)),
      content: SizedBox(
        width: 420,
        child: BlocBuilder<ZoneBloc, ZoneState>(
          buildWhen: (prev, curr) =>
              prev.zones != curr.zones || prev.status != curr.status,
          builder: (context, state) {
            if (state.zones.isEmpty) {
              return AppEmpty(
                icon: PhosphorIcons.mapPin,
                headline: t.translate('zone.empty', languageCode: langCode),
                body: t.translate('zone.empty.action', languageCode: langCode),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              itemCount: state.zones.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final zone = state.zones[i];
                return ListTile(
                  leading: Icon(
                    zone.kind == ZoneKind.takeaway
                        ? PhosphorIcons.shoppingBag
                        : PhosphorIcons.usersThree,
                  ),
                  title: Text(zone.name),
                  subtitle: Text(
                    t.translate(
                      'zone.form.kind${zone.kind.name}',
                      languageCode: langCode,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        key: Key('zoneEdit_${zone.id}'),
                        icon: const Icon(PhosphorIcons.pencilSimple),
                        tooltip: t.translate(
                          'zone.manage.edit',
                          languageCode: langCode,
                        ),
                        onPressed: () => _editZone(context, zone),
                      ),
                      IconButton(
                        key: Key('zoneDelete_${zone.id}'),
                        icon: const Icon(PhosphorIcons.trash),
                        tooltip: t.translate(
                          'zone.manage.delete',
                          languageCode: langCode,
                        ),
                        onPressed: () =>
                            _deleteZone(context, zone, t, langCode),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.translate('cancel', languageCode: langCode)),
        ),
        FilledButton.icon(
          key: const Key('zoneAddButton'),
          onPressed: () => _addZone(context),
          icon: const Icon(PhosphorIcons.plus, size: 18),
          label: Text(t.translate('zone.manage.add', languageCode: langCode)),
        ),
      ],
    );
  }

  Future<void> _addZone(BuildContext context) async {
    final r = await showDialog<ZoneEntity>(
      context: context,
      builder: (_) => BlocProvider<SettingsBloc>.value(
        value: context.read<SettingsBloc>(),
        child: const ZoneFormDialog(),
      ),
    );
    if (r != null && context.mounted) {
      context.read<ZoneBloc>().add(SaveZone(zone: r));
    }
  }

  Future<void> _editZone(BuildContext context, ZoneEntity zone) async {
    final r = await showDialog<ZoneEntity>(
      context: context,
      builder: (_) => BlocProvider<SettingsBloc>.value(
        value: context.read<SettingsBloc>(),
        child: ZoneFormDialog(zone: zone),
      ),
    );
    if (r != null && context.mounted) {
      context.read<ZoneBloc>().add(SaveZone(zone: r));
    }
  }

  Future<void> _deleteZone(
    BuildContext context,
    ZoneEntity zone,
    LocalizationService t,
    String langCode,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(t.translate('zone.delete.title', languageCode: langCode)),
        content: Text(
          t.translate(
            'zone.delete.confirm',
            languageCode: langCode,
            params: [zone.name],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(t.translate('cancel', languageCode: langCode)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              t.translate('zone.delete.confirmAction', languageCode: langCode),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<ZoneBloc>().add(DeleteZone(zoneId: zone.id));
    }
  }
}
