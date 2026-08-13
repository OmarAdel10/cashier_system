import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:cashier_system/core/theme/spacing.dart';
import 'package:cashier_system/core/widgets/validated_field.dart';
import 'package:cashier_system/features/checkout/domain/entities/table_entity.dart';
import 'package:cashier_system/features/checkout/domain/entities/zone_entity.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Add/edit form for a table. Pops a [TableEntity] on submit.
class TableFormDialog extends StatefulWidget {
  const TableFormDialog({super.key, this.table, required this.zones});

  /// When null the dialog is in "add" mode, otherwise "edit" mode.
  final TableEntity? table;

  /// Available zones for the zone dropdown.
  final List<ZoneEntity> zones;

  @override
  State<TableFormDialog> createState() => _TableFormDialogState();
}

class _TableFormDialogState extends State<TableFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _capacityCtrl;
  late final TextEditingController _hourlyRateCtrl;
  late final GlobalKey<ValidatedFieldState> _nameKey;
  late final GlobalKey<ValidatedFieldState> _capacityKey;
  late final GlobalKey<ValidatedFieldState> _hourlyRateKey;
  late String _zoneId;
  late bool _isRoom;

  bool get _isEditing => widget.table != null;

  @override
  void initState() {
    super.initState();
    final t = widget.table;
    _nameCtrl = TextEditingController(text: t?.name ?? '');
    _capacityCtrl = TextEditingController(
      text: t == null ? '1' : t.capacity.toString(),
    );
    _hourlyRateCtrl = TextEditingController(
      text: t == null || t.hourlyRatePiastres == 0
          ? ''
          : (t.hourlyRatePiastres / 100)
                .toStringAsFixed(2)
                .replaceFirst(RegExp(r'\.?0+$'), ''),
    );
    _nameKey = GlobalKey<ValidatedFieldState>();
    _capacityKey = GlobalKey<ValidatedFieldState>();
    _hourlyRateKey = GlobalKey<ValidatedFieldState>();
    _zoneId =
        t?.zoneId ?? (widget.zones.isNotEmpty ? widget.zones.first.id : '');
    _isRoom = t?.isRoom ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _capacityCtrl.dispose();
    _hourlyRateCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final roomsEnabled = context
        .read<SettingsBloc>()
        .state
        .settings
        .roomsEnabled;
    _nameKey.currentState?.validate();
    _capacityKey.currentState?.validate();
    if (_isRoom && roomsEnabled) _hourlyRateKey.currentState?.validate();
    final ok =
        _nameKey.currentState?.isValid == true &&
        _capacityKey.currentState?.isValid == true &&
        (!_isRoom ||
            !roomsEnabled ||
            _hourlyRateKey.currentState?.isValid == true);
    if (!ok) return;

    final base = widget.table;
    final rateEgp = double.tryParse(_hourlyRateCtrl.text) ?? 0;
    Navigator.of(context).pop(
      TableEntity(
        id: base?.id ?? _nameCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        zoneId: _zoneId,
        capacity: int.tryParse(_capacityCtrl.text) ?? 1,
        isRoom: roomsEnabled ? _isRoom : widget.table?.isRoom ?? false,
        hourlyRatePiastres: roomsEnabled && _isRoom
            ? (rateEgp * 100).round()
            : widget.table?.hourlyRatePiastres ?? 0,
        status: base?.status ?? TableStatus.available,
        tabOpenedAt: base?.tabOpenedAt,
        activeRoundNumber: base?.activeRoundNumber,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );
    final roomsEnabled = context.select<SettingsBloc, bool>(
      (b) => b.state.settings.roomsEnabled,
    );

    return AlertDialog(
      title: Text(
        t.translate(
          _isEditing ? 'table.form.editTitle' : 'table.form.title',
          languageCode: langCode,
        ),
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValidatedField(
                autoValidate: false,
                key: _nameKey,
                controller: _nameCtrl,
                focusNode: null,
                label: t.translate('table.form.name', languageCode: langCode),
                hint: t.translate('table.form.name', languageCode: langCode),
                prefixIcon: const Icon(PhosphorIcons.table),
                rules: [
                  ValidatedFieldRule(
                    message: 'Required',
                    isValid: (v) => v.trim().isNotEmpty,
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              DropdownButtonFormField<String>(
                key: const Key('tableZoneDropdown'),
                initialValue: _zoneId,
                decoration: InputDecoration(
                  labelText: t.translate(
                    'table.form.zone',
                    languageCode: langCode,
                  ),
                  prefixIcon: const Icon(PhosphorIcons.mapPin),
                  border: const OutlineInputBorder(),
                ),
                items: [
                  for (final zone in widget.zones)
                    DropdownMenuItem(value: zone.id, child: Text(zone.name)),
                ],
                onChanged: (value) => setState(() => _zoneId = value ?? ''),
              ),
              const SizedBox(height: Spacing.sm),
              ValidatedField(
                key: _capacityKey,
                controller: _capacityCtrl,
                focusNode: null,
                label: t.translate(
                  'table.form.capacity',
                  languageCode: langCode,
                ),
                hint: t.translate(
                  'table.form.capacity',
                  languageCode: langCode,
                ),
                prefixIcon: const Icon(PhosphorIcons.usersThree),
                keyboardType: TextInputType.number,
                rules: [
                  ValidatedFieldRule(
                    message: 'Required',
                    isValid: (v) => (int.tryParse(v) ?? -1) >= 1,
                  ),
                ],
              ),
              if (roomsEnabled) ...[
                const SizedBox(height: Spacing.sm),
                SwitchListTile(
                  key: const Key('tableIsRoomSwitch'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    t.translate('table.form.isRoom', languageCode: langCode),
                  ),
                  value: _isRoom,
                  onChanged: (value) => setState(() => _isRoom = value),
                ),
                if (_isRoom) ...[
                  const SizedBox(height: Spacing.xs),
                  ValidatedField(
                    key: _hourlyRateKey,
                    controller: _hourlyRateCtrl,
                    focusNode: null,
                    label: t.translate(
                      'table.form.hourlyRate',
                      languageCode: langCode,
                    ),
                    hint: t.translate(
                      'table.form.hourlyRate',
                      languageCode: langCode,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    prefixIcon: const Icon(PhosphorIcons.clock),
                    rules: [
                      ValidatedFieldRule(
                        message: 'Required',
                        isValid: (v) =>
                            (double.tryParse(v) ?? -1) >= 0 &&
                            v.trim().isNotEmpty,
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(t.translate('cancel', languageCode: langCode)),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(
            t.translate(
              _isEditing ? 'table.form.save' : 'table.form.add',
              languageCode: langCode,
            ),
          ),
        ),
      ],
    );
  }
}
