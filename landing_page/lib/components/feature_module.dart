// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import '../l10n/translations.dart';

/// Feature module card component.
class FeatureModule extends StatelessComponent {
  final String title;
  final String description;
  final List<String> features;
  final String icon;
  final String currentLanguage;
  final int index;

  const FeatureModule({
    super.key,
    required this.title,
    required this.description,
    required this.features,
    required this.icon,
    required this.currentLanguage,
    required this.index,
  });

  @override
  Component build(BuildContext context) {
    final staggerClass = 'stagger-${(index % 6) + 1}';

    return article(
      classes: 'feature-card card animate-slide-up $staggerClass',
      [
        div(classes: 'feature-icon', [text(icon)]),
        h3(classes: 'feature-title heading-3', [text(title)]),
        p(classes: 'feature-description body-muted', [text(description)]),
        ul(classes: 'feature-list', [
          for (final feature in features)
            li(classes: 'feature-item', [
              span(
                classes: 'feature-check',
                attributes: {'aria-hidden': 'true'},
                [text('✓')],
              ),
              span(classes: 'feature-text body-small', [text(feature)]),
            ]),
        ]),
      ],
    );
  }
}

/// Features section component.
class FeaturesSection extends StatelessComponent {
  final String currentLanguage;

  const FeaturesSection({super.key, required this.currentLanguage});

  @override
  Component build(BuildContext context) {
    return section(
      classes: 'features-section',
      attributes: {'aria-labelledby': 'features-title'},
      [
        div(classes: 'container', [
          header(classes: 'section-header flex-col-center', [
            span(classes: 'badge badge-primary', [
              text(Translations.t('features.title', currentLanguage)),
            ]),
            h2(id: 'features-title', classes: 'heading-1', [
              text(Translations.t('features.subtitle', currentLanguage)),
            ]),
          ]),

          div(classes: 'grid-responsive', [
            FeatureModule(
              title: Translations.t('features.checkout.title', currentLanguage),
              description: Translations.t(
                'features.checkout.desc',
                currentLanguage,
              ),
              features: [
                Translations.t('features.checkout.feature1', currentLanguage),
                Translations.t('features.checkout.feature2', currentLanguage),
                Translations.t('features.checkout.feature3', currentLanguage),
                Translations.t('features.checkout.feature4', currentLanguage),
                Translations.t('features.checkout.feature5', currentLanguage),
              ],
              icon: '⚡',
              currentLanguage: currentLanguage,
              index: 0,
            ),
            FeatureModule(
              title: Translations.t(
                'features.inventory.title',
                currentLanguage,
              ),
              description: Translations.t(
                'features.inventory.desc',
                currentLanguage,
              ),
              features: [
                Translations.t('features.inventory.feature1', currentLanguage),
                Translations.t('features.inventory.feature2', currentLanguage),
                Translations.t('features.inventory.feature3', currentLanguage),
                Translations.t('features.inventory.feature4', currentLanguage),
                Translations.t('features.inventory.feature5', currentLanguage),
              ],
              icon: '📦',
              currentLanguage: currentLanguage,
              index: 1,
            ),
            FeatureModule(
              title: Translations.t('features.settings.title', currentLanguage),
              description: Translations.t(
                'features.settings.desc',
                currentLanguage,
              ),
              features: [
                Translations.t('features.settings.feature1', currentLanguage),
                Translations.t('features.settings.feature2', currentLanguage),
                Translations.t('features.settings.feature3', currentLanguage),
                Translations.t('features.settings.feature4', currentLanguage),
                Translations.t('features.settings.feature5', currentLanguage),
              ],
              icon: '⚙️',
              currentLanguage: currentLanguage,
              index: 2,
            ),
          ]),
        ]),
      ],
    );
  }
}
