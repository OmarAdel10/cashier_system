// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import '../l10n/translations.dart';
import '../components/header.dart';
import '../components/pos_mockup.dart';
import '../components/feature_module.dart';
import '../components/footer.dart';

/// Home page with Hero, POS Mockup, Features, Testimonials, Trust badges, and CTA.
class HomePage extends StatelessComponent {
  final String currentLanguage;
  final Function(String) onLanguageChange;
  final Function(String) onNavigate;

  const HomePage({
    super.key,
    required this.currentLanguage,
    required this.onLanguageChange,
    required this.onNavigate,
  });

  @override
  Component build(BuildContext context) {
    final lang = currentLanguage;
    final isRtl = lang == 'ar';

    // Testimonials data
    final testimonials = [
      {
        'name': Translations.t('testimonial.1.name', lang),
        'shop': Translations.t('testimonial.1.shop', lang),
        'text': Translations.t('testimonial.1.text', lang),
      },
      {
        'name': Translations.t('testimonial.2.name', lang),
        'shop': Translations.t('testimonial.2.shop', lang),
        'text': Translations.t('testimonial.2.text', lang),
      },
      {
        'name': Translations.t('testimonial.3.name', lang),
        'shop': Translations.t('testimonial.3.shop', lang),
        'text': Translations.t('testimonial.3.text', lang),
      },
    ];

    // Trust badges
    final trustBadges = [
      {
        'icon': '🔒',
        'title': Translations.t('trust.offlineFirst', lang),
        'desc': Translations.t('trust.offlineFirstDesc', lang),
      },
      {
        'icon': '⚡',
        'title': Translations.t('trust.performance', lang),
        'desc': Translations.t('trust.performanceDesc', lang),
      },
      {
        'icon': '🛡️',
        'title': Translations.t('trust.security', lang),
        'desc': Translations.t('trust.securityDesc', lang),
      },
      {
        'icon': '📖',
        'title': Translations.t('trust.openSource', lang),
        'desc': Translations.t('trust.openSourceDesc', lang),
      },
    ];

    return div(
      classes: 'page home-page',
      attributes: {'dir': isRtl ? 'rtl' : 'ltr', 'lang': lang},
      [
        // Skip link for accessibility
        a(href: '#main-content', classes: 'skip-link', [
          text('تجاوز إلى المحتوى الرئيسي'),
        ]),

        // Header
        Header(
          currentLanguage: lang,
          currentPath: '/',
          onLanguageChange: onLanguageChange,
          onNavigate: onNavigate,
        ),

        // Main content
        div(id: 'main-content', [
          // Hero Section
          section(
            classes: 'hero-section',
            attributes: {'aria-labelledby': 'hero-title'},
            [
              div(classes: 'container hero-grid', [
                div(classes: 'hero-content animate-slide-up stagger-1', [
                  span(classes: 'badge badge-primary', [
                    text(Translations.t('app.tagline', lang)),
                  ]),
                  h1(id: 'hero-title', classes: 'heading-1', [
                    text(Translations.t('hero.headline', lang)),
                  ]),
                  p(classes: 'hero-subtitle body-large', [
                    text(Translations.t('hero.subheadline', lang)),
                  ]),
                  div(classes: 'hero-buttons', [
                    a(href: '/pricing', classes: 'btn-primary', [
                      text(Translations.t('btn.getStarted', lang)),
                    ]),
                    a(href: '/pricing', classes: 'btn-secondary', [
                      text(Translations.t('btn.tryDemo', lang)),
                    ]),
                  ]),
                  // Trust stats
                  div(classes: 'hero-stats', [
                    _StatItem(
                      value: Translations.t('hero.stats.shops', lang),
                      label: Translations.t('hero.stats.shopsLabel', lang),
                    ),
                    _StatItem(
                      value: Translations.t('hero.stats.uptime', lang),
                      label: Translations.t('hero.stats.uptimeLabel', lang),
                    ),
                    _StatItem(
                      value: Translations.t('hero.stats.speed', lang),
                      label: Translations.t('hero.stats.speedLabel', lang),
                    ),
                  ]),
                  p(classes: 'hero-trusted', [
                    text(Translations.t('hero.trustedBy', lang)),
                  ]),
                ]),

                // Hero visual - placeholder for illustration
                div(classes: 'hero-visual animate-slide-up stagger-2', [
                  div(classes: 'hero-illustration', [
                    div(classes: 'illustration-placeholder', [text('📱')]),
                  ]),
                ]),
              ]),
            ],
          ),

          // POS Mockup Section
          POSMockup(currentLanguage: lang),

          // Features Section
          FeaturesSection(currentLanguage: lang),

          // Testimonials Section
          section(
            classes: 'testimonials-section',
            attributes: {'aria-labelledby': 'testimonials-title'},
            [
              div(classes: 'container', [
                header(classes: 'section-header flex-col-center', [
                  span(classes: 'badge badge-primary', [
                    text(Translations.t('testimonials.title', lang)),
                  ]),
                  h2(id: 'testimonials-title', classes: 'heading-1', [
                    text(Translations.t('testimonials.subtitle', lang)),
                  ]),
                ]),
                div(classes: 'testimonials-grid grid-responsive', [
                  for (int i = 0; i < testimonials.length; i++)
                    _TestimonialCard(
                      name: testimonials[i]['name']!,
                      shop: testimonials[i]['shop']!,
                      testimonialText: testimonials[i]['text']!,
                      index: i,
                    ),
                ]),
              ]),
            ],
          ),

          // Trust Badges Section
          section(
            classes: 'trust-section',
            attributes: {'aria-labelledby': 'trust-title'},
            [
              div(classes: 'container', [
                header(classes: 'section-header flex-col-center', [
                  span(classes: 'badge badge-primary', [
                    text(Translations.t('trust.title', lang)),
                  ]),
                ]),
                div(classes: 'trust-grid grid-4', [
                  for (int i = 0; i < trustBadges.length; i++)
                    _TrustBadge(
                      icon: trustBadges[i]['icon']!,
                      title: trustBadges[i]['title']!,
                      desc: trustBadges[i]['desc']!,
                      index: i,
                    ),
                ]),
              ]),
            ],
          ),

          // CTA Section
          section(classes: 'cta-section', [
            div(classes: 'container flex-col-center', [
              h2(classes: 'heading-1', [
                text(Translations.t('cta.title', lang)),
              ]),
              p(classes: 'body-large', [
                text(Translations.t('cta.subtitle', lang)),
              ]),
              div(classes: 'cta-buttons', [
                a(href: '/pricing', classes: 'btn-primary', [
                  text(Translations.t('cta.primaryBtn', lang)),
                ]),
                a(href: '/pricing', classes: 'btn-secondary', [
                  text(Translations.t('cta.secondaryBtn', lang)),
                ]),
              ]),
            ]),
          ]),
        ]),

        // Footer
        Footer(currentLanguage: lang),
      ],
    );
  }
}

/// Stat item for hero
class _StatItem extends StatelessComponent {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Component build(BuildContext context) {
    return div(classes: 'stat-item', [
      div(classes: 'stat-value heading-1', [text(value)]),
      div(classes: 'stat-label caption', [text(label)]),
    ]);
  }
}

/// Testimonial card
class _TestimonialCard extends StatelessComponent {
  final String name;
  final String shop;
  final String testimonialText;
  final int index;

  const _TestimonialCard({
    required this.name,
    required this.shop,
    required this.testimonialText,
    required this.index,
  });

  @override
  Component build(BuildContext context) {
    final staggerClass = 'stagger-${(index % 6) + 1}';
    return article(
      classes: 'testimonial-card card animate-slide-up $staggerClass',
      [
        div(classes: 'testimonial-text body', [text('"$testimonialText"')]),
        div(classes: 'testimonial-author', [
          div(classes: 'author-avatar', [
            text(name.isNotEmpty ? name.substring(0, 1) : '?'),
          ]),
          div(classes: 'author-info', [
            div(classes: 'author-name body-small', [text(name)]),
            div(classes: 'author-shop caption', [text(shop)]),
          ]),
        ]),
      ],
    );
  }
}

/// Trust badge
class _TrustBadge extends StatelessComponent {
  final String icon;
  final String title;
  final String desc;
  final int index;

  const _TrustBadge({
    required this.icon,
    required this.title,
    required this.desc,
    required this.index,
  });

  @override
  Component build(BuildContext context) {
    final staggerClass = 'stagger-${(index % 6) + 1}';
    return div(classes: 'trust-badge card animate-slide-up $staggerClass', [
      div(classes: 'trust-icon', [text(icon)]),
      h3(classes: 'trust-title heading-3', [text(title)]),
      p(classes: 'trust-desc body-muted', [text(desc)]),
    ]);
  }
}
