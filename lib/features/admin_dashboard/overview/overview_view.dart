// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../dashboard/dashboard_bloc.dart';
import '../dashboard/models.dart';

/// The Overview screen (spec §2.2): Quick Stats row (4 cards), Devices
/// Online grid, Active Shifts + Warnings panels, Recent Activity feed.
class OverviewView extends StatelessWidget {
  const OverviewView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, state) {
        return switch (state) {
          DashboardLoading() => const Center(
            child: CircularProgressIndicator(),
          ),
          DashboardError(messageAr: final message) => _ErrorPane(
            message: message,
          ),
          DashboardLoaded() => _OverviewBody(state),
        };
      },
    );
  }
}

class _ErrorPane extends StatelessWidget {
  final String message;
  const _ErrorPane({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () =>
                context.read<DashboardBloc>().add(const OverviewRequested()),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  final DashboardLoaded state;
  const _OverviewBody(this.state);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          QuickStatsRow(stats: state.stats),
          const SizedBox(height: 24),
          DevicesOnlineGrid(devices: state.devices),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final sideBySide = constraints.maxWidth >= 900;
              final panels = [
                ActiveShiftsPanel(sessions: state.activeSessions),
                const SizedBox(height: 24),
                WarningsPanel(devices: state.devices),
              ];
              final feed = RecentActivityFeed(events: state.activity);
              if (!sideBySide) {
                return Column(
                  children: [...panels, const SizedBox(height: 24), feed],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      child: Column(children: panels),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: feed),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// The 4 quick-stat cards (spec §2.3.2 stat card: left accent border).
class QuickStatsRow extends StatelessWidget {
  final OverviewStats stats;
  const QuickStatsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final cards = [
      ('المبيعات', '${stats.saleCount}', const Color(0xFF007ACC)),
      ('الإيرادات', _egp(stats.totalPiastres), const Color(0xFF10B981)),
      ('الأجهزة المتصلة', '${stats.devicesOnline}', const Color(0xFF10B981)),
      (
        'تنبيهات',
        '${stats.alerts}',
        stats.alerts > 0 ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // Spec §2.2.2: desktop 4 columns / tablet 2 / mobile 1.
        final columns = constraints.maxWidth >= 1200
            ? 4
            : (constraints.maxWidth >= 768 ? 2 : 1);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.0,
          children: [
            for (final (label, value, color) in cards)
              _StatCard(label, value, color),
          ],
        );
      },
    );
  }

  String _egp(int piastres) => '${(piastres / 100).toStringAsFixed(2)} EGP';
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const _StatCard(this.label, this.value, this.accent);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: BorderDirectional(start: BorderSide(color: accent, width: 4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: Theme.of(context).textTheme.titleLarge),
          ),
        ],
      ),
    );
  }
}

/// The devices grid (spec: min-width 280px cards, status dot).
class DevicesOnlineGrid extends StatelessWidget {
  final List<DeviceCardModel> devices;
  const DevicesOnlineGrid({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return const _EmptyCard(
        'لا توجد أجهزة بعد. اربط جهازًا من تطبيق الكاشير.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 280).floor().clamp(1, 4);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.6,
          children: [for (final d in devices) _DeviceCard(d)],
        );
      },
    );
  }
}

class _DeviceCard extends StatelessWidget {
  final DeviceCardModel device;
  const _DeviceCard(this.device);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final online = device.isOnline(now);
    final statusColor = online
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
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
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  device.deviceName ?? device.deviceHwid,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            online ? 'الكاشير: ${device.activeUsername ?? '—'}' : 'غير متصل',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

/// The Active Shifts panel (view-only — spec §2.5.2 Professional tier).
class ActiveShiftsPanel extends StatelessWidget {
  final List<SessionCardModel> sessions;
  const ActiveShiftsPanel({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'الورديات النشطة',
      child: sessions.isEmpty
          ? const Text(
              'لا توجد ورديات نشطة',
              style: TextStyle(color: Color(0xFF64748B)),
            )
          : Column(
              children: [
                for (final s in sessions)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.point_of_sale_outlined, size: 20),
                    title: Text(s.username),
                    subtitle: Text(s.deviceHwid),
                    trailing: Text(
                      TimeOfDay.fromDateTime(
                        DateTime.fromMillisecondsSinceEpoch(s.startedAt),
                      ).format(context),
                    ),
                  ),
              ],
            ),
    );
  }
}

/// Critical alerts: offline devices (spec §2.5.2: critical only).
class WarningsPanel extends StatelessWidget {
  final List<DeviceCardModel> devices;
  const WarningsPanel({super.key, required this.devices});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final offline = devices.where((d) => !d.isOnline(now)).toList();
    return _PanelCard(
      title: 'تنبيهات حرجة',
      child: offline.isEmpty
          ? const Text(
              'لا توجد تنبيهات',
              style: TextStyle(color: Color(0xFF64748B)),
            )
          : Column(
              children: [
                for (final d in offline)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(
                      Icons.warning_amber_outlined,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                    title: Text(d.deviceName ?? d.deviceHwid),
                    subtitle: const Text('الجهاز غير متصل'),
                  ),
              ],
            ),
    );
  }
}

/// The recent activity feed (last 10, expandable).
class RecentActivityFeed extends StatelessWidget {
  final List<ActivityEventModel> events;
  const RecentActivityFeed({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'النشاط الأخير',
      child: events.isEmpty
          ? const Text(
              'لا يوجد نشاط',
              style: TextStyle(color: Color(0xFF64748B)),
            )
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final e in events)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        e.type == 'sale'
                            ? Icons.shopping_cart_outlined
                            : Icons.login_outlined,
                        size: 20,
                      ),
                      title: Text(e.summary),
                      subtitle: Text(_time(e.at)),
                    ),
                ],
              ),
            ),
    );
  }

  String _time(int at) {
    final dt = DateTime.fromMillisecondsSinceEpoch(at);
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _PanelCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _PanelCard({required this.title, required this.child});

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
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Text(message, textAlign: TextAlign.center)),
    );
  }
}
