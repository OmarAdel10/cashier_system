// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:jaspr/server.dart';
import 'main.dart' as landing;

/// Static pre-render entrypoint for Jaspr (writes to build/jaspr).
void main(List<String> args) {
  Jaspr.initializeApp();
  runApp(const landing.LandingApp());
}
