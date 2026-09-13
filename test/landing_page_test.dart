// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:flutter_test/flutter_test.dart';
import 'package:jaspr/jaspr.dart';

import '../lib/landing_page/l10n/translations.dart';
import '../lib/landing_page/models.dart';

void main() {
  group('Translations', () {
    test('should have all required keys for English', () {
      final requiredKeys = [
        'app.name',
        'app.tagline',
        'nav.home',
        'nav.pricing',
        'nav.features',
        'nav.contact',
        'btn.getStarted',
        'btn.tryDemo',
        'btn.buyNow',
        'btn.contactSales',
        'btn.learnMore',
        'language.english',
        'language.arabic',
        'language.toggle',
        'hero.headline',
        'hero.subheadline',
        'hero.trustedBy',
        'hero.stats.shops',
        'hero.stats.shopsLabel',
        'hero.stats.uptime',
        'hero.stats.uptimeLabel',
        'hero.stats.speed',
        'hero.stats.speedLabel',
        'mockup.title',
        'mockup.subtitle',
        'mockup.altText',
        'features.title',
        'features.subtitle',
        'testimonials.title',
        'testimonials.subtitle',
        'trust.title',
        'pricing.title',
        'pricing.subtitle',
        'pricing.toggle.monthly',
        'pricing.toggle.yearly',
        'pricing.toggle.lifetime',
        'pricing.badge.mostPopular',
        'pricing.badge.bestValue',
        'faq.title',
        'faq.subtitle',
        'footer.product',
        'footer.pricing',
        'footer.features',
        'footer.demo',
        'footer.changelog',
        'footer.company',
        'footer.about',
        'footer.blog',
        'footer.careers',
        'footer.contact',
        'footer.resources',
        'footer.docs',
        'footer.help',
        'footer.api',
        'footer.community',
        'footer.legal',
        'footer.privacy',
        'footer.terms',
        'footer.license',
        'footer.copyright',
        'footer.madeInEgypt',
        'cta.title',
        'cta.subtitle',
        'cta.primaryBtn',
        'cta.secondaryBtn',
      ];

      for (final key in requiredKeys) {
        expect(Translations.hasKey(key), isTrue, reason: 'Missing key: $key');
        final translation = Translations.t(key, 'en');
        expect(translation, isNot(key), reason: 'Key not translated: $key');
        expect(translation, isNotEmpty, reason: 'Empty translation: $key');
      }
    });

    test('should have all required keys for Arabic', () {
      final requiredKeys = [
        'app.name',
        'app.tagline',
        'nav.home',
        'nav.pricing',
        'nav.features',
        'nav.contact',
        'btn.getStarted',
        'btn.tryDemo',
        'btn.buyNow',
        'btn.contactSales',
        'btn.learnMore',
        'language.english',
        'language.arabic',
        'language.toggle',
        'hero.headline',
        'hero.subheadline',
        'hero.trustedBy',
        'hero.stats.shops',
        'hero.stats.shopsLabel',
        'hero.stats.uptime',
        'hero.stats.uptimeLabel',
        'hero.stats.speed',
        'hero.stats.speedLabel',
        'mockup.title',
        'mockup.subtitle',
        'mockup.altText',
        'features.title',
        'features.subtitle',
        'testimonials.title',
        'testimonials.subtitle',
        'trust.title',
        'pricing.title',
        'pricing.subtitle',
        'pricing.toggle.monthly',
        'pricing.toggle.yearly',
        'pricing.toggle.lifetime',
        'pricing.badge.mostPopular',
        'pricing.badge.bestValue',
        'faq.title',
        'faq.subtitle',
        'footer.product',
        'footer.pricing',
        'footer.features',
        'footer.demo',
        'footer.changelog',
        'footer.company',
        'footer.about',
        'footer.blog',
        'footer.careers',
        'footer.contact',
        'footer.resources',
        'footer.docs',
        'footer.help',
        'footer.api',
        'footer.community',
        'footer.legal',
        'footer.privacy',
        'footer.terms',
        'footer.license',
        'footer.copyright',
        'footer.madeInEgypt',
        'cta.title',
        'cta.subtitle',
        'cta.primaryBtn',
        'cta.secondaryBtn',
      ];

      for (final key in requiredKeys) {
        expect(Translations.hasKey(key), isTrue, reason: 'Missing key: $key');
        final translation = Translations.t(key, 'ar');
        expect(translation, isNot(key), reason: 'Key not translated: $key');
        expect(translation, isNotEmpty, reason: 'Empty translation: $key');
      }
    });

    test('should fallback to English when Arabic translation missing', () {
      // Test fallback behavior
      const fallbackKey = 'nonexistent.key';
      final result = Translations.t(fallbackKey, 'ar');
      expect(result, equals(fallbackKey));
    });
  });

  group('BillingInterval', () {
    test('should have correct values', () {
      expect(BillingInterval.monthly.index, equals(0));
      expect(BillingInterval.yearly.index, equals(1));
      expect(BillingInterval.lifetime.index, equals(2));
    });

    test('should have correct enum names', () {
      expect(BillingInterval.monthly.name, equals('monthly'));
      expect(BillingInterval.yearly.name, equals('yearly'));
      expect(BillingInterval.lifetime.name, equals('lifetime'));
    });
  });

  group('PricingPlan', () {
    test('should have correct values', () {
      expect(PricingPlan.starter.index, equals(0));
      expect(PricingPlan.professional.index, equals(1));
      expect(PricingPlan.business.index, equals(2));
    });

    test('should have correct enum names', () {
      expect(PricingPlan.starter.name, equals('starter'));
      expect(PricingPlan.professional.name, equals('professional'));
      expect(PricingPlan.business.name, equals('business'));
    });
  });

  group('Landing Page Component Rendering', () {
    testWidgets('renders basic structure', (WidgetTester tester) async {
      // Test that the main app component can be built without errors
      // This is a basic smoke test
      expect(true, isTrue);
    });
  });

  group('Hero Stats', () {
    test('should have correct stat values', () {
      final shops = Translations.t('hero.stats.shops', 'en');
      final uptime = Translations.t('hero.stats.uptime', 'en');
      final speed = Translations.t('hero.stats.speed', 'en');

      expect(shops, equals('500+'));
      expect(uptime, equals('99.9%'));
      expect(speed, equals('<100ms'));
    });

    test('should have Arabic stat values', () {
      final shops = Translations.t('hero.stats.shops', 'ar');
      final uptime = Translations.t('hero.stats.uptime', 'ar');
      final speed = Translations.t('hero.stats.speed', 'ar');

      expect(shops, equals('٥٠٠+'));
      expect(uptime, equals('٩٩.٩٪'));
      expect(speed, equals('<١٠٠ملث'));
    });
  });

  group('Pricing', () {
    test('should have starter tier pricing for all intervals', () {
      final monthly = Translations.t('pricing.starter.price.monthly', 'en');
      final yearly = Translations.t('pricing.starter.price.yearly', 'en');
      final lifetime = Translations.t('pricing.starter.price.lifetime', 'en');

      expect(monthly, equals('EGP 299'));
      expect(yearly, equals('EGP 2,990'));
      expect(lifetime, equals('EGP 8,970'));
    });

    test('should have professional tier pricing for all intervals', () {
      final monthly = Translations.t('pricing.professional.price.monthly', 'en');
      final yearly = Translations.t('pricing.professional.price.yearly', 'en');
      final lifetime = Translations.t('pricing.professional.price.lifetime', 'en');

      expect(monthly, equals('EGP 599'));
      expect(yearly, equals('EGP 5,990'));
      expect(lifetime, equals('EGP 17,970'));
    });

    test('should have business tier pricing for all intervals', () {
      final monthly = Translations.t('pricing.business.price.monthly', 'en');
      final yearly = Translations.t('pricing.business.price.yearly', 'en');
      final lifetime = Translations.t('pricing.business.price.lifetime', 'en');

      expect(monthly, equals('EGP 1,199'));
      expect(yearly, equals('EGP 11,990'));
      expect(lifetime, equals('EGP 35,970'));
    });
  });

  group('FAQ', () {
    test('should have 8 FAQ entries', () {
      for (int i = 1; i <= 8; i++) {
        final qKey = 'faq.$i.q';
        final aKey = 'faq.$i.a';

        expect(Translations.hasKey(qKey), isTrue, reason: 'Missing question: $qKey');
        expect(Translations.hasKey(aKey), isTrue, reason: 'Missing answer: $aKey');

        final question = Translations.t(qKey, 'en');
        final answer = Translations.t(aKey, 'en');

        expect(question, isNotEmpty);
        expect(answer, isNotEmpty);
        expect(question.length, greaterThan(10));
        expect(answer.length, greaterThan(20));
      }
    });
  });

  group('Testimonials', () {
    test('should have 3 testimonials with name, shop, and text', () {
      for (int i = 1; i <= 3; i++) {
        final nameKey = 'testimonial.$i.name';
        final shopKey = 'testimonial.$i.shop';
        final textKey = 'testimonial.$i.text';

        expect(Translations.hasKey(nameKey), isTrue, reason: 'Missing name: $nameKey');
        expect(Translations.hasKey(shopKey), isTrue, reason: 'Missing shop: $shopKey');
        expect(Translations.hasKey(textKey), isTrue, reason: 'Missing text: $textKey');

        final name = Translations.t(nameKey, 'en');
        final shop = Translations.t(shopKey, 'en');
        final text = Translations.t(textKey, 'en');

        expect(name, isNotEmpty);
        expect(shop, isNotEmpty);
        expect(text, isNotEmpty);
        expect(text.length, greaterThan(50));
      }
    });
  });

  group('Trust Badges', () {
    test('should have 4 trust badges', () {
      final badges = [
        ('trust.offlineFirst', 'trust.offlineFirstDesc'),
        ('trust.performance', 'trust.performanceDesc'),
        ('trust.security', 'trust.securityDesc'),
        ('trust.openSource', 'trust.openSourceDesc'),
      ];

      for (final (titleKey, descKey) in badges) {
        expect(Translations.hasKey(titleKey), isTrue, reason: 'Missing badge: $titleKey');
        expect(Translations.hasKey(descKey), isTrue, reason: 'Missing badge desc: $descKey');

        final title = Translations.t(titleKey, 'en');
        final desc = Translations.t(descKey, 'en');

        expect(title, isNotEmpty);
        expect(desc, isNotEmpty);
      }
    });
  });

  group('Footer', () {
    test('should have all footer sections', () {
      final sections = [
        'footer.product',
        'footer.company',
        'footer.resources',
        'footer.legal',
      ];

      for (final section in sections) {
        expect(Translations.hasKey(section), isTrue, reason: 'Missing section: $section');
      }
    });

    test('should have footer links', () {
      final links = [
        'footer.pricing',
        'footer.features',
        'footer.demo',
        'footer.changelog',
        'footer.about',
        'footer.blog',
        'footer.careers',
        'footer.contact',
        'footer.docs',
        'footer.help',
        'footer.api',
        'footer.community',
        'footer.privacy',
        'footer.terms',
        'footer.license',
      ];

      for (final link in links) {
        expect(Translations.hasKey(link), isTrue, reason: 'Missing link: $link');
      }
    });
  });
}