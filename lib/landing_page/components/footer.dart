// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import '../l10n/translations.dart';

/// Footer component with links, social, and copyright.
class Footer extends StatelessComponent {
  final String currentLanguage;

  const Footer({super.key, required this.currentLanguage});

  @override
  Component build(BuildContext context) {
    final lang = currentLanguage;

    return footer(classes: 'footer', [
      div(classes: 'container footer-grid', [
        // Product column
        div(classes: 'footer-column', [
          h4(classes: 'footer-heading caption', [
            text(Translations.t('footer.product', lang)),
          ]),
          ul(classes: 'footer-links', [
            _FooterLink(
              href: '/pricing',
              label: Translations.t('footer.pricing', lang),
            ),
            _FooterLink(
              href: '/features',
              label: Translations.t('footer.features', lang),
            ),
            _FooterLink(
              href: '/pricing',
              label: Translations.t('footer.demo', lang),
            ),
            _FooterLink(
              href: '/pricing',
              label: Translations.t('footer.changelog', lang),
            ),
          ]),
        ]),

        // Company column
        div(classes: 'footer-column', [
          h4(classes: 'footer-heading caption', [
            text(Translations.t('footer.company', lang)),
          ]),
          ul(classes: 'footer-links', [
            _FooterLink(href: '/', label: Translations.t('footer.about', lang)),
            _FooterLink(href: '/', label: Translations.t('footer.blog', lang)),
            _FooterLink(
              href: '/',
              label: Translations.t('footer.careers', lang),
            ),
            _FooterLink(
              href: '/pricing',
              label: Translations.t('footer.contact', lang),
            ),
          ]),
        ]),

        // Resources column
        div(classes: 'footer-column', [
          h4(classes: 'footer-heading caption', [
            text(Translations.t('footer.resources', lang)),
          ]),
          ul(classes: 'footer-links', [
            _FooterLink(
              href: '/features',
              label: Translations.t('footer.docs', lang),
            ),
            _FooterLink(
              href: '/features',
              label: Translations.t('footer.help', lang),
            ),
            _FooterLink(
              href: '/features',
              label: Translations.t('footer.api', lang),
            ),
            _FooterLink(
              href: '/features',
              label: Translations.t('footer.community', lang),
            ),
          ]),
        ]),

        // Legal column
        div(classes: 'footer-column', [
          h4(classes: 'footer-heading caption', [
            text(Translations.t('footer.legal', lang)),
          ]),
          ul(classes: 'footer-links', [
            _FooterLink(
              href: '/',
              label: Translations.t('footer.privacy', lang),
            ),
            _FooterLink(href: '/', label: Translations.t('footer.terms', lang)),
            _FooterLink(
              href: '/',
              label: Translations.t('footer.license', lang),
            ),
          ]),
        ]),
      ]),

      // Bottom bar
      div(classes: 'footer-bottom', [
        div(classes: 'footer-copyright', [
          p(classes: 'caption', [
            text(Translations.t('footer.copyright', lang)),
          ]),
        ]),
        div(classes: 'footer-made', [
          p(classes: 'caption', [
            text(Translations.t('footer.madeInEgypt', lang)),
          ]),
        ]),
        div(classes: 'footer-social', [
          a(
            href: 'https://twitter.com/daftaripos',
            classes: 'social-link',
            attributes: {'aria-label': 'Twitter'},
            [text('𝕏')],
          ),
          a(
            href: 'https://github.com/daftaripos',
            classes: 'social-link',
            attributes: {'aria-label': 'GitHub'},
            [text('⌘')],
          ),
          a(
            href: 'https://linkedin.com/company/daftaripos',
            classes: 'social-link',
            attributes: {'aria-label': 'LinkedIn'},
            [text('in')],
          ),
        ]),
      ]),
    ]);
  }
}

/// Individual footer link.
class _FooterLink extends StatelessComponent {
  final String href;
  final String label;

  const _FooterLink({required this.href, required this.label});

  @override
  Component build(BuildContext context) {
    return li([
      a(href: href, classes: 'footer-link', [text(label)]),
    ]);
  }
}
