// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/backend/workers/api_client.dart';
import 'login/admin_auth_bloc.dart';
import 'dashboard/dashboard_bloc.dart';
import 'overview/overview_view.dart';
import 'subscription/subscription_view.dart';
import 'users/users_bloc.dart';
import 'users/users_view.dart';
import 'sales/sales_chart_view.dart';
import 'devices/device_linking_bloc.dart';
import 'devices/device_linking_view.dart';

/// Destinations (Phase 1): Overview real; Sales/Users/Subscription/Settings
/// are filled by T13/T14. Devices added by T40.
enum AdminDestination {
  overview,
  sales,
  users,
  subscription,
  devices,
  settings,
}

/// The responsive dashboard shell (spec §2.2): sidebar 240px fixed
/// (≥1200px) / 72px collapsed (768–1200) / hidden with a bottom nav (<768);
/// direction follows the locale — Arabic → RTL, English → LTR
/// (spec §2.1.3 RTL Rules).
class AdminShell extends StatefulWidget {
  /// The session token provider (the gate passes the login's token); the
  /// sales chart (T13) + users/subscription views consume it.
  final Future<String?> Function()? tokenProvider;

  /// Optional tier provider — fetches the tenant's pricing tier from
  /// /auth/me. Used to gate Users/Subscription destinations to
  /// Professional+ (spec §2.5.1).
  final Future<String?> Function()? tierProvider;

  /// True only for the Firebase (owner) path — gates admin management UI.
  final bool isOwner;
  const AdminShell({
    super.key,
    this.tokenProvider,
    this.tierProvider,
    this.isOwner = false,
  });

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  AdminDestination _selected = AdminDestination.overview;
  String? _tier;

  @override
  void initState() {
    super.initState();
    _loadTier();
  }

  Future<void> _loadTier() async {
    if (widget.tierProvider == null) {
      return;
    }
    try {
      final tier = await widget.tierProvider!();
      if (mounted) setState(() => _tier = tier);
    } catch (_) {
      // ignore tier fetch errors
    }
  }

  @override
  Widget build(BuildContext context) {
    // The DashboardBloc is scoped to the CONTENT pane only: a dashboard
    // update must not rebuild the Scaffold, the nav rail or the bottom nav
    // (T27 — the old wrapper rebuilt the whole shell on every push).
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final showExtendedRail = width >= 1200;
        final showRail = width >= 768;
        // Direction from the locale (plan T12): Arabic → RTL,
        // English → LTR (spec §2.1.3 RTL Rules).
        final isArabic = Localizations.localeOf(context).languageCode == 'ar';
        return Directionality(
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          child: Scaffold(
            appBar: _headerBar(context),
            body: Row(
              children: [
                if (showRail)
                  SizedBox(
                    width: showExtendedRail ? 240 : 72,
                    child: _navRail(context, extended: showExtendedRail),
                  ),
                Expanded(
                  child: BlocListener<DashboardBloc, DashboardState>(
                    // A dashboard request rejected the session → route the
                    // admin back to re-authentication (T28). The dispatch
                    // lives with the failed request's bloc, not a global
                    // interceptor.
                    listenWhen: (_, state) =>
                        state is DashboardError && state.isSessionExpired,
                    listener: (context, _) => context.read<AdminAuthBloc>().add(
                      const SessionExpired(),
                    ),
                    child: BlocBuilder<DashboardBloc, DashboardState>(
                      builder: (context, dashState) =>
                          _content(context, dashState),
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: showRail ? null : _bottomNav(context),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _headerBar(BuildContext context) {
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
    final destinations = _filteredDestinations;
    return NavigationRail(
      extended: extended,
      minExtendedWidth: 240,
      selectedIndex: destinations.indexOf(_selected),
      onDestinationSelected: (i) => setState(() => _selected = destinations[i]),
      destinations: [
        for (final d in destinations)
          NavigationRailDestination(
            icon: Icon(_destIcon(d)),
            selectedIcon: Icon(_destIcon(d), fill: 1),
            label: Text(_destTitle(d)),
          ),
      ],
    );
  }

  Widget _bottomNav(BuildContext context) {
    final destinations = _filteredDestinations;
    return NavigationBar(
      selectedIndex: destinations.indexOf(_selected),
      onDestinationSelected: (i) => setState(() => _selected = destinations[i]),
      destinations: [
        for (final d in destinations)
          NavigationDestination(icon: Icon(_destIcon(d)), label: _destTitle(d)),
      ],
    );
  }

  List<AdminDestination> get _filteredDestinations {
    final isStarter = _tier == 'starter';
    if (!isStarter) return AdminDestination.values;
    // Starter tier: hide Users, Subscription, and Devices
    return AdminDestination.values
        .where(
          (d) =>
              d != AdminDestination.users &&
              d != AdminDestination.subscription &&
              d != AdminDestination.devices,
        )
        .toList();
  }

  Widget _content(BuildContext context, DashboardState state) {
    return switch (_selected) {
      AdminDestination.overview => const OverviewView(),
      AdminDestination.sales => SalesChartView(
        tokenProvider: widget.tokenProvider ?? () async => null,
      ),
      AdminDestination.users => BlocProvider<UsersBloc>(
        create: (_) => UsersBloc(
          api: ApiClient(),
          tokenProvider: widget.tokenProvider ?? () async => null,
        )..add(const UsersRequested()),
        child: UsersView(isOwner: widget.isOwner),
      ),
      AdminDestination.subscription => SubscriptionView(
        tokenProvider: widget.tokenProvider ?? () async => null,
      ),
      AdminDestination.devices => BlocProvider<DeviceLinkingBloc>(
        create: (_) => DeviceLinkingBloc(
          api: ApiClient(),
          ownerTokenProvider: widget.tokenProvider ?? () async => null,
        ),
        child: const DeviceLinkingView(),
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
    AdminDestination.devices => 'الأجهزة',
    AdminDestination.settings => 'الإعدادات',
  };

  IconData _destIcon(AdminDestination d) => switch (d) {
    AdminDestination.overview => Icons.dashboard_outlined,
    AdminDestination.sales => Icons.receipt_long_outlined,
    AdminDestination.users => Icons.people_outline,
    AdminDestination.subscription => Icons.workspace_premium_outlined,
    AdminDestination.devices => Icons.devices_outlined,
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
