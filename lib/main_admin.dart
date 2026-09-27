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
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      // Public-by-design web config (identifies the project; protection =
      // authorized domains + server-side token checks).
      apiKey: 'AIzaSyBGjEpwrZEuLtFTJC27ZXCELrwShoKj8Qk',
      appId: '1:905067437740:web:6ce2c15255db6ea27bc909',
      messagingSenderId: '905067437740',
      projectId: 'daftari-pos',
      authDomain: 'daftari-pos.firebaseapp.com',
    ),
  );
  runApp(const AdminApp());
}
