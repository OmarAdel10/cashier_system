// Copyright (c) 2024 Daftari POS. All rights reserved.

// Jaspr static-site entrypoint (see `jaspr.entrypoint` + `jaspr.output` in
// pubspec.yaml). Renders LandingApp to build/jaspr for Cloudflare Pages.
// Server-side sibling: lib/main.server.dart (Flutter POS shell, separate app).

import 'package:jaspr/jaspr.dart';
import 'package:cashier_system/landing_page/main.dart' as landing_page;

/// Web entrypoint for Jaspr static rendering.
void main() {
  runApp(const landing_page.LandingApp());
}
