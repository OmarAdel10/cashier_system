// Copyright (c) 2024 Daftari POS. All rights reserved.

/// Design tokens for the Daftari POS landing page.
/// Matches the DESIGN.md specification exactly.

class DesignTokens {
  // Colors (from DESIGN.md Section 2)
  static const String primary = '#007ACC'; // Deep Modern Blue
  static const String success = '#10B981'; // Teal Green
  static const String bgLight = '#F5F0EB'; // Warm Beige
  static const String cardLight = '#FFFDF5'; // Light card background
  static const String bgDark = '#0F172A'; // Charcoal/Slate
  static const String cardDark = '#1E293B'; // Dark card background
  static const String borderLight = '#E8E0D8'; // Warm Beige Grey
  static const String borderDark = '#334155'; // Dark border
  static const String textLight = '#1E293B'; // Dark text on light
  static const String textDark = '#F5F0EB'; // Light text on dark
  static const String textMutedLight = '#64748B'; // Muted text on light
  static const String textMutedDark = '#94A3B8'; // Muted text on dark
  static const String accentGold = '#F59E0B'; // Gold accent
  static const String accentRed = '#EF4444'; // Red accent
  static const String accentPurple = '#8B5CF6'; // Purple accent

  // Spacing (from DESIGN.md Section 6.1)
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // Border radius (from DESIGN.md Section 3)
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusFull = 9999;

  // Typography (from DESIGN.md Section 2)
  static const String fontFamily = 'Cairo';
  static const double headlineLarge = 32; // Bold
  static const double headlineMedium = 28; // Bold
  static const double headlineSmall = 24; // Bold
  static const double heading2 = 24; // Bold
  static const double heading3 = 20; // SemiBold
  static const double titleMedium = 16; // SemiBold
  static const double bodyLarge = 16; // Regular
  static const double body = 14; // Regular
  static const double bodySmall = 12; // Regular
  static const double caption = 11; // Regular

  // Font weights
  static const int weightRegular = 400;
  static const int weightMedium = 500;
  static const int weightSemiBold = 600;
  static const int weightBold = 700;

  // Breakpoints
  static const double bpMobile = 640;
  static const double bpTablet = 768;
  static const double bpDesktop = 1024;
  static const double bpWide = 1280;
  static const double bpUltraWide = 1536;

  // Container max widths
  static const double containerSm = 640;
  static const double containerMd = 768;
  static const double containerLg = 1024;
  static const double containerXl = 1280;
  static const double container2Xl = 1536;

  // Transitions
  static const String transitionFast = '150ms ease';
  static const String transitionNormal = '200ms ease';
  static const String transitionSlow = '300ms ease';

  // Shadows
  static const String shadowSm = '0 1px 2px 0 rgb(0 0 0 / 0.05)';
  static const String shadowMd =
      '0 4px 6px -1px rgb(0 0 0 / 0.1), 0 2px 4px -2px rgb(0 0 0 / 0.1)';
  static const String shadowLg =
      '0 10px 15px -3px rgb(0 0 0 / 0.1), 0 4px 6px -4px rgb(0 0 0 / 0.1)';
  static const String shadowXl =
      '0 20px 25px -5px rgb(0 0 0 / 0.1), 0 8px 10px -6px rgb(0 0 0 / 0.1)';

  // Z-index
  static const int zDropdown = 100;
  static const int zSticky = 200;
  static const int zFixed = 300;
  static const int zModalBackdrop = 400;
  static const int zModal = 500;
  static const int zPopover = 600;
  static const int zTooltip = 700;
}

/// CSS-in-Dart style definitions for Jaspr components.
class Styles {
  // Container styles
  static const String container =
      '''
    width: 100%;
    max-width: ${DesignTokens.containerXl}px;
    margin: 0 auto;
    padding: 0 ${DesignTokens.md}px;
  ''';

  static const String containerFluid =
      '''
    width: 100%;
    padding: 0 ${DesignTokens.xl}px;
  ''';

  // Section padding
  static const String sectionPy =
      '''
    padding-top: ${DesignTokens.xxl}px;
    padding-bottom: ${DesignTokens.xxl}px;
  ''';

  static const String sectionPySm =
      '''
    padding-top: ${DesignTokens.xl}px;
    padding-bottom: ${DesignTokens.xl}px;
  ''';

  // Flex utilities
  static const String flexCenter = '''
    display: flex;
    align-items: center;
    justify-content: center;
  ''';

  static const String flexBetween = '''
    display: flex;
    align-items: center;
    justify-content: space-between;
  ''';

  static const String flexCol = '''
    display: flex;
    flex-direction: column;
  ''';

  static const String flexColCenter = '''
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
  ''';

  // Grid
  static const String grid2 =
      '''
    display: grid;
    grid-template-columns: repeat(2, 1fr);
    gap: ${DesignTokens.lg}px;
  ''';

  static const String grid3 =
      '''
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: ${DesignTokens.lg}px;
  ''';

  static const String grid4 =
      '''
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: ${DesignTokens.lg}px;
  ''';

  // Responsive grid breakpoints
  static const String gridResponsive =
      '''
    display: grid;
    gap: ${DesignTokens.lg}px;
    grid-template-columns: 1fr;
    @media (min-width: ${DesignTokens.bpTablet}px) {
      grid-template-columns: repeat(2, 1fr);
    }
    @media (min-width: ${DesignTokens.bpDesktop}px) {
      grid-template-columns: repeat(3, 1fr);
    }
  ''';

  // Card styles
  static const String card =
      '''
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: ${DesignTokens.radiusMd}px;
    padding: ${DesignTokens.lg}px;
    transition: box-shadow ${DesignTokens.transitionNormal}, transform ${DesignTokens.transitionNormal};
  ''';

  static const String cardHover =
      '''
    box-shadow: ${DesignTokens.shadowLg};
    transform: translateY(-2px);
  ''';

  // Button styles
  static const String btnPrimary =
      '''
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: ${DesignTokens.sm}px;
    padding: ${DesignTokens.md}px ${DesignTokens.xl}px;
    background: ${DesignTokens.primary};
    color: white;
    font-family: ${DesignTokens.fontFamily};
    font-size: ${DesignTokens.body}px;
    font-weight: ${DesignTokens.weightSemiBold};
    border: none;
    border-radius: ${DesignTokens.radiusMd}px;
    cursor: pointer;
    transition: background ${DesignTokens.transitionFast}, transform ${DesignTokens.transitionFast};
    text-decoration: none;
  ''';

  static const String btnPrimaryHover = '''
    background: #0066aa;
    transform: translateY(-1px);
  ''';

  static const String btnSecondary =
      '''
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: ${DesignTokens.sm}px;
    padding: ${DesignTokens.md}px ${DesignTokens.xl}px;
    background: transparent;
    color: ${DesignTokens.primary};
    font-family: ${DesignTokens.fontFamily};
    font-size: ${DesignTokens.body}px;
    font-weight: ${DesignTokens.weightSemiBold};
    border: 2px solid ${DesignTokens.primary};
    border-radius: ${DesignTokens.radiusMd}px;
    cursor: pointer;
    transition: background ${DesignTokens.transitionFast}, color ${DesignTokens.transitionFast};
    text-decoration: none;
  ''';

  static const String btnSecondaryHover =
      '''
    background: ${DesignTokens.primary};
    color: white;
  ''';

  static const String btnGhost =
      '''
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: ${DesignTokens.sm}px;
    padding: ${DesignTokens.sm}px ${DesignTokens.md}px;
    background: transparent;
    color: var(--text-color);
    font-family: ${DesignTokens.fontFamily};
    font-size: ${DesignTokens.bodySmall}px;
    font-weight: ${DesignTokens.weightMedium};
    border: none;
    border-radius: ${DesignTokens.radiusSm}px;
    cursor: pointer;
    transition: background ${DesignTokens.transitionFast};
    text-decoration: none;
  ''';

  static const String btnGhostHover = '''
    background: var(--border-color);
  ''';

  // Input styles
  static const String input =
      '''
    width: 100%;
    padding: ${DesignTokens.md}px;
    background: var(--card-bg);
    border: 1px solid var(--border-color);
    border-radius: ${DesignTokens.radiusMd}px;
    font-family: ${DesignTokens.fontFamily};
    font-size: ${DesignTokens.body}px;
    color: var(--text-color);
    transition: border-color ${DesignTokens.transitionFast}, box-shadow ${DesignTokens.transitionFast};
  ''';

  static const String inputFocus =
      '''
    outline: none;
    border-color: ${DesignTokens.primary};
    box-shadow: 0 0 0 3px ${DesignTokens.primary}33;
  ''';

  // Typography styles
  static const String heading1 =
      '''
    font-family: ${DesignTokens.fontFamily};
    font-size: ${DesignTokens.headlineLarge}px;
    font-weight: ${DesignTokens.weightBold};
    line-height: 1.2;
    color: var(--text-color);
  ''';

  static const String heading2 =
      '''
    font-family: ${DesignTokens.fontFamily};
    font-size: ${DesignTokens.heading2}px;
    font-weight: ${DesignTokens.weightBold};
    line-height: 1.3;
    color: var(--text-color);
  ''';

  static const String heading3 =
      '''
    font-family: ${DesignTokens.fontFamily};
    font-size: ${DesignTokens.heading3}px;
    font-weight: ${DesignTokens.weightSemiBold};
    line-height: 1.4;
    color: var(--text-color);
  ''';

  static const String bodyLarge =
      '''
    font-family: ${DesignTokens.fontFamily};
    font-size: ${DesignTokens.bodyLarge}px;
    font-weight: ${DesignTokens.weightRegular};
    line-height: 1.6;
    color: var(--text-color);
  ''';

  static const String body =
      '''
    font-family: ${DesignTokens.fontFamily};
    font-size: ${DesignTokens.body}px;
    font-weight: ${DesignTokens.weightRegular};
    line-height: 1.6;
    color: var(--text-color);
  ''';

  static const String bodyMuted =
      '''
    font-family: ${DesignTokens.fontFamily};
    font-size: ${DesignTokens.body}px;
    font-weight: ${DesignTokens.weightRegular};
    line-height: 1.6;
    color: var(--text-muted);
  ''';

  static const String bodySmall =
      '''
    font-family: ${DesignTokens.fontFamily};
    font-size: ${DesignTokens.bodySmall}px;
    font-weight: ${DesignTokens.weightRegular};
    line-height: 1.5;
    color: var(--text-muted);
  ''';

  static const String caption =
      '''
    font-family: ${DesignTokens.fontFamily};
    font-size: ${DesignTokens.caption}px;
    font-weight: ${DesignTokens.weightMedium};
    line-height: 1.5;
    color: var(--text-muted);
    text-transform: uppercase;
    letter-spacing: 0.05em;
  ''';

  // Badge styles
  static const String badge =
      '''
    display: inline-flex;
    align-items: center;
    padding: ${DesignTokens.xs}px ${DesignTokens.sm}px;
    font-family: ${DesignTokens.fontFamily};
    font-size: ${DesignTokens.caption}px;
    font-weight: ${DesignTokens.weightSemiBold};
    border-radius: ${DesignTokens.radiusFull}px;
  ''';

  static const String badgePrimary =
      '''
    background: ${DesignTokens.primary}1a;
    color: ${DesignTokens.primary};
  ''';

  static const String badgeSuccess =
      '''
    background: ${DesignTokens.success}1a;
    color: ${DesignTokens.success};
  ''';

  static const String badgeWarning =
      '''
    background: ${DesignTokens.accentGold}1a;
    color: ${DesignTokens.accentGold};
  ''';

  // Divider
  static const String divider = '''
    width: 100%;
    height: 1px;
    background: var(--border-color);
    border: none;
  ''';

  // Focus visible (accessibility)
  static const String focusVisible =
      '''
    outline: none;
    ring: 2px;
    ring-offset: 2px;
    ring-color: ${DesignTokens.primary};
  ''';

  // Visually hidden (for accessibility)
  static const String visuallyHidden = '''
    position: absolute;
    width: 1px;
    height: 1px;
    padding: 0;
    margin: -1px;
    overflow: hidden;
    clip: rect(0, 0, 0, 0);
    white-space: nowrap;
    border: 0;
  ''';
}

/// Generates the complete CSS string for the landing page.
String generateGlobalCss({bool isDark = false, bool isRtl = false}) {
  final bgColor = isDark ? DesignTokens.bgDark : DesignTokens.bgLight;
  final cardBg = isDark ? DesignTokens.cardDark : DesignTokens.cardLight;
  final borderColor = isDark
      ? DesignTokens.borderDark
      : DesignTokens.borderLight;
  final textColor = isDark ? DesignTokens.textDark : DesignTokens.textLight;
  final textMuted = isDark
      ? DesignTokens.textMutedDark
      : DesignTokens.textMutedLight;
  final direction = isRtl ? 'rtl' : 'ltr';

  return '''
    @font-face {
      font-family: '${DesignTokens.fontFamily}';
      src: url('/fonts/Cairo/Cairo[slnt,wght].ttf') format('truetype');
      font-weight: 400 700;
      font-style: normal;
      font-display: swap;
    }

    :root {
      --bg-color: $bgColor;
      --card-bg: $cardBg;
      --border-color: $borderColor;
      --text-color: $textColor;
      --text-muted: $textMuted;
      --primary: ${DesignTokens.primary};
      --success: ${DesignTokens.success};
      --direction: $direction;
    }

    * {
      box-sizing: border-box;
    }

    html {
      direction: var(--direction);
      scroll-behavior: smooth;
    }

    body {
      margin: 0;
      font-family: '${DesignTokens.fontFamily}', system-ui, sans-serif;
      background: var(--bg-color);
      color: var(--text-color);
      line-height: 1.6;
      -webkit-font-smoothing: antialiased;
      -moz-osx-font-smoothing: grayscale;
    }

    img {
      max-width: 100%;
      height: auto;
      display: block;
    }

    a {
      color: var(--primary);
      text-decoration: none;
      transition: color ${DesignTokens.transitionFast};
    }

    a:hover {
      color: #0066aa;
    }

    button {
      font-family: inherit;
    }

    /* Selection styles */
    ::selection {
      background: ${DesignTokens.primary}33;
      color: var(--text-color);
    }

    /* Focus visible for keyboard navigation */
    :focus-visible {
      outline: 2px solid var(--primary);
      outline-offset: 2px;
    }

    /* Skip link for accessibility */
    .skip-link {
      position: absolute;
      top: -100%;
      left: ${DesignTokens.md}px;
      padding: ${DesignTokens.sm}px ${DesignTokens.md}px;
      background: var(--primary);
      color: white;
      border-radius: ${DesignTokens.radiusSm}px;
      z-index: ${DesignTokens.zTooltip};
      transition: top ${DesignTokens.transitionFast};
    }

    .skip-link:focus {
      top: ${DesignTokens.md}px;
    }

    /* RTL specific adjustments */
    [dir="rtl"] .flex-row-reverse {
      flex-direction: row-reverse;
    }

    [dir="rtl"] .text-start {
      text-align: right;
    }

    [dir="rtl"] .text-end {
      text-align: left;
    }

    /* Animation keyframes */
    @keyframes fadeIn {
      from { opacity: 0; }
      to { opacity: 1; }
    }

    @keyframes slideUp {
      from { opacity: 0; transform: translateY(20px); }
      to { opacity: 1; transform: translateY(0); }
    }

    @keyframes slideDown {
      from { opacity: 0; transform: translateY(-20px); }
      to { opacity: 1; transform: translateY(0); }
    }

    @keyframes scaleIn {
      from { opacity: 0; transform: scale(0.95); }
      to { opacity: 1; transform: scale(1); }
    }

    .animate-fade-in {
      animation: fadeIn ${DesignTokens.transitionNormal} ease forwards;
    }

    .animate-slide-up {
      animation: slideUp ${DesignTokens.transitionSlow} ease forwards;
    }

    .animate-slide-down {
      animation: slideDown ${DesignTokens.transitionSlow} ease forwards;
    }

    .animate-scale-in {
      animation: scaleIn ${DesignTokens.transitionNormal} ease forwards;
    }

    /* Staggered animation delays */
    .stagger-1 { animation-delay: 100ms; }
    .stagger-2 { animation-delay: 200ms; }
    .stagger-3 { animation-delay: 300ms; }
    .stagger-4 { animation-delay: 400ms; }
    .stagger-5 { animation-delay: 500ms; }
    .stagger-6 { animation-delay: 600ms; }

    /* Utility classes */
    .sr-only { ${Styles.visuallyHidden} }
    .container { ${Styles.container} }
    .container-fluid { ${Styles.containerFluid} }
    .section-py { ${Styles.sectionPy} }
    .section-py-sm { ${Styles.sectionPySm} }
    .flex-center { ${Styles.flexCenter} }
    .flex-between { ${Styles.flexBetween} }
    .flex-col { ${Styles.flexCol} }
    .flex-col-center { ${Styles.flexColCenter} }
    .grid-2 { ${Styles.grid2} }
    .grid-3 { ${Styles.grid3} }
    .grid-4 { ${Styles.grid4} }
    .grid-responsive { ${Styles.gridResponsive} }
    .card { ${Styles.card} }
    .card:hover { ${Styles.cardHover} }
    .btn-primary { ${Styles.btnPrimary} }
    .btn-primary:hover { ${Styles.btnPrimaryHover} }
    .btn-secondary { ${Styles.btnSecondary} }
    .btn-secondary:hover { ${Styles.btnSecondaryHover} }
    .btn-ghost { ${Styles.btnGhost} }
    .btn-ghost:hover { ${Styles.btnGhostHover} }
    .input { ${Styles.input} }
    .input:focus { ${Styles.inputFocus} }
    .heading-1 { ${Styles.heading1} }
    .heading-2 { ${Styles.heading2} }
    .heading-3 { ${Styles.heading3} }
    .body-large { ${Styles.bodyLarge} }
    .body { ${Styles.body} }
    .body-muted { ${Styles.bodyMuted} }
    .body-small { ${Styles.bodySmall} }
    .caption { ${Styles.caption} }
    .badge { ${Styles.badge} }
    .badge-primary { ${Styles.badgePrimary} }
    .badge-success { ${Styles.badgeSuccess} }
    .badge-warning { ${Styles.badgeWarning} }
    .divider { ${Styles.divider} }
  ''';
}
