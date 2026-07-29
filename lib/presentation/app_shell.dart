import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../core/audit/audit_service.dart';
import '../core/printing/receipt_print_helper.dart';
import '../core/theme/spacing.dart';
import '../core/theme/text_styles.dart';
import '../core/widgets/section_card.dart';
import '../features/auth/domain/entities/nav_destination.dart';
import '../features/auth/domain/entities/user_entity.dart';
import '../features/auth/domain/entities/user_role.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/bloc/auth_event.dart';
import '../features/auth/presentation/bloc/shift_bloc.dart';
import '../features/auth/presentation/bloc/shift_event.dart';
import '../features/auth/presentation/bloc/shift_state.dart';
import '../features/auth/presentation/widgets/end_shift_dialog.dart';
import '../features/checkout/presentation/bloc/checkout_bloc.dart';
import '../features/checkout/presentation/bloc/checkout_event.dart';
import '../features/checkout/presentation/bloc/checkout_state.dart';
import '../features/checkout/presentation/views/checkout_workspace.dart';
import '../features/checkout/presentation/widgets/barcode_scanner_gate.dart';
import '../features/checkout/presentation/widgets/checkout_tower_panel.dart';
import '../features/inventory/data/models/app_product_model.dart';
import '../features/inventory/data/repositories/inventory_repository.dart';
import '../features/receipts/data/models/app_receipt_model.dart';
import '../features/receipts/data/models/app_refund_model.dart';
import '../features/inventory/domain/entities/product_entity.dart';
import '../features/auth/domain/repositories/i_auth_repository.dart';
import '../features/inventory/domain/repositories/i_inventory_repository.dart';
import '../features/inventory/presentation/bloc/inventory_bloc.dart';
import '../features/inventory/presentation/bloc/inventory_event.dart';
import '../features/inventory/presentation/views/inventory_workspace.dart';
import '../features/inventory/presentation/views/product_form_dialog.dart';
import '../features/auth/data/models/app_shift_model.dart';
import '../features/auth/data/repositories/shifts_repository_impl.dart';
import '../features/receipts/data/repositories/receipts_repository_impl.dart';
import '../features/receipts/data/repositories/refunds_repository_impl.dart';
import '../features/receipts/domain/entities/receipt_item.dart';
import '../features/receipts/presentation/bloc/receipts_bloc.dart';
import '../features/receipts/presentation/bloc/receipts_event.dart';
import '../features/receipts/presentation/bloc/receipts_state.dart';
import '../features/sales/presentation/bloc/sales_bloc.dart';
import '../features/sales/presentation/views/sales_workspace.dart';
import '../features/settings/data/services/localization_service.dart';
import '../features/settings/presentation/bloc/settings_bloc.dart';
import '../features/settings/presentation/bloc/settings_state.dart';
import '../features/settings/presentation/views/settings_workspace.dart';
import '../features/shortcuts/presentation/widgets/global_shortcut_gate.dart';

final Map<UserRole, List<NavDestination>> roleNavMap = {
  UserRole.admin: [NavDestination.sales, NavDestination.settings],
  UserRole.cashier: [
    NavDestination.checkout,
    NavDestination.inventory,
    NavDestination.sales,
    NavDestination.settings,
  ],
};

class AppShell extends StatefulWidget {
  final UserEntity user;
  final HiveAesCipher? hiveCipher;

  const AppShell({super.key, required this.user, this.hiveCipher});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final ValueNotifier<NavDestination> _selectedDestination;
  final ValueNotifier<bool> _isSearchOpenNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<String> _barcodeInjectionNotifier = ValueNotifier<String>(
    '',
  );
  final ValueNotifier<int> _discountFocusTrigger = ValueNotifier<int>(0);
  final ValueNotifier<int> _cartFocusTrigger = ValueNotifier<int>(0);
  bool _boxesReady = false;

  LazyBox<AppReceiptModel>? _receiptsBox;
  LazyBox<AppRefundModel>? _refundsBox;

  @override
  void initState() {
    super.initState();
    final allowed = roleNavMap[widget.user.role] ?? [NavDestination.checkout];
    _selectedDestination = ValueNotifier(allowed.first);
    context.read<ShiftBloc>().add(StartShift(widget.user.username));
    _openBoxes();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncTaxPercent());
  }

  void _syncTaxPercent() {
    if (!mounted) return;
    try {
      final s = context.read<SettingsBloc>().state.settings;
      final percent = s.taxEnabled ? s.taxPercent : 0;
      context.read<CheckoutBloc>().add(SetTaxPercent(percent));
    } catch (_) {}
  }

  Future<void> _openBoxes() async {
    try {
      final cipher = widget.hiveCipher;
      _receiptsBox = Hive.isBoxOpen('receipts')
          ? Hive.lazyBox<AppReceiptModel>('receipts')
          : await Hive.openLazyBox<AppReceiptModel>(
              'receipts',
              encryptionCipher: cipher,
            );
      _refundsBox = Hive.isBoxOpen('refunds')
          ? Hive.lazyBox<AppRefundModel>('refunds')
          : await Hive.openLazyBox<AppRefundModel>(
              'refunds',
              encryptionCipher: cipher,
            );
    } catch (e) {
      debugPrint('[AppShell] Failed to open boxes: $e');
    }
    if (mounted) setState(() => _boxesReady = true);
  }

  @override
  void dispose() {
    _selectedDestination.dispose();
    _isSearchOpenNotifier.dispose();
    _barcodeInjectionNotifier.dispose();
    _discountFocusTrigger.dispose();
    _cartFocusTrigger.dispose();
    super.dispose();
  }

  List<NavDestination> get _allowedDestinations =>
      roleNavMap[widget.user.role] ?? [NavDestination.checkout];

  void _onEndShift() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const EndShiftDialog(),
    );
    if (confirmed == true && mounted) {
      context.read<ShiftBloc>().add(const EndShift());
    }
  }

  @override
  Widget build(BuildContext context) {
    final langCode = context.select(
      (SettingsBloc b) => b.state.settings.languageCode,
    );
    final t = LocalizationService();

    if (!_boxesReady) {
      return const Scaffold(body: Center(child: SizedBox.shrink()));
    }

    return RepositoryProvider<IInventoryRepository>.value(
      value: InventoryRepository(box: Hive.box<AppProductModel>('inventory')),
      child: MultiBlocProvider(
        providers: [
          BlocProvider<ReceiptsBloc>(
            create: (ctx) {
              final bloc = ReceiptsBloc(
                receiptsRepo: ReceiptsRepositoryImpl(box: _receiptsBox!),
                inventoryRepo: ctx.read<IInventoryRepository>(),
                refundsRepo: RefundsRepositoryImpl(box: _refundsBox!),
                authRepo: ctx.read<IAuthRepository>(),
                getCurrentShiftId: () =>
                    ctx.read<ShiftBloc>().state.shift?.id ?? '',
                auditService: ctx.read<AuditService>(),
              );
              unawaited(bloc.retryPendingStockUpdates());
              return bloc;
            },
          ),
          BlocProvider<SalesBloc>(
            create: (ctx) => SalesBloc(
              receiptsRepo: ReceiptsRepositoryImpl(box: _receiptsBox!),
              shiftsRepo: ShiftsRepositoryImpl(
                box: Hive.box<AppShiftModel>('shifts'),
                activeBox: Hive.box<String>('active_shifts'),
              ),
            ),
          ),
        ],
        child: MultiBlocListener(
          listeners: [
            BlocListener<SettingsBloc, SettingsState>(
              listenWhen: (SettingsState prev, SettingsState curr) =>
                  prev.settings.taxEnabled != curr.settings.taxEnabled ||
                  prev.settings.taxPercent != curr.settings.taxPercent,
              listener: (BuildContext _, SettingsState state) {
                final percent = state.settings.taxEnabled
                    ? state.settings.taxPercent
                    : 0;
                context.read<CheckoutBloc>().add(SetTaxPercent(percent));
              },
            ),
            BlocListener<ShiftBloc, ShiftState>(
              listenWhen: (_, state) => state.status == ShiftStatus.ended,
              listener: (_, __) {
                context.read<AuthBloc>().add(const LogoutRequested());
              },
            ),
            BlocListener<ShiftBloc, ShiftState>(
              listenWhen: (previous, current) =>
                  !previous.orphanRecovered && current.orphanRecovered,
              listener: (_, __) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        t.translate(
                          'shift.orphanRecovered',
                          languageCode: langCode,
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
            BlocListener<ShiftBloc, ShiftState>(
              listenWhen: (_, state) => state.status == ShiftStatus.error,
              listener: (context, state) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      t.translate(
                        'shift.start.failed',
                        languageCode: langCode,
                        params: [state.failure?.message ?? 'Unknown error'],
                      ),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              },
            ),
            BlocListener<CheckoutBloc, CheckoutState>(
              listenWhen: (_, state) =>
                  state.status == CheckoutStatus.confirmed,
              listener: (context, state) {
                final shiftState = context.read<ShiftBloc>().state;
                final shiftId = shiftState.shift?.id;
                if (shiftId == null || state.cart == null) return;
                final cart = state.cart!;
                final settings = context.read<SettingsBloc>().state.settings;
                final taxPercent =
                    settings.taxEnabled ? settings.taxPercent : 0;
                context.read<ReceiptsBloc>().add(
                  CreateReceipt(
                    shiftId: shiftId,
                    orderNumber: state.orderNumber ?? '',
                    items: cart.items
                        .map(
                          (e) => ReceiptItem(
                            name: e.name,
                            barcode: e.barcode,
                            quantity: e.quantity,
                            unitPricePiastres: e.unitPricePiastres,
                          ),
                        )
                        .toList(),
                    subtotalPiastres: state.subtotalPiastres,
                    discountPiastres: state.discountAmount,
                    taxPiastres: state.taxAmount,
                    totalPiastres: state.totalPiastres,
                    username:
                        context.read<AuthBloc>().state.user?.username ?? '',
                    taxPercent: taxPercent,
                    discountPercent: state.discountPercent,
                  ),
                );
              },
            ),
            BlocListener<ReceiptsBloc, ReceiptsState>(
              listenWhen: (previous, current) =>
                  current.status == ReceiptBlocStatus.ready &&
                  previous.status == ReceiptBlocStatus.loading,
              listener: (context, state) {
                context.read<InventoryBloc>().add(const RefreshInventory());

                final settings = context.read<SettingsBloc>().state.settings;
                if (!settings.autoPrintEnabled && !settings.saveReceiptAsImage) return;

                final receipt = state.receipts.last;
                final shiftStartedAt =
                    context.read<ShiftBloc>().state.shift?.startedAt;

                ReceiptPrintHelper.printReceipt(
                  receipt: receipt,
                  settings: settings,
                  shiftStartedAt: shiftStartedAt,
                ).then((_) {
                  if (settings.saveReceiptAsImage && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t.translate('sales.pngSaved', languageCode: langCode)),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }).catchError((error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(t.translate('sales.autoPrintFailed', languageCode: langCode, params: [error.toString()])),
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                });
              },
            ),
          ],
          child: ValueListenableBuilder<NavDestination>(
            valueListenable: _selectedDestination,
            builder: (context, destination, child) {
              final isCheckout = destination == NavDestination.checkout;
              return GlobalShortcutGate(
                allowedDestinations: _allowedDestinations,
                selectedDestination: _selectedDestination,
                isSearchOpenNotifier: _isSearchOpenNotifier,
                barcodeInjectionNotifier: _barcodeInjectionNotifier,
                discountFocusTrigger: _discountFocusTrigger,
                onAddProduct: () {
                  showDialog<ProductEntity>(
                    context: context,
                    builder: (_) => BlocProvider.value(
                      value: context.read<InventoryBloc>(),
                      child: const ProductFormDialog(),
                    ),
                  ).then((r) {
                    if (r != null && context.mounted) {
                      context.read<InventoryBloc>().add(
                        AddProduct(
                          barcode: r.barcode,
                          name: r.name,
                          price: r.price,
                          stock: r.stock,
                          isQuickTile: r.isQuickTile,
                          tileColorHex: r.tileColorHex,
                        ),
                      );
                    }
                  });
                },
                child: BarcodeScannerGate(
                  isSearchOpenNotifier: _isSearchOpenNotifier,
                  onBarcodeScanned: (barcode) {
                    _barcodeInjectionNotifier.value = barcode;
                  },
                  child: Scaffold(
                    body: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: Spacing.lg),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SectionCard(
                                padding: const EdgeInsets.symmetric(
                                  vertical: Spacing.sm,
                                  horizontal: Spacing.xs,
                                ),
                                child: _NavRail(
                                  allowedDestinations: _allowedDestinations,
                                  selectedDestination: destination,
                                  onDestinationSelected: (d) =>
                                      _selectedDestination.value = d,
                                  languageCode: langCode,
                                  username: widget.user.username,
                                  onEndShift: _onEndShift,
                                ),
                              ),
                              Container(
                                width: 1,
                                color: Theme.of(context).dividerColor,
                              ),
                              Expanded(
                                flex: isCheckout ? 7 : 1,
                                child: IndexedStack(
                                  index: NavDestination.values.indexOf(
                                    destination,
                                  ),
                                  children: [
                                    CheckoutWorkspace(
                                      cartFocusTrigger: _cartFocusTrigger,
                                    ),
                                    const InventoryWorkspace(),
                                    SalesWorkspace(user: widget.user),
                                    SettingsWorkspace(currentUser: widget.user),
                                  ],
                                ),
                              ),
                              if (isCheckout) ...[
                                Container(
                                  width: 1,
                                  color: Theme.of(context).dividerColor,
                                ),
                                ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    minWidth: 360,
                                    maxWidth: 500,
                                  ),
                                  child: CheckoutTowerPanel(
                                    discountFocusTrigger: _discountFocusTrigger,
                                    cartFocusTrigger: _cartFocusTrigger,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

const _navItemData = {
  NavDestination.checkout: _NavItemData(
    PhosphorIcons.shoppingCartSimple,
    'navCheckout',
  ),
  NavDestination.inventory: _NavItemData(PhosphorIcons.package, 'navInventory'),
  NavDestination.sales: _NavItemData(PhosphorIcons.chartBar, 'navSales'),
  NavDestination.settings: _NavItemData(PhosphorIcons.gearSix, 'navSettings'),
};

class _NavItemData {
  final IconData icon;
  final String labelKey;
  const _NavItemData(this.icon, this.labelKey);
}

class _NavRail extends StatelessWidget {
  final List<NavDestination> allowedDestinations;
  final NavDestination selectedDestination;
  final ValueChanged<NavDestination> onDestinationSelected;
  final String languageCode;
  final String username;
  final VoidCallback onEndShift;

  const _NavRail({
    required this.allowedDestinations,
    required this.selectedDestination,
    required this.onDestinationSelected,
    required this.languageCode,
    required this.username,
    required this.onEndShift,
  });

  @override
  Widget build(BuildContext context) {
    final t = LocalizationService();
    final theme = Theme.of(context);

    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.md),
            child: Text(
              username,
              style: TextStyles.caption.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          ...allowedDestinations.map((dest) {
            final data = _navItemData[dest]!;
            return _NavRailItem(
              icon: data.icon,
              label: t.translate(data.labelKey, languageCode: languageCode),
              isSelected: dest == selectedDestination,
              onTap: () => onDestinationSelected(dest),
            );
          }),
          const Spacer(),
          BlocBuilder<ShiftBloc, ShiftState>(
            builder: (context, shiftState) {
              final isLoading = shiftState.status == ShiftStatus.loading;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    const LinearProgressIndicator(minHeight: 2),
                  _NavRailItem(
                    icon: PhosphorIcons.signOut,
                    label: t.translate('shift.end', languageCode: languageCode),
                    isSelected: false,
                    onTap: isLoading ? null : onEndShift,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: Spacing.sm),
        ],
      ),
    );
  }
}

class _NavRailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _NavRailItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fgColor = isSelected
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          decoration: BoxDecoration(
            color: isSelected ? colorScheme.primaryContainer : null,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: fgColor),
              const SizedBox(height: Spacing.xs),
              Text(
                label,
                style: TextStyles.caption.copyWith(color: fgColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
