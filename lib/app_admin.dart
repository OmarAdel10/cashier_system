// Copyright (c) 2026 Daftari POS. All rights reserved.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/backend/auth/firebase_auth_service.dart';
import 'core/backend/workers/api_client.dart';
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
/// Firebase app throws [core/no-app]).
class AdminApp extends StatelessWidget {
  final AdminAuthBloc? bloc;
  const AdminApp({super.key, this.bloc});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Daftari Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: bloc != null
          ? BlocProvider<AdminAuthBloc>.value(
              value: bloc!,
              // The gate: authenticated (either path) → the dashboard shell
              // with its own data bloc scoped to the session token.
              child: BlocBuilder<AdminAuthBloc, AdminAuthState>(
                builder: (context, state) => switch (state) {
                  AuthAuthenticated(:final token, :final isOwner) =>
                    BlocProvider<DashboardBloc>(
                      create: (_) => DashboardBloc(
                        api: ApiClient(),
                        tokenProvider: () async => token,
                      )..add(const OverviewRequested()),
                      child: AdminShell(
                        tokenProvider: () async => token,
                        isOwner: isOwner,
                      ),
                    ),
                  _ => const LoginScreen(),
                },
              ),
            )
          : BlocProvider<AdminAuthBloc>(
              create: (_) => AdminAuthBloc(
                firebase: FirebaseAuthService(),
                admin: AdminAuthService(),
              )..add(const CheckSessionRequested()),
              child: BlocBuilder<AdminAuthBloc, AdminAuthState>(
                builder: (context, state) => switch (state) {
                  AuthAuthenticated(:final token, :final isOwner) =>
                    BlocProvider<DashboardBloc>(
                      create: (_) => DashboardBloc(
                        api: ApiClient(),
                        tokenProvider: () async => token,
                      )..add(const OverviewRequested()),
                      child: AdminShell(
                        tokenProvider: () async => token,
                        isOwner: isOwner,
                      ),
                    ),
                  _ => const LoginScreen(),
                },
              ),
            ),
    );
  }
}
