// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import '../l10n/translations.dart';
import '../models.dart';

/// Pricing card component.
class PricingCard extends StatelessComponent {
  final PricingPlan plan;
  final BillingInterval interval;
  final String currentLanguage;
  final bool isPopular;
  final bool isSelected;
  final Function(PricingPlan) onSelect;

  const PricingCard({
    super.key,
    required this.plan,
    required this.interval,
    required this.currentLanguage,
    this.isPopular = false,
    this.isSelected = false,
    required this.onSelect,
  });

  String get planKey {
    switch (plan) {
      case PricingPlan.starter:
        return 'starter';
      case PricingPlan.professional:
        return 'professional';
      case PricingPlan.business:
        return 'business';
    }
  }

  String get _priceKey {
    switch (interval) {
      case BillingInterval.monthly:
        return 'price.monthly';
      case BillingInterval.yearly:
        return 'price.yearly';
      case BillingInterval.lifetime:
        return 'price.lifetime';
    }
  }

  String get _periodKey {
    switch (interval) {
      case BillingInterval.monthly:
        return 'perMonth';
      case BillingInterval.yearly:
        return 'perYear';
      case BillingInterval.lifetime:
        return 'once';
    }
  }

  @override
  Component build(BuildContext context) {
    final name = Translations.t('pricing.$planKey.name', currentLanguage);
    final price = Translations.t(
      'pricing.$planKey.$_priceKey',
      currentLanguage,
    );
    final period = Translations.t(
      'pricing.$planKey.$_periodKey',
      currentLanguage,
    );
    final desc = Translations.t('pricing.$planKey.desc', currentLanguage);

    final features = [
      Translations.t('pricing.$planKey.feature1', currentLanguage),
      Translations.t('pricing.$planKey.feature2', currentLanguage),
      Translations.t('pricing.$planKey.feature3', currentLanguage),
      Translations.t('pricing.$planKey.feature4', currentLanguage),
      Translations.t('pricing.$planKey.feature5', currentLanguage),
      Translations.t('pricing.$planKey.feature6', currentLanguage),
      Translations.t('pricing.$planKey.feature7', currentLanguage),
      Translations.t('pricing.$planKey.feature8', currentLanguage),
    ];

    final badge = isPopular
        ? Translations.t('pricing.badge.mostPopular', currentLanguage)
        : (plan == PricingPlan.business
              ? Translations.t('pricing.badge.bestValue', currentLanguage)
              : '');

    final btnText = interval == BillingInterval.lifetime
        ? Translations.t('btn.buyNow', currentLanguage)
        : Translations.t('btn.getStarted', currentLanguage);

    return article(
      classes:
          'pricing-card card ${isPopular ? 'popular' : ''} ${isSelected ? 'selected' : ''}',
      [
        if (badge.isNotEmpty)
          div(
            classes:
                'pricing-badge ${isPopular ? 'badge-primary' : 'badge-warning'}',
            [text(badge)],
          ),

        header(classes: 'pricing-header', [
          h3(classes: 'pricing-name heading-3', [text(name)]),
          div(classes: 'pricing-price', [
            span(classes: 'price-amount heading-1', [text(price)]),
            span(classes: 'price-period caption', [text(period)]),
          ]),
          p(classes: 'pricing-desc body-muted', [text(desc)]),
        ]),

        ul(classes: 'pricing-features', [
          for (final feature in features)
            li(classes: 'pricing-feature', [
              span(
                classes: 'feature-check',
                attributes: {'aria-hidden': 'true'},
                [text('✓')],
              ),
              span(classes: 'feature-text body-small', [text(feature)]),
            ]),
        ]),

        button(
          classes: '${isPopular ? 'btn-primary' : 'btn-secondary'} pricing-btn',
          events: {'click': (_) => onSelect(plan)},
          [text(btnText)],
        ),
      ],
    );
  }
}

/// Pricing section with tier cards and billing toggle.
class PricingSection extends StatelessComponent {
  final String currentLanguage;
  final BillingInterval selectedInterval;
  final PricingPlan? selectedPlan;
  final Function(BillingInterval) onIntervalChange;
  final Function(PricingPlan) onPlanSelect;

  const PricingSection({
    super.key,
    required this.currentLanguage,
    required this.selectedInterval,
    required this.selectedPlan,
    required this.onIntervalChange,
    required this.onPlanSelect,
  });

  @override
  Component build(BuildContext context) {
    final lang = currentLanguage;

    return section(
      classes: 'pricing-section',
      attributes: {'aria-labelledby': 'pricing-title'},
      [
        div(classes: 'container', [
          header(classes: 'section-header flex-col-center', [
            span(classes: 'badge badge-primary', [
              text(Translations.t('pricing.title', lang)),
            ]),
            h2(id: 'pricing-title', classes: 'heading-1', [
              text(Translations.t('pricing.subtitle', lang)),
            ]),
          ]),

          // Billing toggle
          div(
            classes: 'billing-toggle',
            attributes: {
              'role': 'tablist',
              'aria-label': Translations.t('a11y.billingPeriod', lang),
            },
            [
              _BillingToggleButton(
                label: Translations.t('pricing.toggle.monthly', lang),
                isActive: selectedInterval == BillingInterval.monthly,
                onTap: () => onIntervalChange(BillingInterval.monthly),
              ),
              _BillingToggleButton(
                label: Translations.t('pricing.toggle.yearly', lang),
                isActive: selectedInterval == BillingInterval.yearly,
                onTap: () => onIntervalChange(BillingInterval.yearly),
              ),
              _BillingToggleButton(
                label: Translations.t('pricing.toggle.lifetime', lang),
                isActive: selectedInterval == BillingInterval.lifetime,
                onTap: () => onIntervalChange(BillingInterval.lifetime),
              ),
            ],
          ),

          // Pricing cards
          div(classes: 'pricing-grid grid-responsive', [
            PricingCard(
              plan: PricingPlan.starter,
              interval: selectedInterval,
              currentLanguage: lang,
              isPopular: false,
              isSelected: selectedPlan == PricingPlan.starter,
              onSelect: onPlanSelect,
            ),
            PricingCard(
              plan: PricingPlan.professional,
              interval: selectedInterval,
              currentLanguage: lang,
              isPopular: true,
              isSelected: selectedPlan == PricingPlan.professional,
              onSelect: onPlanSelect,
            ),
            PricingCard(
              plan: PricingPlan.business,
              interval: selectedInterval,
              currentLanguage: lang,
              isPopular: false,
              isSelected: selectedPlan == PricingPlan.business,
              onSelect: onPlanSelect,
            ),
          ]),
        ]),
      ],
    );
  }
}

/// Individual billing toggle button.
class _BillingToggleButton extends StatelessComponent {
  final String label;
  final bool isActive;
  final Function() onTap;

  const _BillingToggleButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Component build(BuildContext context) {
    return button(
      classes: 'toggle-btn ${isActive ? 'active' : ''}',
      attributes: {'role': 'tab', 'aria-selected': isActive.toString()},
      events: {'click': (_) => onTap()},
      [text(label)],
    );
  }
}
