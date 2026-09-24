// Copyright (c) 2024 Daftari POS. All rights reserved.

import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import '../l10n/translations.dart';

/// POS Mockup component showing the POS interface screenshot.
class POSMockup extends StatelessComponent {
  final String currentLanguage;

  const POSMockup({super.key, required this.currentLanguage});

  @override
  Component build(BuildContext context) {
    final lang = currentLanguage;
    final isRtl = lang == 'ar';

    return section(
      classes: 'pos-mockup-section',
      attributes: {'aria-labelledby': 'mockup-title'},
      [
        div(classes: 'container', [
          // Section header
          header(classes: 'section-header flex-col-center', [
            span(classes: 'badge badge-primary', [
              text(Translations.t('mockup.title', currentLanguage)),
            ]),
            h2(id: 'mockup-title', classes: 'heading-2', [
              text(Translations.t('mockup.subtitle', currentLanguage)),
            ]),
          ]),

          // Mockup image container
          div(classes: 'mockup-container', [
            div(classes: 'mockup-frame', [
              // Mockup browser chrome
              div(classes: 'mockup-chrome', [
                div(classes: 'chrome-dots', [
                  span(classes: 'dot red', []),
                  span(classes: 'dot yellow', []),
                  span(classes: 'dot green', []),
                ]),
                div(classes: 'chrome-url', [
                  text(Translations.t('mockup.chromeUrl', lang)),
                ]),
              ]),

              // Mockup content - POS interface
              div(
                classes: 'mockup-content',
                attributes: {'dir': isRtl ? 'rtl' : 'ltr'},
                [
                  // Left sidebar (nav rail)
                  aside(classes: 'mockup-sidebar', [
                    div(classes: 'sidebar-header', [
                      div(classes: 'sidebar-user', [
                        div(classes: 'user-avatar', [
                          text(Translations.t('mockup.userInitials', lang)),
                        ]),
                        div(classes: 'user-info', [
                          span(classes: 'user-name', [
                            text(Translations.t('mockup.userName', lang)),
                          ]),
                          span(classes: 'user-role', [
                            text(Translations.t('mockup.userRole', lang)),
                          ]),
                        ]),
                      ]),
                    ]),
                    nav(classes: 'sidebar-nav', [
                      _MockNavItem(
                        icon: '🛒',
                        label: Translations.t('mockup.nav.pos', lang),
                        active: true,
                      ),
                      _MockNavItem(
                        icon: '📊',
                        label: Translations.t('mockup.nav.sales', lang),
                        active: false,
                      ),
                    ]),
                    div(classes: 'sidebar-footer', [
                      _MockNavItem(
                        icon: '🚪',
                        label: Translations.t('mockup.nav.endShift', lang),
                        active: false,
                        destructive: true,
                      ),
                    ]),
                  ]),

                  // Main workspace
                  div(
                    classes: 'mockup-workspace',
                    attributes: {'role': 'main'},
                    [
                      // Top bar
                      header(classes: 'workspace-header', [
                        div(classes: 'header-search', [
                          span(classes: 'search-icon', [text('🔍')]),
                          input(
                            attributes: {
                              'type': 'text',
                              'placeholder': Translations.t(
                                'mockup.search',
                                lang,
                              ),
                              'class': 'search-input',
                            },
                          ),
                        ]),
                        div(classes: 'header-status', [
                          span(classes: 'status-indicator online', [
                            text(Translations.t('mockup.online', lang)),
                          ]),
                        ]),
                      ]),

                      // Cart area
                      section(classes: 'cart-section', [
                        header(classes: 'cart-header', [
                          h3(classes: 'cart-title', [
                            text(Translations.t('mockup.cart.title', lang)),
                          ]),
                          span(classes: 'cart-count', [
                            text(Translations.t('mockup.cart.count', lang)),
                          ]),
                        ]),
                        div(classes: 'cart-items', [
                          _MockCartItem(
                            name: Translations.t('mockup.product.pen', lang),
                            qty: '2',
                            price: '15.00 ج.م',
                            total: '30.00 ج.م',
                          ),
                          _MockCartItem(
                            name: Translations.t(
                              'mockup.product.notebook',
                              lang,
                            ),
                            qty: '1',
                            price: '25.00 ج.م',
                            total: '25.00 ج.م',
                          ),
                          _MockCartItem(
                            name: Translations.t('mockup.product.eraser', lang),
                            qty: '5',
                            price: '3.00 ج.م',
                            total: '15.00 ج.م',
                          ),
                        ]),
                        div(classes: 'cart-summary', [
                          div(classes: 'summary-row', [
                            span([
                              text(
                                Translations.t('mockup.cart.subtotal', lang),
                              ),
                            ]),
                            span([text('70.00 ج.م')]),
                          ]),
                          div(classes: 'summary-row discount', [
                            span([
                              text(
                                Translations.t('mockup.cart.discount', lang),
                              ),
                            ]),
                            span([text('-7.00 ج.م')]),
                          ]),
                          div(classes: 'summary-row tax', [
                            span([
                              text(Translations.t('mockup.cart.tax', lang)),
                            ]),
                            span([text('+8.82 ج.م')]),
                          ]),
                          div(classes: 'summary-row total', [
                            span([
                              text(Translations.t('mockup.cart.total', lang)),
                            ]),
                            span([text('71.82 ج.م')]),
                          ]),
                        ]),
                      ]),

                      // Quick tiles
                      section(classes: 'quick-tiles-section', [
                        h3(classes: 'section-title', [
                          text(Translations.t('mockup.tiles.title', lang)),
                        ]),
                        div(classes: 'quick-tiles-grid', [
                          _MockQuickTile(
                            label: Translations.t('mockup.tiles.copy', lang),
                            color: '#007ACC',
                          ),
                          _MockQuickTile(
                            label: Translations.t('mockup.tiles.wrap', lang),
                            color: '#10B981',
                          ),
                          _MockQuickTile(
                            label: Translations.t('mockup.tiles.paper', lang),
                            color: '#F59E0B',
                          ),
                          _MockQuickTile(
                            label: Translations.t('mockup.tiles.pens', lang),
                            color: '#EF4444',
                          ),
                          _MockQuickTile(
                            label: Translations.t('mockup.tiles.other', lang),
                            color: '#8B5CF6',
                          ),
                        ]),
                      ]),
                    ],
                  ),

                  // Right tower panel (receipt + cash drawer)
                  aside(classes: 'mockup-tower', [
                    // Receipt
                    section(classes: 'tower-receipt', [
                      header(classes: 'receipt-header', [
                        span(classes: 'receipt-icon', [text('🧾')]),
                        h3(classes: 'receipt-title', [
                          text(Translations.t('mockup.receipt.title', lang)),
                        ]),
                        span(classes: 'receipt-number', [
                          text(Translations.t('mockup.receipt.number', lang)),
                        ]),
                      ]),
                      div(classes: 'receipt-items', [
                        _MockReceiptItem(
                          no: '1',
                          name: 'قلم أزرق',
                          qty: 2,
                          price: '15.00',
                          total: '30.00',
                        ),
                        _MockReceiptItem(
                          no: '2',
                          name: 'دفتر A5',
                          qty: 1,
                          price: '25.00',
                          total: '25.00',
                        ),
                        _MockReceiptItem(
                          no: '3',
                          name: 'ممحاة',
                          qty: 5,
                          price: '3.00',
                          total: '15.00',
                        ),
                      ]),
                      div(classes: 'receipt-footer', [
                        div(classes: 'footer-row', [
                          span([
                            text(Translations.t('mockup.receipt.items', lang)),
                          ]),
                          span([text('70.00 ج.م')]),
                        ]),
                        div(classes: 'footer-row', [
                          span([
                            text(Translations.t('mockup.cart.discount', lang)),
                          ]),
                          span([text('-7.00 ج.م')]),
                        ]),
                        div(classes: 'footer-row', [
                          span([text(Translations.t('mockup.cart.tax', lang))]),
                          span([text('+8.82 ج.م')]),
                        ]),
                        div(classes: 'footer-row total', [
                          span([
                            text(Translations.t('mockup.cart.total', lang)),
                          ]),
                          span([text('71.82 ج.م')]),
                        ]),
                      ]),
                    ]),

                    // Cash drawer
                    section(classes: 'tower-cash-drawer', [
                      h3(classes: 'drawer-title', [
                        text(Translations.t('mockup.drawer.title', lang)),
                      ]),
                      div(classes: 'amount-due', [
                        span([text(Translations.t('mockup.drawer.due', lang))]),
                        span(classes: 'amount-value', [text('71.82 ج.م')]),
                      ]),
                      div(classes: 'denomination-grid', [
                        _MockDenomBtn(value: '5'),
                        _MockDenomBtn(value: '10'),
                        _MockDenomBtn(value: '20'),
                        _MockDenomBtn(value: '50'),
                        _MockDenomBtn(value: '100'),
                        _MockDenomBtn(value: '200'),
                        _MockDenomBtn(value: 'C', destructive: true),
                      ]),
                      div(classes: 'discount-row', [
                        label([
                          text(Translations.t('mockup.drawer.discount', lang)),
                        ]),
                        input(
                          attributes: {
                            'type': 'text',
                            'placeholder': '0%',
                            'class': 'discount-input',
                          },
                        ),
                      ]),
                      button(classes: 'btn-primary confirm-btn', [
                        text(Translations.t('mockup.drawer.confirm', lang)),
                      ]),
                    ]),
                  ]),
                ],
              ),
            ]),
          ]),
        ]),
      ],
    );
  }
}

/// Mock navigation item for sidebar
class _MockNavItem extends StatelessComponent {
  final String icon;
  final String label;
  final bool active;
  final bool destructive;

  const _MockNavItem({
    required this.icon,
    required this.label,
    required this.active,
    this.destructive = false,
  });

  @override
  Component build(BuildContext context) {
    return button(
      classes:
          'mock-nav-item ${active ? 'active' : ''} ${destructive ? 'destructive' : ''}',
      [
        span(classes: 'nav-icon', [text(icon)]),
        span(classes: 'nav-label', [text(label)]),
      ],
    );
  }
}

/// Mock cart item
class _MockCartItem extends StatelessComponent {
  final String name;
  final String qty;
  final String price;
  final String total;

  const _MockCartItem({
    required this.name,
    required this.qty,
    required this.price,
    required this.total,
  });

  @override
  Component build(BuildContext context) {
    return div(classes: 'cart-item', [
      div(classes: 'item-info', [
        span(classes: 'item-name', [text(name)]),
        span(classes: 'item-details', [text('$qty × $price')]),
      ]),
      span(classes: 'item-total', [text(total)]),
    ]);
  }
}

/// Mock quick tile
class _MockQuickTile extends StatelessComponent {
  final String label;
  final String color;

  const _MockQuickTile({required this.label, required this.color});

  @override
  Component build(BuildContext context) {
    return button(
      classes: 'quick-tile',
      attributes: {
        'style':
            'background-color: ${color}33; color: $color; border-color: ${color}66;',
      },
      [
        span(classes: 'tile-label', [text(label)]),
      ],
    );
  }
}

/// Mock receipt item
class _MockReceiptItem extends StatelessComponent {
  final String no;
  final String name;
  final int qty;
  final String price;
  final String total;

  const _MockReceiptItem({
    required this.no,
    required this.name,
    required this.qty,
    required this.price,
    required this.total,
  });

  @override
  Component build(BuildContext context) {
    return div(classes: 'receipt-item', [
      span(classes: 'item-no', [text('$no.')]),
      span(classes: 'item-name', [text(name)]),
      span(classes: 'item-qty-price', [text('$qty × $price')]),
      span(classes: 'item-total', [text('$total ج.م')]),
    ]);
  }
}

/// Mock denomination button
class _MockDenomBtn extends StatelessComponent {
  final String value;
  final bool destructive;

  const _MockDenomBtn({required this.value, this.destructive = false});

  @override
  Component build(BuildContext context) {
    return button(classes: 'denom-btn ${destructive ? 'destructive' : ''}', [
      text(value),
    ]);
  }
}
