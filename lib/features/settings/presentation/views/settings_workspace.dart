import 'package:cashier_system/features/settings/presentation/widgets/prep_categories_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/business/business_type.dart';
import '../../../../core/business/business_type_registry.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_error.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../features/checkout/domain/helpers/price_helper.dart';
import '../../../../features/auth/domain/entities/user_entity.dart';
import '../../../../features/auth/domain/entities/user_role.dart';
import '../../../../features/auth/presentation/widgets/user_management_section.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_event.dart';
import '../../data/services/localization_service.dart';
import '../bloc/settings_bloc.dart';
import '../bloc/settings_event.dart';
import '../bloc/settings_state.dart';
import '../widgets/admin_general_section.dart';
import '../widgets/appearance_section.dart';
import '../widgets/localization_section.dart';
import '../widgets/tax_section.dart';
import '../widgets/printing_section.dart';
import '../widgets/export_directory_section.dart';
import '../widgets/shortcuts_section.dart';
import '../widgets/reset_section.dart';
import '../widgets/payment_types_section.dart';
import '../widgets/table_mode_sections.dart';

class _BusinessTypeCard extends StatelessWidget {
  final BusinessType businessType;
  final String languageCode;

  const _BusinessTypeCard({
    required this.businessType,
    required this.languageCode,
  });

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final meta = BusinessTypeRegistry.metadata[businessType]!;
    final name = t.translate(meta.labelKey, languageCode: languageCode);
    final favoritesStripEnabled = context.select<SettingsBloc, bool>(
      (b) => b.state.settings.favoritesStripEnabled,
    );

    return Card(
      child: Padding(
        padding: EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(meta.icon, size: 32),
                SizedBox(width: Spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyles.title),
                      SizedBox(height: Spacing.xs),
                      Text(
                        t.translate(
                          'settings.businessType.locked',
                          languageCode: languageCode,
                        ),
                        style: TextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (businessType.favoritesEnabled) ...[
              SizedBox(height: Spacing.sm),
              const Divider(),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  t.translate(
                    'settings.favoritesStrip.label',
                    languageCode: languageCode,
                  ),
                ),
                subtitle: Text(
                  t.translate(
                    'settings.favoritesStrip.subtitle',
                    languageCode: languageCode,
                  ),
                ),
                value: favoritesStripEnabled,
                onChanged: (v) {
                  context.read<SettingsBloc>().add(FavoritesStripChanged(v));
                },
              ),
            ],
            if (businessType.isTimeBilling) ...[
              SizedBox(height: Spacing.sm),
              const Divider(),
              _MinimumGameCostField(languageCode: languageCode),
            ],
          ],
        ),
      ),
    );
  }
}

class _MinimumGameCostField extends StatefulWidget {
  final String languageCode;

  const _MinimumGameCostField({required this.languageCode});

  @override
  State<_MinimumGameCostField> createState() => _MinimumGameCostFieldState();
}

class _MinimumGameCostFieldState extends State<_MinimumGameCostField> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _syncFromSettings();
  }

  void _syncFromSettings() {
    final cost = context.read<SettingsBloc>().state.settings.minimumGameCost;
    final text = (cost / 100).toStringAsFixed(2);
    if (_controller.text != text) {
      _controller.text = text;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minimumGameCost = context.select<SettingsBloc, int>(
      (b) => b.state.settings.minimumGameCost,
    );
    final t = LocalizationService();
    final text = (minimumGameCost / 100).toStringAsFixed(2);
    if (_controller.text != text) {
      _controller.text = text;
    }

    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,7}(\.\d{0,2})?')),
      ],
      decoration: InputDecoration(
        labelText: t.translate(
          'settings.minimumGameCost.label',
          languageCode: widget.languageCode,
        ),
        helperText: t.translate(
          'settings.minimumGameCost.subtitle',
          languageCode: widget.languageCode,
        ),
        suffixText: PriceHelper.format(
          minimumGameCost,
          languageCode: widget.languageCode,
        ),
        border: const OutlineInputBorder(),
      ),
      onSubmitted: (value) {
        final egp = double.tryParse(value.trim());
        if (egp == null) return;
        final piastres = (egp * 100).round();
        final clamped = piastres < 100 ? 100 : piastres;
        context.read<SettingsBloc>().add(MinimumGameCostChanged(clamped));
      },
    );
  }
}

class _UsersLoader extends StatefulWidget {
  final Widget child;
  const _UsersLoader({required this.child});
  @override
  State<_UsersLoader> createState() => _UsersLoaderState();
}

class _UsersLoaderState extends State<_UsersLoader> {
  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(const LoadUsers());
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class SettingsWorkspace extends StatelessWidget {
  final UserEntity? currentUser;

  const SettingsWorkspace({super.key, this.currentUser});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsBloc, SettingsState>(
      buildWhen: (prev, next) {
        return prev.status != next.status ||
            prev.settings.languageCode != next.settings.languageCode ||
            prev.settings.businessType != next.settings.businessType ||
            prev.settings.favoritesStripEnabled !=
                next.settings.favoritesStripEnabled ||
            prev.settings.minimumGameCost != next.settings.minimumGameCost;
      },
      builder: (context, state) {
        final langCode = state.settings.languageCode;
        final mode = BusinessType.fromId(state.settings.businessType);
        final t = LocalizationService();
        final isAdmin =
            currentUser != null && currentUser!.role == UserRole.admin;
        final title = t.translate('settings', languageCode: langCode);

        final Widget body = switch (state.status) {
          SettingsStatus.loading || SettingsStatus.initial => AppLoading(
            message: t.translate(
              'state.loading.loading',
              languageCode: langCode,
            ),
          ),
          SettingsStatus.error => AppError(
            headline: title,
            body: t.translate('state.error.load', languageCode: langCode),
            actionLabel: t.translate(
              'state.error.load.action',
              languageCode: langCode,
            ),
            onAction: () =>
                context.read<SettingsBloc>().add(const LoadSettings()),
          ),
          SettingsStatus.ready => SingleChildScrollView(
            padding: EdgeInsets.all(Spacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isAdmin)
                  _BusinessTypeCard(
                    businessType: BusinessType.fromId(
                      state.settings.businessType,
                    ),
                    languageCode: langCode,
                  ),
                if (isAdmin) SizedBox(height: Spacing.lg),
                if (isAdmin) ...[
                  _UsersLoader(
                    child: UserManagementSection(currentUser: currentUser!),
                  ),
                  SizedBox(height: Spacing.lg),
                  const AdminGeneralSection(),
                  SizedBox(height: Spacing.lg),
                ],
                const AppearanceSection(),
                SizedBox(height: Spacing.lg),
                const LocalizationSection(),
                SizedBox(height: Spacing.lg),
                if (isAdmin) ...[
                  const TaxSection(),
                  const SizedBox(height: Spacing.lg),
                  const PaymentTypesSection(),
                  const SizedBox(height: Spacing.lg),
                  const PrepCategoriesSection(),
                  const SizedBox(height: Spacing.lg),
                  PrintingSection(
                    showBarcodePrinter: mode.barcodesEnabled,
                    showReceiptPrinter: mode.receiptsEnabled,
                  ),
                  SizedBox(height: Spacing.lg),
                  if (mode.isTableBilling) ...[
                    const FloorSection(),
                    SizedBox(height: Spacing.lg),
                    const TicketsSection(),
                    SizedBox(height: Spacing.lg),
                  ],
                  const ExportDirectorySection(),
                  SizedBox(height: Spacing.lg),
                  const ResetSection(),
                ],
                if (isAdmin &&
                    !mode.isTimeBilling &&
                    (mode.favoritesEnabled
                        ? state.settings.favoritesStripEnabled
                        : true)) ...[
                  ShortcutsSection(userRole: currentUser?.role),
                  SizedBox(height: Spacing.lg),
                ],
              ],
            ),
          ),
        };

        return Scaffold(
          body: SectionCard(
            title: title,
            mainAxisSize: MainAxisSize.max,
            child: body,
          ),
        );
      },
    );
  }
}
