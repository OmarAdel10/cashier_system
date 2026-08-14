import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive/hive.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../core/audit/audit_service.dart';
import '../core/business/business_type.dart';
import '../core/printing/print_service.dart';
import '../core/printing/receipt_print_helper.dart';
import '../core/printing/ticket_print_helper.dart';
import '../core/theme/spacing.dart';
import '../core/theme/text_styles.dart';
import '../core/widgets/section_card.dart';
import '../features/auth/domain/entities/nav_destination.dart';
import '../features/auth/domain/entities/user_entity.dart';
import '../features/shortcuts/default_bindings.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/bloc/auth_event.dart';
import '../features/auth/presentation/bloc/shift_bloc.dart';
import '../features/auth/presentation/bloc/shift_event.dart';
import '../features/auth/presentation/bloc/shift_state.dart';
import '../features/auth/presentation/widgets/end_shift_dialog.dart';
import '../features/checkout/domain/entities/table_entity.dart';
import '../features/checkout/domain/entities/table_round_entity.dart';
import '../features/checkout/domain/entities/zone_entity.dart';
import '../features/checkout/domain/helpers/ticket_routing.dart';
import '../features/checkout/presentation/bloc/checkout_bloc.dart';
import '../features/checkout/presentation/bloc/checkout_event.dart';
import '../features/checkout/presentation/bloc/checkout_state.dart';
import '../features/checkout/data/models/app_session_record_model.dart';
import '../features/checkout/data/models/app_station_model.dart';
import '../features/checkout/data/models/app_table_model.dart';
import '../features/checkout/data/models/app_table_round_model.dart';
import '../features/checkout/data/models/app_zone_model.dart';
import '../features/checkout/data/repositories/session_record_repository_impl.dart';
import '../features/checkout/data/repositories/station_repository_impl.dart';
import '../features/checkout/data/repositories/table_repository_impl.dart';
import '../features/checkout/data/repositories/table_round_repository_impl.dart';
import '../features/checkout/data/repositories/zone_repository.dart';
import '../features/checkout/presentation/bloc/session_record_bloc.dart';
import '../features/checkout/presentation/bloc/session_record_event.dart';
import '../features/checkout/presentation/bloc/station_bloc.dart';
import '../features/checkout/presentation/bloc/station_event.dart';
import '../features/checkout/presentation/bloc/station_state.dart';
import '../features/checkout/presentation/bloc/table_bloc.dart';
import '../features/checkout/presentation/bloc/table_event.dart';
import '../features/checkout/presentation/bloc/zone_bloc.dart';
import '../features/checkout/presentation/bloc/zone_event.dart';
import '../features/checkout/presentation/views/checkout_workspace.dart';
import '../features/checkout/presentation/views/station_workspace.dart';
import '../features/checkout/presentation/views/table_workspace.dart';
import '../features/checkout/presentation/widgets/auto_conversion_host.dart';
import '../features/checkout/presentation/widgets/barcode_scanner_gate.dart';
import '../features/checkout/presentation/widgets/checkout_tower_panel.dart';
import '../features/inventory/data/models/app_product_model.dart';
import '../features/inventory/data/repositories/category_repository.dart';
import '../features/inventory/data/repositories/inventory_repository.dart';
import '../features/receipts/data/models/app_receipt_model.dart';
import '../features/receipts/data/models/app_refund_model.dart';
import '../features/inventory/domain/entities/product_entity.dart';
import '../features/auth/domain/repositories/i_auth_repository.dart';
import '../features/inventory/domain/repositories/i_inventory_repository.dart';
import '../features/inventory/presentation/bloc/category_bloc.dart';
import '../features/inventory/presentation/bloc/category_event.dart';
import '../features/inventory/presentation/bloc/inventory_bloc.dart';
import '../features/inventory/presentation/bloc/inventory_event.dart';
import '../features/inventory/presentation/views/inventory_workspace.dart';
import '../features/inventory/presentation/views/product_form_dialog.dart';
import '../features/settings/data/services/localization_service.dart';
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
import '../features/settings/presentation/bloc/settings_bloc.dart';
import '../features/settings/presentation/bloc/settings_state.dart';
import '../features/settings/presentation/views/settings_workspace.dart';
import '../features/shortcuts/presentation/widgets/global_shortcut_gate.dart';
import '../../features/shortcuts/presentation/focus_controller.dart';
import '../features/expenses/data/repositories/expenses_repository_impl.dart';
import '../features/expenses/data/models/app_expense_model.dart';
import '../features/expenses/presentation/bloc/expenses_bloc.dart';
import '../features/expenses/presentation/bloc/expenses_state.dart';

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
  late FocusController? _focusController;
  bool _boxesReady = false;

  LazyBox<AppReceiptModel>? _receiptsBox;
  LazyBox<AppRefundModel>? _refundsBox;
  LazyBox<AppExpenseModel>? _expensesBox;
  Box<AppStationModel>? _stationsBox;
  Box<AppSessionRecordModel>? _sessionRecordsBox;
  Box<AppZoneModel>? _zonesBox;
  Box<AppTableModel>? _tablesBox;
  Box<AppTableRoundModel>? _tableRoundsBox;

  @override
  void initState() {
    super.initState();
    final allowed = roleNavMap[widget.user.role] ?? [NavDestination.checkout];
    _selectedDestination = ValueNotifier(allowed.first);
    _focusController = FocusController();
    _focusController?.attachAllowedDestinations(allowed);
    _focusController?.attachDestination(_selectedDestination);
    context.read<ShiftBloc>().add(StartShift(widget.user.username));
    _openBoxes();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncTaxPercent();
      final grid = BusinessType.fromId(
        context.read<SettingsBloc>().state.settings.businessType,
      ).isGridMode;
      _focusController?.attachScannerMode(!grid);
    });
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
      _expensesBox = Hive.isBoxOpen('expenses')
          ? Hive.lazyBox<AppExpenseModel>('expenses')
          : await Hive.openLazyBox<AppExpenseModel>(
              'expenses',
              encryptionCipher: cipher,
            );
      _stationsBox = Hive.isBoxOpen('stations')
          ? Hive.box<AppStationModel>('stations')
          : await Hive.openBox<AppStationModel>(
              'stations',
              encryptionCipher: cipher,
            );
      _sessionRecordsBox = Hive.isBoxOpen('session_records')
          ? Hive.box<AppSessionRecordModel>('session_records')
          : await Hive.openBox<AppSessionRecordModel>(
              'session_records',
              encryptionCipher: cipher,
            );
      _zonesBox = Hive.isBoxOpen('floor_zones')
          ? Hive.box<AppZoneModel>('floor_zones')
          : await Hive.openBox<AppZoneModel>(
              'floor_zones',
              encryptionCipher: cipher,
            );
      _tablesBox = Hive.isBoxOpen('tables')
          ? Hive.box<AppTableModel>('tables')
          : await Hive.openBox<AppTableModel>(
              'tables',
              encryptionCipher: cipher,
            );
      _tableRoundsBox = Hive.isBoxOpen('table_rounds')
          ? Hive.box<AppTableRoundModel>('table_rounds')
          : await Hive.openBox<AppTableRoundModel>(
              'table_rounds',
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
    super.dispose();
  }

  List<NavDestination> get _allowedDestinations =>
      roleNavMap[widget.user.role] ?? [NavDestination.checkout];

  void _onEndShift() async {
    final langCode = context.read<SettingsBloc>().state.settings.languageCode;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => EndShiftDialog(langCode: langCode),
    );
    if (confirmed == true && mounted) {
      context.read<ShiftBloc>().add(const EndShift());
    }
  }

  /// Prints tickets for a fired round: one ticket per enabled category
  /// printer. Builds the payload with venue info + table/zone/round context
  /// resolved from the current shell state.
  Future<void> _printTickets(
    TableRoundEntity round,
    TableEntity table,
    List<TicketRoute> routes,
  ) async {
    final settings = context.read<SettingsBloc>().state.settings;
    final zones = _zonesBox == null
        ? const <ZoneEntity>[]
        : context.read<ZoneBloc>().state.zones;
    final zone = zones.where((z) => z.id == table.zoneId).firstOrNull;
    final service = PrintService();
    try {
      for (final route in routes) {
        await service.printTicket(
          buildTicketPayload(
            route: route,
            round: round,
            table: table,
            zoneName: zone?.name ?? '',
            settings: settings,
          ),
        );
      }
    } finally {
      service.dispose();
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
              sessionRecordsRepo: SessionRecordRepositoryImpl(
                _sessionRecordsBox!,
              ),
              inventoryRepo: ctx.read<IInventoryRepository>(),
              expensesRepo: ExpensesRepositoryImpl(box: _expensesBox!),
            ),
          ),
          BlocProvider<ExpensesBloc>(
            create: (ctx) => ExpensesBloc(
              expensesRepo: ExpensesRepositoryImpl(box: _expensesBox!),
              inventoryRepo: ctx.read<IInventoryRepository>(),
              getCurrentShiftId: () =>
                  ctx.read<ShiftBloc>().state.shift?.id ?? '',
              auditService: ctx.read<AuditService>(),
            ),
          ),
          BlocProvider<StationBloc>(
            create: (_) =>
                StationBloc(repository: StationRepositoryImpl(_stationsBox!))
                  ..add(const LoadStations()),
          ),
          BlocProvider<ZoneBloc>(
            create: (ctx) => ZoneBloc(
              repository: ZoneRepository(
                businessType: BusinessType.fromId(
                  ctx.read<SettingsBloc>().state.settings.businessType,
                ),
                box: _zonesBox!,
              ),
            )..add(const LoadZones()),
          ),
          BlocProvider<TableBloc>(
            create: (ctx) => TableBloc(
              tableRepository: TableRepositoryImpl(_tablesBox!),
              roundRepository: TableRoundRepositoryImpl(_tableRoundsBox!),
              settingsReader: () => ctx.read<SettingsBloc>().state.settings,
              ticketPrinter: (round, table, routes) =>
                  _printTickets(round, table, routes),
            )..add(const LoadTables()),
          ),
          BlocProvider<CategoryBloc>(create: (ctx) => _buildCategoryBloc(ctx)),
          BlocProvider<SessionRecordBloc>(
            create: (_) => SessionRecordBloc(
              repository: SessionRecordRepositoryImpl(_sessionRecordsBox!),
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
            BlocListener<StationBloc, StationState>(
              listenWhen: (previous, current) =>
                  previous.lastCompletedSession !=
                      current.lastCompletedSession &&
                  current.lastCompletedSession != null,
              listener: (context, state) {
                final record = state.lastCompletedSession!;
                final shiftId = context.read<ShiftBloc>().state.shift?.id ?? '';
                final username = widget.user.username;
                context.read<SessionRecordBloc>().add(
                  CreateSessionRecord(
                    record: record.copyWith(
                      shiftId: shiftId,
                      username: username,
                    ),
                  ),
                );
                if (record.addonLines.isNotEmpty) {
                  context.read<ReceiptsBloc>().add(
                    CreateReceipt(
                      shiftId: shiftId,
                      orderNumber: 'F&B-${record.stationId}-${record.id}',
                      items: record.addonLines
                          .map(
                            (l) => ReceiptItem(
                              name: l.name,
                              barcode: l.barcode,
                              quantity: l.quantity,
                              unitPricePiastres: l.unitPricePiastres,
                            ),
                          )
                          .toList(),
                      subtotalPiastres: record.addonLines.fold(
                        0,
                        (sum, l) => sum + l.quantity * l.unitPricePiastres,
                      ),
                      totalPiastres: record.addonLines.fold(
                        0,
                        (sum, l) => sum + l.quantity * l.unitPricePiastres,
                      ),
                      username: username,
                    ),
                  );
                }
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
                final taxPercent = settings.taxEnabled
                    ? settings.taxPercent
                    : 0;
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
                    amountPaidPiastres: state.amountPaidPiastres,
                    paymentType: state.paymentType,
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
                if (!settings.autoPrintEnabled && !settings.saveReceiptAsImage)
                  return;
                if (!state.receiptCreated) return;

                final receipt = state.receipts.last;
                final shiftStartedAt = context
                    .read<ShiftBloc>()
                    .state
                    .shift
                    ?.startedAt;

                ReceiptPrintHelper.printReceipt(
                      receipt: receipt,
                      settings: settings,
                      shiftStartedAt: shiftStartedAt,
                    )
                    .then((_) {
                      if (settings.saveReceiptAsImage && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              t.translate(
                                'sales.pngSaved',
                                languageCode: langCode,
                              ),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    })
                    .catchError((error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              t.translate(
                                'sales.autoPrintFailed',
                                languageCode: langCode,
                                params: [error.toString()],
                              ),
                            ),
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                        );
                      }
                    });
              },
            ),
            BlocListener<ExpensesBloc, ExpensesState>(
              listenWhen: (previous, current) =>
                  current.status == ExpenseBlocStatus.ready &&
                  previous.status == ExpenseBlocStatus.loading,
              listener: (context, state) {
                context.read<InventoryBloc>().add(const RefreshInventory());
              },
            ),
          ],
          child: ValueListenableBuilder<NavDestination>(
            valueListenable: _selectedDestination,
            builder: (context, destination, child) {
              final isCheckout = destination == NavDestination.checkout;
              final businessType = BusinessType.fromId(
                context.read<SettingsBloc>().state.settings.businessType,
              );
              final isPlaystation = businessType == BusinessType.playstation;
              final isTableBilling = businessType.isTableBilling;
              return GlobalShortcutGate(
                allowedDestinations: _allowedDestinations,
                selectedDestination: _selectedDestination,
                isSearchOpenNotifier: _isSearchOpenNotifier,
                barcodeInjectionNotifier: _barcodeInjectionNotifier,
                discountFocusTrigger: _discountFocusTrigger,
                focusController: _focusController,
                onAddProduct: () {
                  showDialog<ProductEntity>(
                    context: context,
                    builder: (dialogContext) => MultiBlocProvider(
                      providers: [
                        BlocProvider<InventoryBloc>.value(
                          value: context.read<InventoryBloc>(),
                        ),
                        BlocProvider<CategoryBloc>(
                          create: (ctx) => _buildCategoryBloc(ctx),
                        ),
                      ],
                      child: const ProductFormDialog(),
                    ),
                  ).then((r) {
                    if (r != null && context.mounted) {
                      context.read<InventoryBloc>().add(
                        AddProduct(
                          barcode: r.barcode,
                          name: r.name,
                          price: r.price,
                          purchasePrice: r.purchasePrice,
                          stock: r.stock,
                          isQuickTile: r.isQuickTile,
                          tileColorHex: r.tileColorHex,
                          notes: r.notes,
                          category: r.category,
                          prepCategory: r.prepCategory,
                        ),
                      );
                    }
                  });
                },
                child: BarcodeScannerGate(
                  focusController: _focusController,
                  enabled: !BusinessType.fromId(
                    context.read<SettingsBloc>().state.settings.businessType,
                  ).isGridMode,
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
                                    if (isPlaystation)
                                      const AutoConversionHost(
                                        child: StationWorkspace(),
                                      )
                                    else if (isTableBilling)
                                      const TableWorkspace()
                                    else
                                      const CheckoutWorkspace(),
                                    const InventoryWorkspace(),
                                    SalesWorkspace(user: widget.user),
                                    SettingsWorkspace(currentUser: widget.user),
                                  ],
                                ),
                              ),
                              if (isCheckout &&
                                  !isPlaystation &&
                                  !isTableBilling) ...[
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
                                    focusController: _focusController,
                                    user: widget.user,
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
                  if (isLoading) const LinearProgressIndicator(minHeight: 2),
                  _NavRailItem(
                    icon: PhosphorIcons.signOut,
                    label: t.translate('shift.end', languageCode: languageCode),
                    isSelected: false,
                    backgroundColor: Colors.red.withValues(alpha: 0.25),
                    fgColor: Colors.red.shade600,
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
  final Color? backgroundColor;
  final Color? fgColor;

  const _NavRailItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.backgroundColor,
    this.fgColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fgColor =
        this.fgColor ??
        (isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 56,
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          decoration: BoxDecoration(
            color:
                backgroundColor ??
                (isSelected ? colorScheme.primaryContainer : null),
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

CategoryBloc _buildCategoryBloc(BuildContext context) {
  final businessType = BusinessType.fromId(
    context.read<SettingsBloc>().state.settings.businessType,
  );
  return CategoryBloc(
    repository: CategoryRepository(
      businessType: businessType,
      box: Hive.box<List>('product_categories'),
    ),
  )..add(const LoadCategories());
}
