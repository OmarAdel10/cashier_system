// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'device_linking_bloc.dart';

/// Device-linking wizard view (T40 / DAFTARI-86).
/// Three-step flow:
/// 1. Owner sign-in (Firebase ID token)
/// 2. Device naming
/// 3. Link submitted → POST /admin/devices/link
class DeviceLinkingView extends StatelessWidget {
  const DeviceLinkingView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DeviceLinkingBloc>.value(
      value: context.read<DeviceLinkingBloc>(),
      child: const _DeviceLinkingContent(),
    );
  }
}

class _DeviceLinkingContent extends StatelessWidget {
  const _DeviceLinkingContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DeviceLinkingBloc, DeviceLinkingState>(
      builder: (context, state) {
        return switch (state) {
          DeviceLinkingInitial() => _OwnerSignInScreen(
              onSignIn: () =>
                  context.read<DeviceLinkingBloc>().add(const OwnerSignInRequested()),
            ),
          DeviceLinkingLoading() => const Center(child: CircularProgressIndicator()),
          DeviceNaming() => _DeviceNamingScreen(
              onNamed: (hwid, name, platform) =>
                  context.read<DeviceLinkingBloc>().add(
                        DeviceNamed(deviceHwid: hwid, deviceName: name, platform: platform),
                      ),
            ),
          DeviceLinkingReady(
            deviceHwid: final hwid,
            deviceName: final name,
            platform: final platform,
          ) =>
            _LinkConfirmationScreen(
              deviceHwid: hwid,
              deviceName: name,
              platform: platform,
              onSubmit: () => context.read<DeviceLinkingBloc>().add(const LinkSubmitted()),
              onBack: () => context.read<DeviceLinkingBloc>().add(const LinkingReset()),
            ),
          DeviceLinkingSuccess(device: final device) => _SuccessScreen(
              device: device,
              onDone: () => context.read<DeviceLinkingBloc>().add(const LinkingReset()),
            ),
          DeviceLinkingError(message: final message) => _ErrorScreen(
              message: message,
              onRetry: () => context.read<DeviceLinkingBloc>().add(const LinkingReset()),
            ),
        };
      },
    );
  }
}

class _OwnerSignInScreen extends StatelessWidget {
  final VoidCallback onSignIn;
  const _OwnerSignInScreen({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.link, color: Color(0xFF007ACC), size: 64),
                const SizedBox(height: 16),
                Text(
                  'ربط جهاز جديد',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'سجل دخول كمالك لربط جهاز جديد بالمستأجر.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onSignIn,
                  icon: const Icon(Icons.person),
                  label: const Text('تسجيل دخول المالك'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeviceNamingScreen extends StatefulWidget {
  final void Function(String hwid, String name, String? platform) onNamed;
  const _DeviceNamingScreen({required this.onNamed});

  @override
  State<_DeviceNamingScreen> createState() => _DeviceNamingScreenState();
}

class _DeviceNamingScreenState extends State<_DeviceNamingScreen> {
  final _hwidController = TextEditingController();
  final _nameController = TextEditingController();
  final _platformController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _hwidController.dispose();
    _nameController.dispose();
    _platformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.devices, color: Color(0xFF007ACC), size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'معلومات الجهاز',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'أدخل معلومات الجهاز الجديد لربطه.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _hwidController,
                    decoration: const InputDecoration(
                      labelText: 'معرف الجهاز (HWID)',
                      border: OutlineInputBorder(),
                      helperText: 'مثال: abc123-def456',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'معرف الجهاز مطلوب';
                      }
                      if (v.trim().length > 128) {
                        return 'أقصى طول 128 حرف';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم الجهاز',
                      border: OutlineInputBorder(),
                      helperText: 'مثال: عداد النقاط الرئيسي',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'اسم الجهاز مطلوب';
                      }
                      if (v.trim().length > 64) {
                        return 'أقصى طول 64 حرف';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _platformController,
                    decoration: const InputDecoration(
                      labelText: 'المنصة (اختياري)',
                      border: OutlineInputBorder(),
                      helperText: 'مثال: android, ios, windows, linux',
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        widget.onNamed(
                          _hwidController.text.trim(),
                          _nameController.text.trim(),
                          _platformController.text.trim().isNotEmpty
                              ? _platformController.text.trim()
                              : null,
                        );
                      }
                    },
                    child: const Text('التالي'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinkConfirmationScreen extends StatelessWidget {
  final String deviceHwid;
  final String deviceName;
  final String? platform;
  final VoidCallback onSubmit;
  final VoidCallback onBack;
  const _LinkConfirmationScreen({
    required this.deviceHwid,
    required this.deviceName,
    this.platform,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 64),
                const SizedBox(height: 16),
                Text(
                  'تأكيد الربط',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                _InfoRow(label: 'معرف الجهاز', value: deviceHwid),
                _InfoRow(label: 'اسم الجهاز', value: deviceName),
                if (platform != null) _InfoRow(label: 'المنصة', value: platform!),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onBack,
                        child: const Text('رجوع'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: onSubmit,
                        child: const Text('ربط الجهاز'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessScreen extends StatelessWidget {
  final Map<String, dynamic> device;
  final VoidCallback onDone;
  const _SuccessScreen({required this.device, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 64),
                const SizedBox(height: 16),
                Text(
                  'تم ربط الجهاز بنجاح',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                _InfoRow(label: 'معرف الجهاز', value: device['device_hwid'] ?? '—'),
                _InfoRow(label: 'اسم الجهاز', value: device['device_name'] ?? '—'),
                if (device['platform'] != null)
                  _InfoRow(label: 'المنصة', value: device['platform']),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onDone,
                  child: const Text('تم'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorScreen({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 64),
                const SizedBox(height: 16),
                Text(
                  'حدث خطأ',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}