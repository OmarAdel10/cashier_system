// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import '../l10n/translations.dart';
import '../styles/tokens.dart';

/// Header component with logo, navigation, and language toggle.
class Header extends StatelessComponent {
  final String currentLanguage;
  final String currentPath;
  final Function(String) onLanguageChange;
  final Function(String) onNavigate;

  const Header({
    super.key,
    required this.currentLanguage,
    required this.currentPath,
    required this.onLanguageChange,
    required this.onNavigate,
  });

  @override
  Component build(BuildContext context) {
    final isHome = currentPath == '/';
    final isRtl = currentLanguage == 'ar';
    final isScrolled = !isHome;

    return header(classes: 'header ${isScrolled ? 'scrolled' : ''}', [
      div(classes: 'container header-inner', [
        // Logo
        a(href: '/', classes: 'logo', [
          span(classes: 'logo-icon', [text('دف')]),
          span(classes: 'logo-text', [
            text(Translations.t('app.name', currentLanguage)),
          ]),
        ]),

        // Desktop Navigation
        nav(classes: 'nav-desktop', [
          _NavItem(
            label: Translations.t('nav.home', currentLanguage),
            href: '/',
            isActive: currentPath == '/',
            onTap: () => onNavigate('/'),
          ),
          _NavItem(
            label: Translations.t('nav.features', currentLanguage),
            href: '/features',
            isActive: currentPath == '/features',
            onTap: () => onNavigate('/features'),
          ),
          _NavItem(
            label: Translations.t('nav.pricing', currentLanguage),
            href: '/pricing',
            isActive: currentPath == '/pricing',
            onTap: () => onNavigate('/pricing'),
          ),
        ]),

        // Actions: Language toggle + CTA
        div(classes: 'header-actions', [
          // Language Toggle
          button(
            classes: 'language-toggle',
            attributes: {
              'aria-label': Translations.t('language.toggle', currentLanguage),
              'type': 'button',
            },
            events: {
              'click': (_) =>
                  onLanguageChange(currentLanguage == 'en' ? 'ar' : 'en'),
            },
            [
              span(classes: 'lang-icon', [
                text(currentLanguage == 'en' ? 'ع' : 'En'),
              ]),
              span(classes: 'lang-text', [
                text(currentLanguage == 'en' ? 'AR' : 'EN'),
              ]),
            ],
          ),

          // Get Started Button
          a(href: '/pricing', classes: 'btn-primary header-cta', [
            text(Translations.t('btn.getStarted', currentLanguage)),
          ]),
        ]),
      ]),
    ]);
  }
}

/// Individual navigation item.
class _NavItem extends StatelessComponent {
  final String label;
  final String href;
  final bool isActive;
  final Function() onTap;

  const _NavItem({
    required this.label,
    required this.href,
    required this.isActive,
    required this.onTap,
  });

  @override
  Component build(BuildContext context) {
    return a(
      href: href,
      classes: 'nav-link ${isActive ? 'active' : ''}',
      events: {
        'click': (e) {
          e.preventDefault();
          onTap();
        },
      },
      [text(label)],
    );
  }
}
