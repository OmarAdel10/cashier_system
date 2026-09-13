// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:jaspr/server.dart';
import 'landing_page/main.dart' as landing_page;

/// Server entrypoint for Jaspr (required for static builds).
void main(List<String> args) {
  Jaspr.initializeApp();
  runApp(const landing_page.LandingApp());
}
