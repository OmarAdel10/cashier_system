// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'l10n/translations.dart';
import 'models.dart';
import 'pages/home_page.dart';
import 'pages/pricing_page.dart';
import 'pages/features_page.dart';

/// Main entry point for the Daftari POS Jaspr landing page.
void main() {
  runApp(const LandingApp());
}

/// Root application component with language state and simple hash routing.
class LandingApp extends StatelessComponent {
  const LandingApp({super.key});

  @override
  Component build(BuildContext context) {
    // For static rendering, we'll use a simple single-page approach
    // The actual routing will be handled client-side via the web entrypoint
    return const HomePage(
      currentLanguage: 'en',
      onLanguageChange: _noop,
      onNavigate: _noop,
    );
  }
}

/// No-op callback for static rendering
void _noop(String _) {}

/// Global styles component that injects CSS and meta tags.
class _GlobalStyles extends StatelessComponent {
  final bool isDark;
  final bool isRtl;
  final String language;

  const _GlobalStyles({
    required this.isDark,
    required this.isRtl,
    required this.language,
  });

  @override
  Component build(BuildContext context) {
    final isRtl = language == 'ar';

    return Component.fragment([
      // CSS Styles
      Component.element(
        tag: 'style',
        children: [text(_generateCss(isDark, isRtl))],
      ),

      // Meta tags
      Component.element(tag: 'meta', attributes: {'charset': 'utf-8'}),
      Component.element(
        tag: 'meta',
        attributes: {
          'name': 'viewport',
          'content': 'width=device-width, initial-scale=1',
        },
      ),
      Component.element(
        tag: 'meta',
        attributes: {'name': 'theme-color', 'content': '#007ACC'},
      ),
      Component.element(
        tag: 'meta',
        attributes: {
          'name': 'description',
          'content': Translations.t('app.tagline', language),
        },
      ),
      Component.element(
        tag: 'meta',
        attributes: {
          'property': 'og:title',
          'content': Translations.t('app.name', language),
        },
      ),
      Component.element(
        tag: 'meta',
        attributes: {
          'property': 'og:description',
          'content': Translations.t('app.tagline', language),
        },
      ),
      Component.element(
        tag: 'meta',
        attributes: {'property': 'og:type', 'content': 'website'},
      ),
      Component.element(
        tag: 'meta',
        attributes: {'name': 'twitter:card', 'content': 'summary_large_image'},
      ),
      Component.element(
        tag: 'meta',
        attributes: {
          'name': 'twitter:title',
          'content': Translations.t('app.name', language),
        },
      ),
      Component.element(
        tag: 'meta',
        attributes: {
          'name': 'twitter:description',
          'content': Translations.t('app.tagline', language),
        },
      ),

      // Favicon
      Component.element(
        tag: 'link',
        attributes: {'rel': 'icon', 'href': '/assets/favicons/favicon.ico'},
      ),
      Component.element(
        tag: 'link',
        attributes: {
          'rel': 'icon',
          'type': 'image/svg+xml',
          'href': '/assets/favicons/favicon.svg',
        },
      ),
      Component.element(
        tag: 'link',
        attributes: {
          'rel': 'apple-touch-icon',
          'href': '/assets/favicons/apple-touch-icon.png',
        },
      ),
      Component.element(
        tag: 'link',
        attributes: {'rel': 'manifest', 'href': '/manifest.json'},
      ),
    ]);
  }

  String _generateCss(bool isDark, bool isRtl) {
    final bgColor = isDark ? '#0F172A' : '#F5F0EB';
    final cardBg = isDark ? '#1E293B' : '#FFFDF5';
    final borderColor = isDark ? '#334155' : '#E8E0D8';
    final textColor = isDark ? '#F5F0EB' : '#1E293B';
    final textMuted = isDark ? '#94A3B8' : '#64748B';
    final direction = isRtl ? 'rtl' : 'ltr';

    return '''
      @font-face {
        font-family: 'Cairo';
        src: url('/fonts/Cairo/Cairo[slnt,wght].ttf') format('truetype');
        font-weight: 400 700;
        font-style: normal;
        font-display: swap;
      }

      :root {
        --bg-color: $bgColor;
        --card-bg: $cardBg;
        --border-color: $borderColor;
        --text-color: $textColor;
        --text-muted: $textMuted;
        --primary: #007ACC;
        --success: #10B981;
        --direction: $direction;
      }

      [data-theme="dark"] {
        --bg-color: #0F172A;
        --card-bg: #1E293B;
        --border-color: #334155;
        --text-color: #F5F0EB;
        --text-muted: #94A3B8;
      }

      [dir="rtl"] { --direction: rtl; }

      * { box-sizing: border-box; margin: 0; padding: 0; }

      html { direction: var(--direction); scroll-behavior: smooth; font-size: 16px; }

      body {
        font-family: 'Cairo', system-ui, sans-serif;
        background: var(--bg-color);
        color: var(--text-color);
        line-height: 1.6;
        -webkit-font-smoothing: antialiased;
        -moz-osx-font-smoothing: grayscale;
        min-height: 100vh;
      }

      img { max-width: 100%; height: auto; display: block; }

      a { color: var(--primary); text-decoration: none; transition: color 150ms ease; }
      a:hover { color: #0066aa; }

      button { font-family: inherit; cursor: pointer; border: none; background: none; }

      ::selection { background: #007ACC33; color: var(--text-color); }

      :focus-visible { outline: 2px solid var(--primary); outline-offset: 2px; }

      .skip-link {
        position: absolute; top: -100%; left: 16px;
        padding: 8px 16px; background: var(--primary); color: white;
        border-radius: 8px; z-index: 700;
        transition: top 150ms ease;
        font-family: 'Cairo'; font-size: 12px; font-weight: 500;
      }
      .skip-link:focus { top: 16px; }

      .container { width: 100%; max-width: 1280px; margin: 0 auto; padding: 0 16px; }
      .section-py { padding-top: 48px; padding-bottom: 48px; }

      .flex-center { display: flex; align-items: center; justify-content: center; }
      .flex-between { display: flex; align-items: center; justify-content: space-between; }
      .flex-col { display: flex; flex-direction: column; }
      .flex-col-center { display: flex; flex-direction: column; align-items: center; text-align: center; }

      .grid-responsive {
        display: grid; gap: 24px; grid-template-columns: 1fr;
      }
      @media (min-width: 768px) { .grid-responsive { grid-template-columns: repeat(2, 1fr); } }
      @media (min-width: 1024px) { .grid-responsive { grid-template-columns: repeat(3, 1fr); } }

      .card {
        background: var(--card-bg); border: 1px solid var(--border-color);
        border-radius: 12px; padding: 24px;
        transition: box-shadow 200ms ease, transform 200ms ease;
      }
      .card:hover { box-shadow: 0 10px 15px -3px rgb(0 0 0 / 0.1); transform: translateY(-2px); }

      .btn-primary {
        display: inline-flex; align-items: center; justify-content: center; gap: 8px;
        padding: 16px 32px; background: var(--primary); color: white;
        font-family: 'Cairo'; font-size: 14px; font-weight: 600;
        border: none; border-radius: 12px; cursor: pointer;
        transition: background 150ms ease, transform 150ms ease; text-decoration: none;
      }
      .btn-primary:hover { background: #0066aa; transform: translateY(-1px); }

      .btn-secondary {
        display: inline-flex; align-items: center; justify-content: center; gap: 8px;
        padding: 16px 32px; background: transparent; color: var(--primary);
        font-family: 'Cairo'; font-size: 14px; font-weight: 600;
        border: 2px solid var(--primary); border-radius: 12px; cursor: pointer;
        transition: background 150ms ease, color 150ms ease; text-decoration: none;
      }
      .btn-secondary:hover { background: var(--primary); color: white; }

      .badge {
        display: inline-flex; align-items: center; padding: 4px 8px;
        font-family: 'Cairo'; font-size: 11px; font-weight: 600;
        border-radius: 9999px;
      }
      .badge-primary { background: #007ACC1a; color: var(--primary); }
      .badge-success { background: #10B9811a; color: var(--success); }
      .badge-warning { background: #F59E0B1a; color: #F59E0B; }

      .heading-1 { font-family: 'Cairo'; font-size: 32px; font-weight: 700; line-height: 1.2; color: var(--text-color); }
      .heading-2 { font-family: 'Cairo'; font-size: 24px; font-weight: 700; line-height: 1.3; color: var(--text-color); }
      .heading-3 { font-family: 'Cairo'; font-size: 20px; font-weight: 600; line-height: 1.4; color: var(--text-color); }
      .body { font-family: 'Cairo'; font-size: 14px; font-weight: 400; line-height: 1.6; color: var(--text-color); }
      .body-muted { font-family: 'Cairo'; font-size: 14px; font-weight: 400; line-height: 1.6; color: var(--text-muted); }
      .body-large { font-family: 'Cairo'; font-size: 16px; font-weight: 400; line-height: 1.6; color: var(--text-color); }
      .body-small { font-family: 'Cairo'; font-size: 12px; font-weight: 400; line-height: 1.5; color: var(--text-muted); }
      .caption { font-family: 'Cairo'; font-size: 11px; font-weight: 500; line-height: 1.5; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.05em; }

      .animate-slide-up { animation: slideUp 300ms ease forwards; }
      @keyframes slideUp { from { opacity: 0; transform: translateY(20px); } to { opacity: 1; transform: translateY(0); } }
      .stagger-1 { animation-delay: 100ms; } .stagger-2 { animation-delay: 200ms; }
      .stagger-3 { animation-delay: 300ms; } .stagger-4 { animation-delay: 400ms; }
      .stagger-5 { animation-delay: 500ms; } .stagger-6 { animation-delay: 600ms; }
    ''';
  }
}
