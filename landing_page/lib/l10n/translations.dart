// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Translation keys for the Daftari POS landing page.
/// Supports Arabic (RTL) and English (LTR) languages.

class Translations {
  static const Map<String, Map<String, String>> _translations = {
    // ===== COMMON =====
    'app.name': {'en': 'Daftari POS', 'ar': 'دفتری POS'},
    'app.tagline': {
      'en': 'Premium POS for Egyptian Stationery Shops',
      'ar': 'نظام نقاط بيع مميز للمكتبات المصرية',
    },
    'nav.home': {'en': 'Home', 'ar': 'الرئيسية'},
    'nav.pricing': {'en': 'Pricing', 'ar': 'الأسعار'},
    'nav.features': {'en': 'Features', 'ar': 'المميزات'},
    'nav.contact': {'en': 'Contact', 'ar': 'تواصل معنا'},
    'btn.getStarted': {'en': 'Get Started Free', 'ar': 'ابدأ مجاناً'},
    'btn.tryDemo': {'en': 'Try Live Demo', 'ar': 'جرب العرض التوضيحي'},
    'btn.buyNow': {'en': 'Buy Now', 'ar': 'اشتري الآن'},
    'btn.contactSales': {'en': 'Contact Sales', 'ar': 'تواصل مع المبيعات'},
    'btn.learnMore': {'en': 'Learn More', 'ar': 'اعرف المزيد'},
    'language.english': {'en': 'English', 'ar': 'الإنجليزية'},
    'language.arabic': {'en': 'العربية', 'ar': 'العربية'},
    'language.toggle': {'en': 'Switch to Arabic', 'ar': 'التبديل للإنجليزية'},

    // ===== HERO SECTION =====
    'hero.headline': {
      'en': 'The Smart POS Your Stationery Shop Deserves',
      'ar': 'نظام نقاط البيع الذكي الذي تستحقه مكتبتك',
    },
    'hero.subheadline': {
      'en':
          'Fast, offline-first, and built for Egyptian retail. Manage sales, inventory, and shifts with zero lag — even on 4GB RAM machines.',
      'ar':
          'سريع، يعمل دون إنترنت، ومصمم للتجزئة المصرية. إدارة المبيعات والمخزون والورديات بلا تأخير — حتى على أجهزة 4 جيجابايت ذاكرة.',
    },
    'hero.trustedBy': {
      'en': 'Trusted by 500+ stationery shops across Egypt',
      'ar': 'يثق به أكثر من ٥٠٠ مكتبة في مصر',
    },
    'hero.stats.shops': {'en': '500+', 'ar': '٥٠٠+'},
    'hero.stats.shopsLabel': {'en': 'Shops', 'ar': 'مكتبة'},
    'hero.stats.uptime': {'en': '99.9%', 'ar': '٩٩.٩٪'},
    'hero.stats.uptimeLabel': {'en': 'Uptime', 'ar': 'زمن التشغيل'},
    'hero.stats.speed': {'en': '<100ms', 'ar': '<١٠٠ملث'},
    'hero.stats.speedLabel': {'en': 'Scan Response', 'ar': 'استجابة المسح'},

    // ===== POS MOCKUP =====
    'mockup.title': {'en': 'See It In Action', 'ar': 'شاهدها في العمل'},
    'mockup.subtitle': {
      'en': 'Real interface screenshot — no mockups, no fluff',
      'ar': 'لقطة حقيقية للواجهة — لا نماذج أولية، لا حشو',
    },
    'mockup.altText': {
      'en':
          'Daftari POS checkout interface showing cart, receipt tower, and cash drawer',
      'ar': 'واجهة دفتری POS تعرض السلة، برج الإيصال، وصندوق النقد',
    },
    'mockup.userName': {'en': 'Ahmed Mohamed', 'ar': 'أحمد محمد'},
    'mockup.userRole': {'en': 'Cashier', 'ar': 'كاشير'},
    'mockup.userInitials': {'en': 'AM', 'ar': 'أح'},
    'mockup.nav.pos': {'en': 'Point of Sale', 'ar': 'نقطة البيع'},
    'mockup.nav.sales': {'en': 'Sales', 'ar': 'المبيعات'},
    'mockup.nav.endShift': {'en': 'End Shift', 'ar': 'إنهاء الوردية'},
    'mockup.search': {
      'en': 'Search product... (F5)',
      'ar': 'البحث عن منتج... (F5)',
    },
    'mockup.online': {'en': '● Online', 'ar': '● متصل'},
    'mockup.cart.title': {'en': 'Current Cart', 'ar': 'السلة الحالية'},
    'mockup.cart.count': {'en': '3 items', 'ar': '٣ أصناف'},
    'mockup.cart.subtotal': {'en': 'Subtotal', 'ar': 'المجموع الفرعي'},
    'mockup.cart.discount': {'en': 'Discount (10%)', 'ar': 'خصم (10%)'},
    'mockup.cart.tax': {'en': 'Tax (14%)', 'ar': 'ضريبة (14%)'},
    'mockup.cart.total': {'en': 'Total', 'ar': 'الإجمالي'},
    'mockup.tiles.title': {'en': 'Quick Access', 'ar': 'وصول سريع'},
    'mockup.tiles.copy': {'en': 'Copy', 'ar': 'نسخ'},
    'mockup.tiles.wrap': {'en': 'Wrap', 'ar': 'تغليف'},
    'mockup.tiles.paper': {'en': 'Paper', 'ar': 'أوراق'},
    'mockup.tiles.pens': {'en': 'Pens', 'ar': 'أقلام'},
    'mockup.tiles.other': {'en': 'Other', 'ar': 'أخرى'},
    'mockup.receipt.title': {'en': 'Receipt', 'ar': 'الإيصال'},
    'mockup.receipt.number': {'en': 'ORD-00042', 'ar': 'ORD-00042'},
    'mockup.chromeUrl': {
      'en': 'app.daftari.pos/checkout',
      'ar': 'app.daftari.pos/checkout',
    },
    'mockup.receipt.items': {'en': 'Items: 3', 'ar': 'الصنف: 3'},
    'mockup.drawer.title': {'en': 'Cash Drawer', 'ar': 'صندوق النقد'},
    'mockup.drawer.due': {'en': 'Amount Due', 'ar': 'المبلغ المستحق'},
    'mockup.drawer.discount': {'en': 'Discount %', 'ar': 'خصم %'},
    'mockup.drawer.confirm': {
      'en': 'Confirm Sale (F12)',
      'ar': 'تأكيد البيع (F12)',
    },
    'mockup.product.pen': {'en': 'Blue Pen', 'ar': 'قلم أزرق'},
    'mockup.product.notebook': {'en': 'Notebook A5', 'ar': 'دفتر A5'},
    'mockup.product.eraser': {'en': 'Eraser', 'ar': 'ممحاة'},

    // ===== FEATURES =====
    'features.moduleLabel': {'en': 'Module', 'ar': 'وحدة'},
    'features.detail.checkout.1.title': {
      'en': 'Blazing Fast',
      'ar': 'سريع جداً',
    },
    'features.detail.checkout.1.desc': {
      'en': 'Barcode scan under 100ms, smooth even on legacy hardware.',
      'ar':
          'مسح الباركود في أقل من ١٠٠ مللي ثانية، يعمل بسلاسة حتى على أجهزة قديمة.',
    },
    'features.detail.checkout.2.title': {
      'en': 'Global Hotkeys',
      'ar': 'مفاتيح سريعة عالمية',
    },
    'features.detail.checkout.2.desc': {
      'en':
          'F12 or Space to confirm, Alt+1..10 for quick products, F5 search, Ctrl+D discount focus.',
      'ar':
          'F12 أو مسافة للتأكيد، Alt+1 إلى Alt+10 للمنتجات السريعة، F5 للبحث، Ctrl+D للتركيز على الخصم.',
    },
    'features.detail.checkout.3.title': {
      'en': 'Multiple Modes',
      'ar': 'أوضاع عمل متعددة',
    },
    'features.detail.checkout.3.desc': {
      'en': 'Cashier mode, table mode for cafes, station mode for gaming.',
      'ar':
          'يدعم وضع الكاشير، وضع الطاولات للمقاهي/المطاعم، ووضع المحطات للألعاب.',
    },
    'features.detail.inventory.1.title': {
      'en': 'Smart Barcode Generation',
      'ar': 'توليد باركود ذكي',
    },
    'features.detail.inventory.1.desc': {
      'en':
          'Auto 12-digit barcode with non-zero first digit and duplicate checks.',
      'ar':
          'توليد تلقائي لباركود ١٢ رقم مع أول رقم غير صفري، وتحقق من التكرار.',
    },
    'features.detail.inventory.2.title': {
      'en': 'Pro Label Printing',
      'ar': 'طباعة ملصقات احترافية',
    },
    'features.detail.inventory.2.desc': {
      'en':
          'Label templates with store name, barcode, product, price, notes — thermal-printer ready.',
      'ar':
          'قوالب ملصقات تتضمن اسم المتجر، الباركود، اسم المنتج، السعر، والملاحظات - جاهزة للطابعات الحرارية.',
    },
    'features.detail.inventory.3.title': {
      'en': 'Stock Sync',
      'ar': 'مزامنة المخزون',
    },
    'features.detail.inventory.3.desc': {
      'en':
          'Stock decrements on every sale, with tracking of items that failed to update.',
      'ar':
          'تحديث المخزون تلقائياً عند كل عملية بيع، مع تتبع الأصناف التي فشل تحديث مخزونها.',
    },
    'features.detail.settings.1.title': {
      'en': 'Full RTL Arabic',
      'ar': 'تعريب كامل RTL',
    },
    'features.detail.settings.1.desc': {
      'en':
          'Instant Arabic/English switch with full layout mirroring — nav rail, dialogs, receipts, print.',
      'ar':
          'تبديل فوري بين العربية والإنجليزية مع انعكاس كامل للتخطيط - شريط التنقل، النوافذ، الإيصالات، والطباعة.',
    },
    'features.detail.settings.2.title': {
      'en': 'Bundled Cairo Font',
      'ar': 'خط Cairo مرفق محلياً',
    },
    'features.detail.settings.2.desc': {
      'en':
          'No Google Fonts dependency — the font ships with the app and works offline.',
      'ar':
          'لا اعتماد على Google Fonts - الخط مضمن في التطبيق ويعمل دون إنترنت.',
    },
    'features.detail.settings.3.title': {
      'en': 'Hotkey Editor',
      'ar': 'محرر مفاتيح سريعة',
    },
    'features.detail.settings.3.desc': {
      'en':
          'Full shortcut customization with conflict detection and auto-resolution.',
      'ar': 'تخصيص كامل لجميع الاختصارات مع كشف التعارضات وحلها تلقائياً.',
    },
    'features.title': {
      'en': 'Built for How You Actually Work',
      'ar': 'مصمم لطريقة عملك الفعلية',
    },
    'features.subtitle': {
      'en': 'Three core modules that replace your entire legacy stack',
      'ar': 'ثلاث وحدات أساسية تحل محل نظامك القديم بالكامل',
    },

    // Module 1: Checkout Hub
    'features.checkout.title': {
      'en': 'Lightning-Fast Checkout Hub',
      'ar': 'مركز دفع فائق السرعة',
    },
    'features.checkout.desc': {
      'en':
          'Barcode scanning in <100ms. Global hotkeys (F12, Space) for instant confirm. Quick-tiles for barcode-less services. Cash drawer with Egyptian denomination buttons. Works 100% offline.',
      'ar':
          'مسح الباركود في أقل من ١٠٠ مللي ثانية. مفاتيح سريعة عامة (F12، مسافة) للتأكيد الفوري. مربعات وصول سريع للخدمات بدون باركود. صندوق نقد بأزرار فئات العملة المصرية. يعمل ١٠٠٪ دون إنترنت.',
    },
    'features.checkout.feature1': {
      'en': 'Sub-100ms barcode scanning',
      'ar': 'مسح باركود بأقل من ١٠٠ مللي ثانية',
    },
    'features.checkout.feature2': {
      'en': 'Global hotkeys (F12, Space, Alt+1-0)',
      'ar': 'مفاتيح سريعة عامة (F12، مسافة، Alt+1-0)',
    },
    'features.checkout.feature3': {
      'en': 'Quick-tiles for services (photocopy, wrapping)',
      'ar': 'مربعات وصول سريع للخدمات (نسخ، تغليف)',
    },
    'features.checkout.feature4': {
      'en': 'Egyptian cash denominations (5-200 EGP)',
      'ar': 'فئات نقدية مصرية (٥-٢٠٠ جنيه)',
    },
    'features.checkout.feature5': {
      'en': '100% offline — no cloud dependency',
      'ar': '١٠٠٪ دون إنترنت — لا اعتماد على السحابة',
    },

    // Module 2: Inventory & Barcode Studio
    'features.inventory.title': {
      'en': 'Inventory & Barcode Studio',
      'ar': 'إدارة المخزون واستوديو الباركود',
    },
    'features.inventory.desc': {
      'en':
          'Two-column layout: normal products + quick-tiles. Auto-generate 12-digit barcodes. Live code128 preview. Export barcode labels as PNG with store name, price, and notes. 10 color-coded quick-tile slots.',
      'ar':
          'تخطيط بعمودين: منتجات عادية + مربعات وصول سريع. توليد باركود ١٢ رقم تلقائي. معاينة code128 مباشرة. تصدير ملصقات الباركود كصورة PNG مع اسم المتجر والسعر والملاحظات. ١٠ خانات وصول سريع ملونة.',
    },
    'features.inventory.feature1': {
      'en': 'Two-column inventory (normal + quick-tiles)',
      'ar': 'مخزون بعمودين (عادي + وصول سريع)',
    },
    'features.inventory.feature2': {
      'en': 'Auto 12-digit barcode generation',
      'ar': 'توليد باركود ١٢ رقم تلقائي',
    },
    'features.inventory.feature3': {
      'en': 'Live code128 preview & PNG export',
      'ar': 'معاينة code128 مباشرة وتصدير PNG',
    },
    'features.inventory.feature4': {
      'en': '10 color-coded quick-tile slots',
      'ar': '١٠ خانات وصول سريع ملونة',
    },
    'features.inventory.feature5': {
      'en': 'Stock sync with receipt creation',
      'ar': 'مزامنة المخزون مع إنشاء الإيصال',
    },

    // Module 3: Settings & Localization
    'features.settings.title': {
      'en': 'Settings & Full RTL Localization',
      'ar': 'الإعدادات والتعريب الكامل RTL',
    },
    'features.settings.desc': {
      'en':
          'Instant Arabic/English toggle with full layout mirroring. Cairo font bundled locally. Dark/light themes. Tax config, printer selection, export paths, keyboard shortcuts editor — all auto-save per interaction.',
      'ar':
          'تبديل فوري عربي/إنجليزي مع انعكاس كامل للتخطيط. خط Cairo مرفق محلياً. ثيمات داكنة/فاتحة. إعداد ضريبة، اختيار طابعة، مسارات تصدير، محرر مفاتيح سريعة — كلها تحفظ تلقائياً مع كل تفاعل.',
    },
    'features.settings.feature1': {
      'en': 'Instant RTL/LTR layout mirroring',
      'ar': 'انعكاس تخطيط RTL/LTR فوري',
    },
    'features.settings.feature2': {
      'en': 'Cairo font bundled (no Google Fonts)',
      'ar': 'خط Cairo مرفق (بدون Google Fonts)',
    },
    'features.settings.feature3': {
      'en': 'Dark/light themes for night shifts',
      'ar': 'ثيمات داكنة/فاتحة للورديات الليلية',
    },
    'features.settings.feature4': {
      'en': 'Per-interaction auto-save (no save button)',
      'ar': 'حفظ تلقائي لكل تفاعل (بدون زر حفظ)',
    },
    'features.settings.feature5': {
      'en': 'Full keyboard shortcuts configurator',
      'ar': 'مُكوِّن مفاتيح سريعة كامل',
    },

    // ===== TESTIMONIALS =====
    'testimonials.title': {
      'en': 'Shop Owners Love Daftari',
      'ar': 'أصحاب المكتبات يحبون دفتری',
    },
    'testimonials.subtitle': {
      'en': 'Real feedback from Egyptian stationery retailers',
      'ar': 'آراء حقيقية من تجار المكتبات المصريين',
    },

    'testimonial.1.name': {'en': 'Ahmed Hassan', 'ar': 'أحمد حسن'},
    'testimonial.1.shop': {
      'en': 'Al-Ma\'rifa Bookstore, Cairo',
      'ar': 'مكتبة المعرفة، القاهرة',
    },
    'testimonial.1.text': {
      'en':
          'Finally a POS that understands Egyptian retail. The barcode scanning is instant, and the cash drawer buttons save me so much time calculating change. Best investment for my shop.',
      'ar':
          'أخيراً نظام نقاط بيع يفهم التجزئة المصرية. مسح الباركود فوري، وأزرار صندوق النقد توفر وقتاً هائلاً في حساب الباقي. أفضل استثمار لمكتبتي.',
    },

    'testimonial.2.name': {'en': 'Fatima Mahmoud', 'ar': 'فاطمة محمود'},
    'testimonial.2.shop': {
      'en': 'Noor Stationery, Alexandria',
      'ar': 'مكتبة نور، الإسكندرية',
    },
    'testimonial.2.text': {
      'en':
          'The Arabic interface is perfect — no broken translations. Dark mode saves my eyes during night shifts. And it runs smooth on my old i3 laptop. Highly recommended.',
      'ar':
          'الواجهة العربية مثالية — لا ترجمات معطلة. الوضع الداكن يريح عيني خلال الورديات الليلية. ويعمل بسلاسة على لابتوب i3 القديم. أنصح به بشدة.',
    },

    'testimonial.3.name': {'en': 'Mohamed Ali', 'ar': 'محمد علي'},
    'testimonial.3.shop': {
      'en': 'El-Shams Bookstore, Giza',
      'ar': 'مكتبة الشمس، الجيزة',
    },
    'testimonial.3.text': {
      'en':
          'Inventory management used to be a nightmare. Now I scan, it auto-generates barcodes, and stock updates automatically after each sale. The barcode label printing is a game changer.',
      'ar':
          'إدارة المخزون كانت كابوساً. الآن أمسح، يولد الباركود تلقائياً، والمخزون يحدث ذاتياً بعد كل عملية بيع. طباعة ملصقات الباركود غيرت قواعد اللعبة.',
    },

    // ===== TRUST BADGES =====
    'trust.title': {
      'en': 'Built to Professional Standards',
      'ar': 'مبني وفق معايير احترافية',
    },
    'trust.offlineFirst': {
      'en': 'Offline-First Architecture',
      'ar': 'بنية تعمل دون إنترنت أولاً',
    },
    'trust.offlineFirstDesc': {
      'en': 'Zero cloud dependency. Your data never leaves your machine.',
      'ar': 'صفر اعتماد على السحابة. بياناتك لا تغادر جهازك أبداً.',
    },
    'trust.performance': {
      'en': '60 FPS on Low-End Hardware',
      'ar': '٦٠ إطاراً في الثانية على أجهزة متواضعة',
    },
    'trust.performanceDesc': {
      'en': 'Optimized for 4GB RAM, integrated graphics, Windows 10.',
      'ar': 'محسّن لـ ٤ جيجابايت ذاكرة، رسومات مدمجة، ويندوز ١٠.',
    },
    'trust.security': {
      'en': 'Bank-Grade Encryption',
      'ar': 'تشفير بمستوى البنوك',
    },
    'trust.securityDesc': {
      'en': 'PBKDF2-HMAC-SHA256 (100k iterations) + Ed25519 DRM.',
      'ar': 'PBKDF2-HMAC-SHA256 (١٠٠ ألف تكرار) + DRM بتقنية Ed25519.',
    },
    'trust.openSource': {'en': 'Transparent Codebase', 'ar': 'قاعدة كود شفافة'},
    'trust.openSourceDesc': {
      'en':
          'No hidden telemetry. No forced updates. You control your software.',
      'ar': 'لا تجسس مخفي. لا تحديثات قسرية. أنت تتحكم في برنامجك.',
    },

    // ===== PRICING =====
    'pricing.title': {
      'en': 'Simple, Transparent Pricing',
      'ar': 'أسعار بسيطة وشفافة',
    },
    'pricing.subtitle': {
      'en': 'One-time purchase. No subscriptions. Lifetime updates included.',
      'ar': 'شراء لمرة واحدة. لا اشتراكات. تحديثات مدى الحياة مشمولة.',
    },
    'pricing.toggle.monthly': {'en': 'Monthly', 'ar': 'شهري'},
    'pricing.toggle.yearly': {'en': 'Yearly', 'ar': 'سنوي'},
    'pricing.toggle.lifetime': {'en': 'Lifetime', 'ar': 'مدى الحياة'},
    'pricing.badge.mostPopular': {'en': 'Most Popular', 'ar': 'الأكثر شيوعاً'},
    'pricing.badge.bestValue': {'en': 'Best Value', 'ar': 'أفضل قيمة'},

    // Starter Tier
    'pricing.starter.name': {'en': 'Starter', 'ar': 'البداية'},
    'pricing.starter.price.monthly': {'en': 'EGP 299', 'ar': '٢٩٩ ج.م'},
    'pricing.starter.price.yearly': {'en': 'EGP 2,990', 'ar': '٢٬٩٩٠ ج.م'},
    'pricing.starter.price.lifetime': {'en': 'EGP 8,970', 'ar': '٨٬٩٧٠ ج.م'},
    'pricing.starter.perMonth': {'en': '/month', 'ar': '/شهر'},
    'pricing.starter.perYear': {'en': '/year', 'ar': '/سنة'},
    'pricing.starter.once': {'en': 'one-time', 'ar': 'مرة واحدة'},
    'pricing.starter.desc': {
      'en': 'Perfect for small shops with single checkout',
      'ar': 'مثالي للمتاجر الصغيرة بنقطة دفع واحدة',
    },
    'pricing.starter.feature1': {
      'en': '1 checkout license',
      'ar': 'ترخيص نقطة دفع واحدة',
    },
    'pricing.starter.feature2': {
      'en': 'Unlimited products & sales',
      'ar': 'منتجات ومبيعات غير محدودة',
    },
    'pricing.starter.feature3': {
      'en': 'Barcode scanner support',
      'ar': 'دعم قارئ الباركود',
    },
    'pricing.starter.feature4': {
      'en': 'Quick-tiles (10 slots)',
      'ar': 'مربعات وصول سريع (١٠ خانات)',
    },
    'pricing.starter.feature5': {
      'en': 'Arabic/English + RTL',
      'ar': 'عربي/إنجليزي + RTL',
    },
    'pricing.starter.feature6': {
      'en': 'Dark/light themes',
      'ar': 'ثيمات داكنة/فاتحة',
    },
    'pricing.starter.feature7': {
      'en': 'Lifetime updates',
      'ar': 'تحديثات مدى الحياة',
    },
    'pricing.starter.feature8': {
      'en': 'Email support',
      'ar': 'دعم بالبريد الإلكتروني',
    },

    // Professional Tier
    'pricing.professional.name': {'en': 'Professional', 'ar': 'احترافي'},
    'pricing.professional.price.monthly': {'en': 'EGP 599', 'ar': '٥٩٩ ج.م'},
    'pricing.professional.price.yearly': {'en': 'EGP 5,990', 'ar': '٥٬٩٩٠ ج.م'},
    'pricing.professional.price.lifetime': {
      'en': 'EGP 17,970',
      'ar': '١٧٬٩٧٠ ج.م',
    },
    'pricing.professional.perMonth': {'en': '/month', 'ar': '/شهر'},
    'pricing.professional.perYear': {'en': '/year', 'ar': '/سنة'},
    'pricing.professional.once': {'en': 'one-time', 'ar': 'مرة واحدة'},
    'pricing.professional.desc': {
      'en': 'For growing shops with multiple stations',
      'ar': 'للمتاجر النامية بمحطات متعددة',
    },
    'pricing.professional.feature1': {
      'en': '3 checkout licenses',
      'ar': '٣ تراخيص نقاط دفع',
    },
    'pricing.professional.feature2': {
      'en': 'Shift management & sales analytics',
      'ar': 'إدارة الورديات وتحليلات المبيعات',
    },
    'pricing.professional.feature3': {
      'en': 'Receipt reprint & PDF export',
      'ar': 'إعادة طباعة الإيصال وتصدير PDF',
    },
    'pricing.professional.feature4': {
      'en': 'Barcode label printing (PNG)',
      'ar': 'طباعة ملصقات باركود (PNG)',
    },
    'pricing.professional.feature5': {
      'en': 'Multi-payment types (cash, Instapay, Visa)',
      'ar': 'أنواع دفع متعددة (نقدي، إنستاباي، فيزا)',
    },
    'pricing.professional.feature6': {
      'en': 'Tax configuration',
      'ar': 'إعداد الضريبة',
    },
    'pricing.professional.feature7': {
      'en': 'Keyboard shortcuts editor',
      'ar': 'محرر مفاتيح سريعة',
    },
    'pricing.professional.feature8': {
      'en': 'Priority email support',
      'ar': 'دعم بريدي أولوي',
    },

    // Business Tier
    'pricing.business.name': {'en': 'Business', 'ar': 'الأعمال'},
    'pricing.business.price.monthly': {'en': 'EGP 1,199', 'ar': '١٬١٩٩ ج.م'},
    'pricing.business.price.yearly': {'en': 'EGP 11,990', 'ar': '١١٬٩٩٠ ج.م'},
    'pricing.business.price.lifetime': {'en': 'EGP 35,970', 'ar': '٣٥٬٩٧٠ ج.م'},
    'pricing.business.perMonth': {'en': '/month', 'ar': '/شهر'},
    'pricing.business.perYear': {'en': '/year', 'ar': '/سنة'},
    'pricing.business.once': {'en': 'one-time', 'ar': 'مرة واحدة'},
    'pricing.business.desc': {
      'en': 'For chains & high-volume operations',
      'ar': 'للسلاسل والعمليات عالية الحجم',
    },
    'pricing.business.feature1': {
      'en': 'Unlimited checkout licenses',
      'ar': 'تراخيص نقاط دفع غير محدودة',
    },
    'pricing.business.feature2': {
      'en': 'Multi-branch inventory sync',
      'ar': 'مزامنة مخزون متعددة الفروع',
    },
    'pricing.business.feature3': {
      'en': 'Advanced sales exports (CSV/PDF)',
      'ar': 'تصدير مبيعات متقدم (CSV/PDF)',
    },
    'pricing.business.feature4': {
      'en': 'Expense tracking & profit reports',
      'ar': 'تتبع المصاريف وتقارير الأرباح',
    },
    'pricing.business.feature5': {
      'en': 'User management (admin/cashier roles)',
      'ar': 'إدارة المستخدمين (أدوار مدير/كاشير)',
    },
    'pricing.business.feature6': {
      'en': 'Custom receipt footnotes & branding',
      'ar': 'تذييلات إيصال مخصصة وعلامة تجارية',
    },
    'pricing.business.feature7': {
      'en': 'Phone + email priority support',
      'ar': 'دعم أولوي بالهاتف والبريد الإلكتروني',
    },
    'pricing.business.feature8': {
      'en': 'On-premise deployment option',
      'ar': 'خيار نشر محلي (On-premise)',
    },

    // ===== FAQ =====
    'faq.title': {'en': 'Frequently Asked Questions', 'ar': 'الأسئلة الشائعة'},
    'faq.subtitle': {
      'en': 'Everything you need to know before getting started',
      'ar': 'كل ما تحتاج معرفته قبل البدء',
    },

    'faq.1.q': {
      'en': 'Does Daftari POS require an internet connection?',
      'ar': 'هل يتطلب دفتری POS اتصالاً بالإنترنت؟',
    },
    'faq.1.a': {
      'en':
          'No. Daftari POS is 100% offline-first. All data is stored locally on your machine using Hive database. Internet is only needed for initial license activation and optional updates.',
      'ar':
          'لا. دفتری POS يعمل ١٠٠٪ دون إنترنت. جميع البيانات مخزنة محلياً على جهازك باستخدام قاعدة بيانات Hive. الإنترنت مطلوب فقط لتفعيل الترخيص الأولي والتحديثات الاختيارية.',
    },

    'faq.2.q': {
      'en': 'What hardware do I need?',
      'ar': 'ما الأجهزة التي أحتاجها؟',
    },
    'faq.2.a': {
      'en':
          'Windows 10 (64-bit), 4GB RAM minimum, any x64 processor (Intel i3/Celeron or better). Barcode scanner (USB/Bluetooth) and thermal receipt printer (ESC/POS) are supported but optional.',
      'ar':
          'ويندوز ١٠ (٦٤-بت)، ذاكرة ٤ جيجابايت حد أدنى، أي معالج x64 (Intel i3/سيليرون أو أفضل). قارئ باركود (USB/بلوتوث) وطابعة إيصالات حرارية (ESC/POS) مدعومة لكن اختيارية.',
    },

    'faq.3.q': {
      'en': 'Is there a subscription or recurring fee?',
      'ar': 'هل يوجد اشتراك أو رسوم متكررة؟',
    },
    'faq.3.a': {
      'en':
          'No subscriptions. You pay once and own the license forever. Lifetime tier includes all future updates. Monthly/Yearly tiers are for teams preferring operational expense model — you can upgrade to Lifetime anytime.',
      'ar':
          'لا اشتراكات. تدفع مرة واحدة وتملك الترخيص للأبد. مستوى "مدى الحياة" يشمل جميع التحديثات المستقبلية. المستويات الشهرية/السنوية للفرق التي تفضل نموذج مصاريف تشغيلية — يمكنك الترقية لـ "مدى الحياة" في أي وقت.',
    },

    'faq.4.q': {
      'en': 'Does it support Arabic and RTL fully?',
      'ar': 'هل يدعم العربية و RTL بالكامل؟',
    },
    'faq.4.a': {
      'en':
          'Yes. Full RTL layout mirroring, Cairo font bundled locally (no Google Fonts dependency), all UI text translated. Switch languages instantly from Settings — the entire interface flips including nav rail, dialogs, and receipts.',
      'ar':
          'نعم. انعكاس تخطيط RTL كامل، خط Cairo مرفق محلياً (بدون اعتماد على Google Fonts)، جميع نصوص الواجهة مترجمة. تبديل اللغات فوري من الإعدادات — الواجهة بأكملها تنعكس بما في ذلك شريط التنقل، النوافذ، والإيصالات.',
    },

    'faq.5.q': {
      'en': 'Can I print barcode labels for my products?',
      'ar': 'هل يمكنني طباعة ملصقات باركود لمنتجاتي؟',
    },
    'faq.5.a': {
      'en':
          'Yes. The Barcode Studio generates code128 barcodes automatically. You can preview them live in the product form and export as PNG labels with store name, product name, price, and notes — ready for thermal label printers.',
      'ar':
          'نعم. استوديو الباركود يولد باركود code128 تلقائياً. يمكنك معاينته مباشرة في نموذج المنتج وتصديره كملصق PNG مع اسم المتجر، اسم المنتج، السعر، والملاحظات — جاهز لطابعات الملصقات الحرارية.',
    },

    'faq.6.q': {
      'en': 'How does the license activation work?',
      'ar': 'كيف يعمل تفعيل الترخيص؟',
    },
    'faq.6.a': {
      'en':
          'Offline Ed25519 DRM. On first run, the app generates a device fingerprint (HWID). You receive a signed license file tied to that device. Activation is instant and completely offline — no license server to go down.',
      'ar':
          'DRM بتقنية Ed25519 دون إنترنت. عند التشغيل الأول، يولد التطبيق بصمة جهاز (HWID). تصلك ملف ترخيص موقع مرتبط بهذا الجهاز. التفعيل فوري وكامل دون إنترنت — لا خادم ترخيص قد يتعطل.',
    },

    'faq.7.q': {
      'en': 'What payment methods are supported?',
      'ar': 'ما طرق الدفع المدعومة؟',
    },
    'faq.7.a': {
      'en':
          'Cash, Instapay, Vodafone Cash, and Visa. You can enable/disable each in Settings. The cash drawer has quick buttons for Egyptian denominations (5, 10, 20, 50, 100, 200 EGP) for instant change calculation.',
      'ar':
          'نقدي، إنستاباي، فودافون كاش، وفيزا. يمكنك تفعيل/إلغاء تفعيل كل منها في الإعدادات. صندوق النقد يحتوي أزرار سريعة للفئات المصرية (٥، ١٠، ٢٠، ٥٠، ١٠٠، ٢٠٠ جنيه) لحساب الباقي فوراً.',
    },

    'faq.8.q': {
      'en': 'Can I try before buying?',
      'ar': 'هل يمكنني التجربة قبل الشراء؟',
    },
    'faq.8.a': {
      'en':
          'Yes! Click "Try Live Demo" to walk through the checkout flow in your browser.',
      'ar': 'نعم! اضغط "جرب العرض التوضيحي" لاستعراض تدفق الدفع في متصفحك.',
    },

    // ===== FOOTER =====
    'app.logoMark': {'en': 'D', 'ar': 'دف'},
    'faq.cta': {'en': "Didn't find your answer?", 'ar': 'لم تجد إجابتك؟'},
    'a11y.billingPeriod': {
      'en': 'Choose billing period',
      'ar': 'اختر فترة الفوترة',
    },
    'a11y.skipToContent': {'en': 'Skip to content', 'ar': 'تخطي إلى المحتوى'},
    'footer.product': {'en': 'Product', 'ar': 'المنتج'},
    'footer.pricing': {'en': 'Pricing', 'ar': 'الأسعار'},
    'footer.features': {'en': 'Features', 'ar': 'المميزات'},
    'footer.demo': {'en': 'Live Demo', 'ar': 'عرض توضيحي'},
    'footer.changelog': {'en': 'Changelog', 'ar': 'سجل التغييرات'},
    'footer.company': {'en': 'Company', 'ar': 'الشركة'},
    'footer.about': {'en': 'About Us', 'ar': 'من نحن'},
    'footer.blog': {'en': 'Blog', 'ar': 'المدونة'},
    'footer.careers': {'en': 'Careers', 'ar': 'الوظائف'},
    'footer.contact': {'en': 'Contact', 'ar': 'تواصل معنا'},
    'footer.resources': {'en': 'Resources', 'ar': 'الموارد'},
    'footer.docs': {'en': 'Documentation', 'ar': 'التوثيق'},
    'footer.help': {'en': 'Help Center', 'ar': 'مركز المساعدة'},
    'footer.api': {'en': 'API Reference', 'ar': 'مرجع API'},
    'footer.community': {'en': 'Community', 'ar': 'المجتمع'},
    'footer.legal': {'en': 'Legal', 'ar': 'القانونية'},
    'footer.privacy': {'en': 'Privacy Policy', 'ar': 'سياسة الخصوصية'},
    'footer.terms': {'en': 'Terms of Service', 'ar': 'شروط الخدمة'},
    'footer.license': {'en': 'License Agreement', 'ar': 'اتفاقية الترخيص'},
    'footer.copyright': {
      'en': '© 2024 Daftari POS. All rights reserved.',
      'ar': '© ٢٠٢٤ دفتری POS. جميع الحقوق محفوظة.',
    },
    'footer.madeInEgypt': {
      'en': 'Made with ❤️ in Egypt',
      'ar': 'صُنع بـ ❤️ في مصر',
    },

    // ===== CTA SECTION =====
    'cta.title': {
      'en': 'Ready to Modernize Your Shop?',
      'ar': 'مستعد لتطوير مكتبتك؟',
    },
    'cta.subtitle': {
      'en':
          'Join 500+ Egyptian stationery shops running Daftari POS. Start free, upgrade when ready.',
      'ar':
          'انضم لأكثر من ٥٠٠ مكتبة مصرية تدير أعمالها بـ دفتری POS. ابدأ مجاناً، ورَقِّ عندما تكون جاهزاً.',
    },
    'cta.primaryBtn': {'en': 'Download for Windows', 'ar': 'تحميل لويندوز'},
    'cta.secondaryBtn': {'en': 'Try Live Demo', 'ar': 'جرب العرض التوضيحي'},

    // ===== 404 =====
    'notFound.message': {
      'en': 'The page you are looking for does not exist.',
      'ar': 'الصفحة التي تبحث عنها غير موجودة.',
    },
    'notFound.backHome': {'en': 'Back to home', 'ar': 'عودة للرئيسية'},
  };

  /// Get translation for a key in the given language.
  static String t(String key, String lang) {
    return _translations[key]?[lang] ?? _translations[key]?['en'] ?? key;
  }

  /// Check if a key exists.
  static bool hasKey(String key) {
    return _translations.containsKey(key);
  }

  /// Get all keys for a language (useful for debugging).
  static List<String> getKeysForLang(String lang) {
    return _translations.entries
        .where((e) => e.value.containsKey(lang))
        .map((e) => e.key)
        .toList();
  }
}
