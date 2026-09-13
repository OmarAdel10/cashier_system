// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:jaspr/jaspr.dart';

/// Main Jaspr landing page for Daftari POS.
/// Converted from Figma design to Jaspr (Dart) for Cloudflare Pages deployment.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: AppBar(
        title: Text('Daftari POS'),
        centerTitle: true,
      ),
      body: Center(
        child: Text('Daftari POS Landing Page'),
      ),
    );
  }
}

/// Entry point for the Jaspr application.
void main() {
  runApp(const LandingPage());
}