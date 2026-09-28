// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter/material.dart';

import '../../../core/backend/workers/api_client.dart';

/// The Subscription screen (spec §2.5.2: Professional = view + upgrade;
/// the Paymob checkout wiring is a followup — the upgrade button shows an
/// info dialog for now).
class SubscriptionView extends StatefulWidget {
  final Future<String?> Function() tokenProvider;
  final ApiClient? api;
  const SubscriptionView({super.key, required this.tokenProvider, this.api});

  @override
  State<SubscriptionView> createState() => _SubscriptionViewState();
}

class _SubscriptionViewState extends State<SubscriptionView> {
  String? _tier;
  int? _activeSessions;
  bool _loading = true;
  String _errorAr = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = widget.api ?? ApiClient();
    final token = await widget.tokenProvider();
    if (token == null) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorAr = 'انتهت الجلسة. سجل الدخول من جديد.';
        });
      }
      return;
    }
    try {
      final me = await api.get('/auth/me', idToken: token);
      final overview = await api.get('/admin/overview', idToken: token);
      final meBody = me.fold((_) => null, (b) => b);
      final ovBody = overview.fold((_) => null, (b) => b);
      if (mounted) {
        setState(() {
          _tier = meBody?['data']?['profile']?['tier'] as String? ?? 'starter';
          _activeSessions =
              (meBody != null && ovBody?['data']?['active_sessions'] is num)
              ? (ovBody!['data']!['active_sessions'] as num).toInt()
              : 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorAr = 'فشل تحميل بيانات الاشتراك.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_errorAr.isNotEmpty) {
      return Center(child: Text(_errorAr, textAlign: TextAlign.center));
    }
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _InfoCard(
          title: 'الباقة الحالية',
          value: _tierLabel(_tier ?? 'starter'),
        ),
        const SizedBox(height: 16),
        _InfoCard(title: 'الجلسات النشطة', value: '$_activeSessions'),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('ترقية الباقة'),
              content: const Text(
                'الدفع عبر Paymob يُفعّل في إصدار لاحق — تواصل معنا للترقية الآن.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('حسنًا'),
                ),
              ],
            ),
          ),
          icon: const Icon(Icons.workspace_premium_outlined),
          label: const Text('ترقية الباقة'),
        ),
      ],
    );
  }

  String _tierLabel(String tier) => switch (tier) {
    'business' => 'الأعمال (Business)',
    'pro' => 'المحترف (Professional)',
    _ => 'المبتدئ (Starter)',
  };
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String value;
  const _InfoCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}
