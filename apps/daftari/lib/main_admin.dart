// Copyright (c) 2026 Daftari POS. All rights reserved.

/// Entry point for the web admin dashboard (admin flavor).
///
/// Build/run with:
///   flutter run -d chrome -t lib/main_admin.dart \
///     --dart-define=FLAVOR=admin --dart-define=ENV=development
///
/// The dashboard is a pure web client of the api/realtime workers — no
/// Hive/print/window/license machinery (desktop-only boot would throw on
/// web and leave a blank page).
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app_admin.dart';
import 'core/config/env_config.dart';
import 'core/config/flavor_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  EnvConfig.initializeFromEnv();
  FlavorConfig.initializeFromEnv();
  // Public-by-design web config (identifies the project; protection =
  // authorized domains + server-side token checks). Read from EnvConfig —
  // single source of truth (initializeFromEnv ran above, so the late-final
  // reads are safe).
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: EnvConfig.firebaseWebApiKey,
      appId: EnvConfig.firebaseWebAppId,
      messagingSenderId: EnvConfig.firebaseWebMessagingSenderId,
      projectId: EnvConfig.firebaseProjectId,
      authDomain: EnvConfig.firebaseWebAuthDomain,
    ),
  );
  runApp(const AdminApp());
}
