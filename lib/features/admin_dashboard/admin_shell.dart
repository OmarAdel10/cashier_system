// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'login/admin_auth_bloc.dart';
import 'dashboard/dashboard_bloc.dart';
import 'overview/overview_view.dart';

/// Destinations (Phase 1): Overview real; Sales/Users/Subscription/Settings
/// are filled by T13/T14.
enum AdminDestination { overview, sales, users, subscription, settings }

/// The responsive dashboard shell (spec §2.2): sidebar 240px fixed
/// (≥1200px) / 72px collapsed (768–1200) / hidden with a bottom nav (<768);
/// direction follows the locale — Arabic → RTL, English → LTR
/// (spec §2.1.3 RTL Rules).
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  AdminDestination _selected = AdminDestination.overview;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardBloc, DashboardState>(
      builder: (context, dashState) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final showExtendedRail = width >= 1200;
            final showRail = width >= 768;
            // Direction from the locale (plan T12): Arabic → RTL,
            // English → LTR (spec §2.1.3 RTL Rules).
            final isArabic =
                Localizations.localeOf(context).languageCode == 'ar';
            return Directionality(
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              child: Scaffold(
                appBar: _headerBar(context, dashState),
                body: Row(
                  children: [
                    if (showRail)
                      SizedBox(
                        width: showExtendedRail ? 240 : 72,
                        child: _navRail(context, extended: showExtendedRail),
                      ),
                    Expanded(child: _content(context, dashState)),
                  ],
                ),
                bottomNavigationBar: showRail ? null : _bottomNav(context),
              ),
            );
          },
        );
      },
    );
  }

  PreferredSizeWidget _headerBar(BuildContext context, DashboardState state) {
    return AppBar(
      toolbarHeight: 64,
      title: Text(
        _destTitle(_selected),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'تحديث',
          onPressed: () =>
              context.read<DashboardBloc>().add(const OverviewRequested()),
        ),
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'تسجيل الخروج',
          onPressed: () =>
              context.read<AdminAuthBloc>().add(const LogoutRequested()),
        ),
      ],
    );
  }

  Widget _navRail(BuildContext context, {required bool extended}) {
    return NavigationRail(
      extended: extended,
      minExtendedWidth: 240,
      selectedIndex: AdminDestination.values.indexOf(_selected),
      onDestinationSelected: (i) =>
          setState(() => _selected = AdminDestination.values[i]),
      destinations: [
        for (final d in AdminDestination.values)
          NavigationRailDestination(
            icon: Icon(_destIcon(d)),
            selectedIcon: Icon(_destIcon(d), fill: 1),
            label: Text(_destTitle(d)),
          ),
      ],
    );
  }

  Widget _bottomNav(BuildContext context) {
    return NavigationBar(
      selectedIndex: AdminDestination.values.indexOf(_selected),
      onDestinationSelected: (i) =>
          setState(() => _selected = AdminDestination.values[i]),
      destinations: [
        for (final d in AdminDestination.values)
          NavigationDestination(icon: Icon(_destIcon(d)), label: _destTitle(d)),
      ],
    );
  }

  Widget _content(BuildContext context, DashboardState state) {
    return switch (_selected) {
      AdminDestination.overview => const OverviewView(),
      AdminDestination.sales => const _PlaceholderScreen(
        'المبيعات — Sales (T13)',
      ),
      AdminDestination.users => const _PlaceholderScreen(
        'المستخدمون — Users (T14)',
      ),
      AdminDestination.subscription => const _PlaceholderScreen(
        'الاشتراك — Subscription (T14)',
      ),
      AdminDestination.settings => const _PlaceholderScreen(
        'الإعدادات — Settings (T14)',
      ),
    };
  }

  String _destTitle(AdminDestination d) => switch (d) {
    AdminDestination.overview => 'نظرة عامة',
    AdminDestination.sales => 'المبيعات',
    AdminDestination.users => 'المستخدمون',
    AdminDestination.subscription => 'الاشتراك',
    AdminDestination.settings => 'الإعدادات',
  };

  IconData _destIcon(AdminDestination d) => switch (d) {
    AdminDestination.overview => Icons.dashboard_outlined,
    AdminDestination.sales => Icons.receipt_long_outlined,
    AdminDestination.users => Icons.people_outline,
    AdminDestination.subscription => Icons.workspace_premium_outlined,
    AdminDestination.settings => Icons.settings_outlined,
  };
}

class _PlaceholderScreen extends StatelessWidget {
  final String label;
  const _PlaceholderScreen(this.label);

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(label));
  }
}
