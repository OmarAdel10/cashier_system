// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:jaspr/server.dart';
import 'landing_page/main.dart' as landing_page;

/// Server entrypoint for `dart run jaspr build` static pre-render.
/// Wires LandingApp (lib/landing_page/main.dart) into Jaspr SSR; the client
/// hydrates from web/main.dart. Flutter POS boots separately via lib/main.dart.
void main(List<String> args) {
  Jaspr.initializeApp();
  runApp(const landing_page.LandingApp());
}
