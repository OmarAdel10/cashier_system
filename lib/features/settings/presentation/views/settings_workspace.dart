import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/business/business_type.dart';
import '../../../../core/business/business_type_registry.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../core/theme/text_styles.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/app_error.dart';
import '../../../../core/widgets/section_card.dart';
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

    return Card(
      child: Padding(
        padding: EdgeInsets.all(Spacing.lg),
        child: Row(
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
      ),
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
      buildWhen: (prev, next) => prev.status != next.status,
      builder: (context, state) {
        final langCode = state.settings.languageCode;
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
                _BusinessTypeCard(
                  businessType: BusinessType.fromId(
                    state.settings.businessType,
                  ),
                  languageCode: langCode,
                ),
                SizedBox(height: Spacing.lg),
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
                  SizedBox(height: Spacing.lg),
                  const PaymentTypesSection(),
                  SizedBox(height: Spacing.lg),
                  const PrintingSection(),
                  SizedBox(height: Spacing.lg),
                  const ExportDirectorySection(),
                  SizedBox(height: Spacing.lg),
                  const ResetSection(),
                ],
                if (isAdmin) ...[
                  const ShortcutsSection(),
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
