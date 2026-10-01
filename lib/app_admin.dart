// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/backend/auth/firebase_auth_service.dart';
import 'core/backend/workers/api_client.dart';
import 'core/config/env_config.dart';
import 'core/backend/workers/realtime_client.dart';
import 'core/theme/app_theme.dart';
import 'features/admin_dashboard/admin_shell.dart';
import 'features/admin_dashboard/dashboard/dashboard_bloc.dart';
import 'features/admin_dashboard/login/admin_auth_bloc.dart';
import 'features/admin_dashboard/login/admin_auth_service.dart';
import 'features/admin_dashboard/login/login_screen.dart';

/// The web admin dashboard app (admin flavor) — a pure web client of the
/// api/realtime workers. No Hive/print/window/license machinery.
///
/// [bloc] is the test seam: widget tests inject a bloc built on mocked
/// services (constructing the real FirebaseAuthService outside a booted
/// Firebase app throws [core/no-app]). [adminService]/[firebaseService] are
/// the matching seam for the production path, so the live token providers
/// can be exercised without Firebase.
class AdminApp extends StatelessWidget {
  final AdminAuthBloc? bloc;
  final AdminAuthService? adminService;
  final FirebaseAuthService? firebaseService;
  const AdminApp({
    super.key,
    this.bloc,
    this.adminService,
    this.firebaseService,
  });

  @override
  Widget build(BuildContext context) {
    final injected = bloc;
    return MaterialApp(
      title: 'Daftari Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      supportedLocales: const [Locale('ar'), Locale('en')],
      // An unsupported device locale falls back to English (not the first
      // supported locale, which is Arabic) — the dashboard's neutral default.
      localeResolutionCallback: (locale, supported) {
        if (locale == null) return const Locale('en');
        for (final candidate in supported) {
          if (candidate.languageCode == locale.languageCode) return candidate;
        }
        return const Locale('en');
      },
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: injected != null
          ? BlocProvider<AdminAuthBloc>.value(
              value: injected,
              child: const _AdminAuthGate(),
            )
          : _productionHome(),
    );
  }

  /// The real (no-injected-bloc) gate. The token providers are LIVE closures
  /// over the services: an expired session JWT is refreshed by a resume and
  /// a Firebase ID token is re-read per request — never a string captured at
  /// build time.
  Widget _productionHome() {
    final admin = adminService ?? AdminAuthService();
    final firebase = firebaseService ?? FirebaseAuthService();
    return BlocProvider<AdminAuthBloc>(
      create: (_) =>
          AdminAuthBloc(firebase: firebase, admin: admin)
            ..add(const CheckSessionRequested()),
      child: _AdminAuthGate(
        sessionToken: admin.validToken,
        ownerToken: firebase.currentIdToken,
      ),
    );
  }
}

/// The gate: authenticated (either path) → the dashboard shell with its own
/// data bloc scoped to the session token.
///
/// The optional providers are the live token sources; when absent (the
/// injected-bloc test seam) the already-authenticated state's token is used.
class _AdminAuthGate extends StatelessWidget {
  final Future<String?> Function()? sessionToken;
  final Future<String?> Function()? ownerToken;
  const _AdminAuthGate({this.sessionToken, this.ownerToken});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminAuthBloc, AdminAuthState>(
      builder: (context, state) => switch (state) {
        AuthAuthenticated(:final token, :final isOwner) => _shell(
          isOwner: isOwner,
          tokenProvider: isOwner
              ? (ownerToken ?? () async => token)
              : (sessionToken ?? () async => token),
          tierProvider: isOwner
              ? (ownerToken ?? () async => token)
              : (sessionToken ?? () async => token),
        ),
        _ => const LoginScreen(),
      },
    );
  }

  Widget _shell({
    required bool isOwner,
    required Future<String?> Function() tokenProvider,
    required Future<String?> Function() tierProvider,
  }) {
    return BlocProvider<DashboardBloc>(
      create: (_) => DashboardBloc(
        api: ApiClient(),
        tokenProvider: tokenProvider,
        realtime: RealtimeClient(
          wsUrl: EnvConfig.realtimeWsUrl,
          tokenProvider: tokenProvider,
        ),
      )..add(const OverviewRequested()),
      child: AdminShell(
        tokenProvider: tokenProvider,
        tierProvider: tierProvider,
        isOwner: isOwner,
      ),
    );
  }
}
