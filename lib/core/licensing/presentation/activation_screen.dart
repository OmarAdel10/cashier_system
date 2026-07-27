import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../theme/app_theme.dart';
import '../../../../features/settings/data/services/localization_service.dart';
import '../domain/enums/license_status.dart';
import 'activation_cubit.dart';
import 'widgets/activation_input.dart';
import 'widgets/device_id_qr.dart';

class ActivationScreen extends StatefulWidget {
  final VoidCallback onActivated;
  final String langCode;

  const ActivationScreen({super.key, required this.onActivated, this.langCode = 'en'});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  late final ActivationCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = ActivationCubit();
    _cubit.checkLicense();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: Scaffold(
        body: SafeArea(
          child: BlocConsumer<ActivationCubit, ActivationState>(
            bloc: _cubit,
            listener: (context, state) {
              if (state is ActivationSuccess) {
                widget.onActivated();
              }
            },
            builder: (context, state) => switch (state) {
              ActivationInitial() => _BrandedSplash(langCode: widget.langCode),
              ActivationLoading() => _BrandedSplash(langCode: widget.langCode),
              ActivationError(message: final msg) => _ActivationForm(
                  cubit: _cubit,
                  deviceId: null,
                  licenseStatus: null,
                  errorMessage: msg,
                  langCode: widget.langCode,
                ),
              ActivationDeviceReady(deviceId: final id, status: final s) =>
                _ActivationForm(
                  cubit: _cubit,
                  deviceId: id,
                  licenseStatus: s,
                  errorMessage: null,
                  langCode: widget.langCode,
                ),
              ActivationSuccess() => _BrandedSplash(langCode: widget.langCode),
            },
          ),
        ),
      ),
    );
  }
}

class _BrandedSplash extends StatelessWidget {
  final String langCode;

  const _BrandedSplash({this.langCode = 'en'});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = LocalizationService();
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            t.translate('appTitle', languageCode: langCode),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }
}

class _ActivationForm extends StatelessWidget {
  final ActivationCubit cubit;
  final String? deviceId;
  final LicenseStatus? licenseStatus;
  final String? errorMessage;
  final String langCode;

  const _ActivationForm({
    required this.cubit,
    required this.deviceId,
    required this.licenseStatus,
    required this.errorMessage,
    required this.langCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = LocalizationService();
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.shield_outlined,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            t.translate('licensing.activationRequired', languageCode: langCode),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t.translate('licensing.activationInstructions', languageCode: langCode),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          if (deviceId != null) DeviceIdQr(deviceId: deviceId!, langCode: langCode),
          const SizedBox(height: 32),
          ActivationInput(
            onSubmit: (key) => cubit.submitActivationKey(key),
            errorMessage: errorMessage,
            isLoading: false,
            langCode: langCode,
          ),
          if (licenseStatus == LicenseStatus.tampered)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                t.translate('licensing.tamperedWarning', languageCode: langCode),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
