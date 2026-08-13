import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:cashier_system/core/theme/spacing.dart';
import 'package:cashier_system/core/widgets/validated_field.dart';
import 'package:cashier_system/features/checkout/domain/entities/zone_entity.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Add/edit form for a zone. Pops a [ZoneEntity] on submit.
class ZoneFormDialog extends StatefulWidget {
  const ZoneFormDialog({super.key, this.zone});

  /// When null the dialog is in "add" mode, otherwise "edit" mode.
  final ZoneEntity? zone;

  @override
  State<ZoneFormDialog> createState() => _ZoneFormDialogState();
}

class _ZoneFormDialogState extends State<ZoneFormDialog> {
  late final TextEditingController _nameCtrl;
  late final GlobalKey<ValidatedFieldState> _nameKey;
  late ZoneKind _kind;

  bool get _isEditing => widget.zone != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.zone?.name ?? '');
    _nameKey = GlobalKey<ValidatedFieldState>();
    _kind = widget.zone?.kind ?? ZoneKind.dineIn;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    _nameKey.currentState?.validate();
    if (_nameKey.currentState?.isValid != true) return;

    final base = widget.zone;
    Navigator.of(context).pop(
      ZoneEntity(
        id: base?.id ?? _nameCtrl.text.trim(),
        name: _nameCtrl.text.trim(),
        kind: _kind,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final langCode = context.select<SettingsBloc, String>(
      (b) => b.state.settings.languageCode,
    );

    return AlertDialog(
      title: Text(
        t.translate(
          _isEditing ? 'zone.form.editTitle' : 'zone.form.title',
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
                label: t.translate('zone.form.name', languageCode: langCode),
                hint: t.translate('zone.form.name', languageCode: langCode),
                prefixIcon: const Icon(PhosphorIcons.mapPin),
                rules: [
                  ValidatedFieldRule(
                    message: 'Required',
                    isValid: (v) => v.trim().isNotEmpty,
                  ),
                ],
              ),
              const SizedBox(height: Spacing.md),
              Text(
                t.translate('zone.form.kind', languageCode: langCode),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: Spacing.xs),
              SegmentedButton<ZoneKind>(
                segments: [
                  ButtonSegment(
                    value: ZoneKind.dineIn,
                    icon: const Icon(PhosphorIcons.usersThree, size: 18),
                    label: Text(
                      t.translate(
                        'zone.form.kinddineIn',
                        languageCode: langCode,
                      ),
                    ),
                  ),
                  ButtonSegment(
                    value: ZoneKind.takeaway,
                    icon: const Icon(PhosphorIcons.shoppingBag, size: 18),
                    label: Text(
                      t.translate(
                        'zone.form.kindtakeaway',
                        languageCode: langCode,
                      ),
                    ),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (selection) =>
                    setState(() => _kind = selection.first),
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
              _isEditing ? 'zone.form.save' : 'zone.form.add',
              languageCode: langCode,
            ),
          ),
        ),
      ],
    );
  }
}
