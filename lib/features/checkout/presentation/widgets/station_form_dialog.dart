import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:cashier_system/core/theme/spacing.dart';
import 'package:cashier_system/core/theme/text_styles.dart';
import 'package:cashier_system/core/widgets/validated_field.dart';
import 'package:cashier_system/features/checkout/domain/entities/station_entity.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Add/edit form for a station. Pops a [StationEntity] on submit.
class StationFormDialog extends StatefulWidget {
  const StationFormDialog({super.key, this.station});

  /// When null the dialog is in "add" mode, otherwise "edit" mode.
  final StationEntity? station;

  @override
  State<StationFormDialog> createState() => _StationFormDialogState();
}

class _StationFormDialogState extends State<StationFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _normalRateCtrl;
  late final TextEditingController _multiRateCtrl;
  late final TextEditingController _minNormalCtrl;
  late final TextEditingController _minMultiCtrl;
  late final TextEditingController _iconAssetCtrl;
  late final GlobalKey<ValidatedFieldState> _nameKey;
  late final GlobalKey<ValidatedFieldState> _categoryKey;
  late final GlobalKey<ValidatedFieldState> _normalRateKey;
  late final GlobalKey<ValidatedFieldState> _multiRateKey;
  late final GlobalKey<ValidatedFieldState> _minNormalKey;
  late final GlobalKey<ValidatedFieldState> _minMultiKey;
  StationType _stationType = StationType.playstation;

  bool get _isEditing => widget.station != null;

  @override
  void initState() {
    super.initState();
    final s = widget.station;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _categoryCtrl = TextEditingController(text: s?.parentCategory ?? '');
    _normalRateCtrl = TextEditingController(
      text: s == null ? '' : _formatDouble(s.normalHourlyRate),
    );
    _multiRateCtrl = TextEditingController(
      text: s == null ? '' : _formatDouble(s.multiHourlyRate),
    );
    _minNormalCtrl = TextEditingController(
      text: s == null ? '' : s.minimumGameCostNormal.toString(),
    );
    _minMultiCtrl = TextEditingController(
      text: s == null ? '' : s.minimumGameCostMulti.toString(),
    );
    _iconAssetCtrl = TextEditingController(text: s?.iconAsset ?? '');
    _nameKey = GlobalKey<ValidatedFieldState>();
    _categoryKey = GlobalKey<ValidatedFieldState>();
    _normalRateKey = GlobalKey<ValidatedFieldState>();
    _multiRateKey = GlobalKey<ValidatedFieldState>();
    _minNormalKey = GlobalKey<ValidatedFieldState>();
    _minMultiKey = GlobalKey<ValidatedFieldState>();
    if (s != null) {
      _stationType = s.stationType;
    }
  }

  String _formatDouble(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _normalRateCtrl.dispose();
    _multiRateCtrl.dispose();
    _minNormalCtrl.dispose();
    _minMultiCtrl.dispose();
    _iconAssetCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    _nameKey.currentState?.validate();
    _categoryKey.currentState?.validate();
    _normalRateKey.currentState?.validate();
    _multiRateKey.currentState?.validate();
    _minNormalKey.currentState?.validate();
    _minMultiKey.currentState?.validate();
    final ok =
        _nameKey.currentState?.isValid == true &&
        _categoryKey.currentState?.isValid == true &&
        _normalRateKey.currentState?.isValid == true &&
        _multiRateKey.currentState?.isValid == true &&
        _minNormalKey.currentState?.isValid == true &&
        _minMultiKey.currentState?.isValid == true;
    if (!ok) return;

    final id = widget.station?.id ?? _nameCtrl.text.trim();
    Navigator.of(context).pop(
      StationEntity(
        id: id,
        name: _nameCtrl.text.trim(),
        parentCategory: _categoryCtrl.text.trim(),
        stationType: _stationType,
        normalHourlyRate: double.tryParse(_normalRateCtrl.text) ?? 0,
        multiHourlyRate: double.tryParse(_multiRateCtrl.text) ?? 0,
        minimumGameCostNormal: int.tryParse(_minNormalCtrl.text) ?? 0,
        minimumGameCostMulti: int.tryParse(_minMultiCtrl.text) ?? 0,
        iconAsset: _iconAssetCtrl.text.trim().isEmpty
            ? 'assets/icons/ps4.svg'
            : _iconAssetCtrl.text.trim(),
        status: widget.station?.status ?? StationStatus.available,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select<SettingsBloc, String>(
      (s) => s.state.settings.languageCode,
    );

    return AlertDialog(
      title: Text(
        t.translate(
          _isEditing ? 'station.form.editTitle' : 'station.form.title',
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
              Text(
                t.translate('station.form.type', languageCode: langCode),
                style: TextStyles.body,
              ),
              const SizedBox(height: Spacing.xs),
              SegmentedButton<StationType>(
                segments: [
                  ButtonSegment(
                    value: StationType.playstation,
                    icon: const Icon(PhosphorIcons.gameController, size: 18),
                    label: Text(
                      t.translate(
                        'station.form.typePlaystation',
                        languageCode: langCode,
                      ),
                    ),
                  ),
                  ButtonSegment(
                    value: StationType.table,
                    icon: const Icon(PhosphorIcons.table, size: 18),
                    label: Text(
                      t.translate(
                        'station.form.typeTable',
                        languageCode: langCode,
                      ),
                    ),
                  ),
                ],
                selected: {_stationType},
                onSelectionChanged: (selection) =>
                    setState(() => _stationType = selection.first),
              ),
              const SizedBox(height: Spacing.md),
              ValidatedField(
                autoValidate: false,
                key: _nameKey,
                controller: _nameCtrl,
                focusNode: null,
                label: t.translate('station.form.name', languageCode: langCode),
                hint: t.translate('station.form.name', languageCode: langCode),
                prefixIcon: const Icon(PhosphorIcons.gameController),
                rules: [
                  ValidatedFieldRule(
                    message: 'Required',
                    isValid: (v) => v.trim().isNotEmpty,
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              ValidatedField(
                key: _categoryKey,
                controller: _categoryCtrl,
                focusNode: null,
                label: t.translate(
                  'station.form.parentCategory',
                  languageCode: langCode,
                ),
                hint: t.translate(
                  'station.form.parentCategory',
                  languageCode: langCode,
                ),
                prefixIcon: const Icon(PhosphorIcons.folder),
                rules: [
                  ValidatedFieldRule(
                    message: 'Required',
                    isValid: (v) => v.trim().isNotEmpty,
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: ValidatedField(
                      key: _normalRateKey,
                      controller: _normalRateCtrl,
                      focusNode: null,
                      label: t.translate(
                        'station.form.normalRate',
                        languageCode: langCode,
                      ),
                      hint: t.translate(
                        'station.form.normalRate',
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
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: ValidatedField(
                      key: _multiRateKey,
                      controller: _multiRateCtrl,
                      focusNode: null,
                      label: t.translate(
                        'station.form.multiRate',
                        languageCode: langCode,
                      ),
                      hint: t.translate(
                        'station.form.multiRate',
                        languageCode: langCode,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      prefixIcon: const Icon(PhosphorIcons.usersThree),
                      rules: [
                        ValidatedFieldRule(
                          message: 'Required',
                          isValid: (v) =>
                              (double.tryParse(v) ?? -1) >= 0 &&
                              v.trim().isNotEmpty,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: ValidatedField(
                      key: _minNormalKey,
                      controller: _minNormalCtrl,
                      focusNode: null,
                      label: t.translate(
                        'station.form.minNormal',
                        languageCode: langCode,
                      ),
                      hint: t.translate(
                        'station.form.minNormal',
                        languageCode: langCode,
                      ),
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(PhosphorIcons.coins),
                      rules: [
                        ValidatedFieldRule(
                          message: 'Required',
                          isValid: (v) => (int.tryParse(v) ?? -1) >= 0,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: ValidatedField(
                      key: _minMultiKey,
                      controller: _minMultiCtrl,
                      focusNode: null,
                      label: t.translate(
                        'station.form.minMulti',
                        languageCode: langCode,
                      ),
                      hint: t.translate(
                        'station.form.minMulti',
                        languageCode: langCode,
                      ),
                      keyboardType: TextInputType.number,
                      prefixIcon: const Icon(PhosphorIcons.coins),
                      rules: [
                        ValidatedFieldRule(
                          message: 'Required',
                          isValid: (v) => (int.tryParse(v) ?? -1) >= 0,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Spacing.sm),
              ValidatedField(
                key: null,
                controller: _iconAssetCtrl,
                focusNode: null,
                label: t.translate(
                  'station.form.iconAsset',
                  languageCode: langCode,
                ),
                hint: t.translate(
                  'station.form.iconAsset',
                  languageCode: langCode,
                ),
                prefixIcon: const Icon(PhosphorIcons.image),
                rules: const [],
              ),
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
              _isEditing ? 'station.form.save' : 'station.form.add',
              languageCode: langCode,
            ),
          ),
        ),
      ],
    );
  }
}
