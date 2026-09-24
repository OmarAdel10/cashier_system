// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import '../l10n/translations.dart';
import '../components/header.dart';
import '../components/pricing_card.dart';
import '../components/faq.dart';
import '../components/footer.dart';
import '../models.dart';

/// Pricing page with tier cards and billing toggle.
class PricingPage extends StatelessComponent {
  final String currentLanguage;
  final Function(String) onLanguageChange;
  final Function(String) onNavigate;
  final BillingInterval selectedInterval;
  final PricingPlan? selectedPlan;
  final Function(BillingInterval) onIntervalChange;
  final Function(PricingPlan) onPlanSelect;

  const PricingPage({
    super.key,
    required this.currentLanguage,
    required this.onLanguageChange,
    required this.onNavigate,
    required this.selectedInterval,
    required this.selectedPlan,
    required this.onIntervalChange,
    required this.onPlanSelect,
  });

  @override
  Component build(BuildContext context) {
    final lang = currentLanguage;
    final isRtl = lang == 'ar';

    return div(
      classes: 'page pricing-page',
      attributes: {'dir': isRtl ? 'rtl' : 'ltr', 'lang': lang},
      [
        a(href: '#main-content', classes: 'skip-link', [
          text(Translations.t('a11y.skipToContent', currentLanguage)),
        ]),

        Header(
          currentLanguage: lang,
          currentPath: '/pricing',
          onLanguageChange: onLanguageChange,
          onNavigate: onNavigate,
        ),

        div(id: 'main-content', [
          // Hero
          section(classes: 'page-hero', [
            div(classes: 'container flex-col-center', [
              span(classes: 'badge badge-primary', [
                text(Translations.t('pricing.title', lang)),
              ]),
              h1(classes: 'heading-1', [
                text(Translations.t('pricing.subtitle', lang)),
              ]),
            ]),
          ]),

          // Pricing Section
          PricingSection(
            currentLanguage: lang,
            selectedInterval: selectedInterval,
            selectedPlan: selectedPlan,
            onIntervalChange: onIntervalChange,
            onPlanSelect: onPlanSelect,
          ),

          // FAQ Section
          FAQSection(currentLanguage: lang),
        ]),

        Footer(currentLanguage: lang),
      ],
    );
  }
}
