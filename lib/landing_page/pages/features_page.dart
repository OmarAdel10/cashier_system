// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import '../l10n/translations.dart';
import '../components/header.dart';
import '../components/feature_module.dart';
import '../components/footer.dart';

/// Features page with detailed module descriptions.
class FeaturesPage extends StatelessComponent {
  final String currentLanguage;
  final Function(String) onLanguageChange;
  final Function(String) onNavigate;

  const FeaturesPage({
    super.key,
    required this.currentLanguage,
    required this.onLanguageChange,
    required this.onNavigate,
  });

  @override
  Component build(BuildContext context) {
    final lang = currentLanguage;
    final isRtl = lang == 'ar';

    // Detailed feature modules for the features page
    final modules = [
      {
        'icon': '⚡',
        'title': Translations.t('features.checkout.title', lang),
        'description': Translations.t('features.checkout.desc', lang),
        'features': [
          Translations.t('features.checkout.feature1', lang),
          Translations.t('features.checkout.feature2', lang),
          Translations.t('features.checkout.feature3', lang),
          Translations.t('features.checkout.feature4', lang),
          Translations.t('features.checkout.feature5', lang),
        ],
        'details': [
          {
            'title': 'سريع جداً',
            'desc':
                'مسح الباركود في أقل من ١٠٠ مللي ثانية، يعمل بسلاسة حتى على أجهزة قديمة.',
          },
          {
            'title': 'مفاتيح سريعة عالمية',
            'desc':
                'F12 أو مسافة للتأكيد، Alt+1 إلى Alt+10 للمنتجات السريعة، F5 للبحث، Ctrl+D للتركيز على الخصم.',
          },
          {
            'title': 'أوضاع عمل متعددة',
            'desc':
                'يدعم وضع الكاشير، وضع الطاولات للمقاهي/المطاعم، ووضع المحطات للألعاب.',
          },
        ],
      },
      {
        'icon': '📦',
        'title': Translations.t('features.inventory.title', lang),
        'description': Translations.t('features.inventory.desc', lang),
        'features': [
          Translations.t('features.inventory.feature1', lang),
          Translations.t('features.inventory.feature2', lang),
          Translations.t('features.inventory.feature3', lang),
          Translations.t('features.inventory.feature4', lang),
          Translations.t('features.inventory.feature5', lang),
        ],
        'details': [
          {
            'title': 'توليد باركود ذكي',
            'desc':
                'توليد تلقائي لباركود ١٢ رقم مع أول رقم غير صفري، وتحقق من التكرار.',
          },
          {
            'title': 'طباعة ملصقات احترافية',
            'desc':
                'قوالب ملصقات تتضمن اسم المتجر، الباركود، اسم المنتج، السعر، والملاحظات - جاهزة للطابعات الحرارية.',
          },
          {
            'title': 'مزامنة المخزون',
            'desc':
                'تحديث المخزون تلقائياً عند كل عملية بيع، مع تتبع الأصناف التي فشل تحديث مخزونها.',
          },
        ],
      },
      {
        'icon': '⚙️',
        'title': Translations.t('features.settings.title', lang),
        'description': Translations.t('features.settings.desc', lang),
        'features': [
          Translations.t('features.settings.feature1', lang),
          Translations.t('features.settings.feature2', lang),
          Translations.t('features.settings.feature3', lang),
          Translations.t('features.settings.feature4', lang),
          Translations.t('features.settings.feature5', lang),
        ],
        'details': [
          {
            'title': 'تعريب كامل RTL',
            'desc':
                'تبديل فوري بين العربية والإنجليزية مع انعكاس كامل للتخطيط - شريط التنقل، النوافذ، الإيصالات، والطباعة.',
          },
          {
            'title': 'خط Cairo مرفق محلياً',
            'desc':
                'لا اعتماد على Google Fonts - الخط مضمن في التطبيق ويعمل دون إنترنت.',
          },
          {
            'title': 'محرر مفاتيح سريعة',
            'desc':
                'تخصيص كامل لجميع الاختصارات مع كشف التعارضات وحلها تلقائياً.',
          },
        ],
      },
    ];

    return div(
      classes: 'page features-page',
      attributes: {'dir': isRtl ? 'rtl' : 'ltr', 'lang': lang},
      [
        a(href: '#main-content', classes: 'skip-link', [
          text('تجاوز إلى المحتوى الرئيسي'),
        ]),

        Header(
          currentLanguage: lang,
          currentPath: '/features',
          onLanguageChange: onLanguageChange,
          onNavigate: onNavigate,
        ),

        div(id: 'main-content', [
          // Hero
          section(classes: 'page-hero', [
            div(classes: 'container flex-col-center', [
              span(classes: 'badge badge-primary', [
                text(Translations.t('features.title', lang)),
              ]),
              h1(classes: 'heading-1', [
                text(Translations.t('features.subtitle', lang)),
              ]),
            ]),
          ]),

          // Feature Modules - Detailed
          section(
            classes: 'features-detailed-section',
            attributes: {'aria-labelledby': 'features-detailed-title'},
            [
              div(classes: 'container', [
                for (int i = 0; i < modules.length; i++)
                  _FeatureModuleDetail(
                    module: modules[i],
                    index: i,
                    isRtl: isRtl,
                  ),
              ]),
            ],
          ),

          // CTA
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
                a(href: '/demo', classes: 'btn-secondary', [
                  text(Translations.t('cta.secondaryBtn', lang)),
                ]),
              ]),
            ]),
          ]),
        ]),

        Footer(currentLanguage: lang),
      ],
    );
  }
}

/// Detailed feature module for features page.
class _FeatureModuleDetail extends StatelessComponent {
  final Map<String, dynamic> module;
  final int index;
  final bool isRtl;

  const _FeatureModuleDetail({
    required this.module,
    required this.index,
    required this.isRtl,
  });

  @override
  Component build(BuildContext context) {
    final staggerClass = 'stagger-${(index % 6) + 1}';
    final icon = module['icon'] as String;
    final title = module['title'] as String;
    final description = module['description'] as String;
    final features = module['features'] as List<String>;
    final details = module['details'] as List<Map<String, String>>;

    // Alternate layout for visual variety
    final isEven = index % 2 == 0;
    final contentOrder = isRtl ? (isEven ? 1 : 0) : (isEven ? 0 : 1);

    return article(
      classes: 'feature-detail card animate-slide-up $staggerClass',
      [
        div(classes: 'feature-detail-grid', [
          // Visual side
          div(classes: 'feature-visual', [
            div(classes: 'feature-icon-large', [text(icon)]),
          ]),

          // Content side
          div(classes: 'feature-content', [
            span(classes: 'badge badge-primary', [text('وحدة ${index + 1}')]),
            h2(classes: 'heading-2', [text(title)]),
            p(classes: 'body-large', [text(description)]),

            // Feature highlights
            div(classes: 'feature-highlights', [
              for (final feature in features)
                div(classes: 'highlight-item', [
                  span(classes: 'highlight-check', [text('✓')]),
                  span(classes: 'highlight-text body', [text(feature)]),
                ]),
            ]),

            // Detailed features
            div(classes: 'feature-details', [
              for (final detail in details)
                div(classes: 'detail-item', [
                  h4(classes: 'detail-title heading-3', [
                    text(detail['title']!),
                  ]),
                  p(classes: 'detail-desc body-muted', [text(detail['desc']!)]),
                ]),
            ]),
          ]),
        ]),
      ],
    );
  }
}
