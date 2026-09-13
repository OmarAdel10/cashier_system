// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import '../l10n/translations.dart';

/// FAQ item component using native HTML details/summary.
class FAQItem extends StatelessComponent {
  final String question;
  final String answer;

  const FAQItem({super.key, required this.question, required this.answer});

  @override
  Component build(BuildContext context) {
    return details(classes: 'faq-item', [
      summary(classes: 'faq-question', [
        span(classes: 'faq-q-text heading-3', [text(question)]),
        span(classes: 'faq-icon', [text('+')]),
      ]),
      div(classes: 'faq-answer', [
        p(classes: 'body', [text(answer)]),
      ]),
    ]);
  }
}

/// FAQ section component.
class FAQSection extends StatelessComponent {
  final String currentLanguage;

  const FAQSection({super.key, required this.currentLanguage});

  @override
  Component build(BuildContext context) {
    final lang = currentLanguage;

    final faqs = [
      (Translations.t('faq.1.q', lang), Translations.t('faq.1.a', lang)),
      (Translations.t('faq.2.q', lang), Translations.t('faq.2.a', lang)),
      (Translations.t('faq.3.q', lang), Translations.t('faq.3.a', lang)),
      (Translations.t('faq.4.q', lang), Translations.t('faq.4.a', lang)),
      (Translations.t('faq.5.q', lang), Translations.t('faq.5.a', lang)),
      (Translations.t('faq.6.q', lang), Translations.t('faq.6.a', lang)),
      (Translations.t('faq.7.q', lang), Translations.t('faq.7.a', lang)),
      (Translations.t('faq.8.q', lang), Translations.t('faq.8.a', lang)),
    ];

    return section(
      classes: 'faq-section',
      attributes: {'aria-labelledby': 'faq-title'},
      [
        div(classes: 'container', [
          header(classes: 'section-header flex-col-center', [
            span(classes: 'badge badge-primary', [
              text(Translations.t('faq.title', lang)),
            ]),
            h2(id: 'faq-title', classes: 'heading-1', [
              text(Translations.t('faq.subtitle', lang)),
            ]),
          ]),

          div(classes: 'faq-grid', [
            for (final faq in faqs) FAQItem(question: faq.$1, answer: faq.$2),
          ]),

          // CTA
          div(classes: 'faq-cta flex-col-center', [
            p(classes: 'body-large', [text('لم تجد إجابتك؟')]),
            a(href: '/contact', classes: 'btn-secondary', [
              text(Translations.t('btn.contactSales', lang)),
            ]),
          ]),
        ]),
      ],
    );
  }
}
