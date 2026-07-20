import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../theme/app_theme.dart';
import '../domain/enums/license_status.dart';
import 'activation_cubit.dart';
import 'widgets/activation_input.dart';
import 'widgets/device_id_qr.dart';

class ActivationScreen extends StatefulWidget {
  final VoidCallback onActivated;

  const ActivationScreen({super.key, required this.onActivated});

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
              ActivationInitial() => const _BrandedSplash(),
              ActivationLoading() => const _BrandedSplash(),
              ActivationError(message: final msg) => _ActivationForm(
                  cubit: _cubit,
                  deviceId: null,
                  licenseStatus: null,
                  errorMessage: msg,
                ),
              ActivationDeviceReady(deviceId: final id, status: final s) =>
                _ActivationForm(
                  cubit: _cubit,
                  deviceId: id,
                  licenseStatus: s,
                  errorMessage: null,
                ),
              ActivationSuccess() => const _BrandedSplash(),
            },
          ),
        ),
      ),
    );
  }
}

class _BrandedSplash extends StatelessWidget {
  const _BrandedSplash();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            'Cashier System',
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

  const _ActivationForm({
    required this.cubit,
    required this.deviceId,
    required this.licenseStatus,
    required this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            'Activation Required',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Scan the QR code with your phone to generate an activation key, then enter it below.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          if (deviceId != null) DeviceIdQr(deviceId: deviceId!),
          const SizedBox(height: 32),
          ActivationInput(
            onSubmit: (key) => cubit.submitActivationKey(key),
            errorMessage: errorMessage,
            isLoading: false,
          ),
          if (licenseStatus == LicenseStatus.tampered)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Warning: License tampering detected. Contact support.',
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
