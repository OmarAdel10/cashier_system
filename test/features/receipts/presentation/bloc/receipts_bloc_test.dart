import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/crypto/password_hasher.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';
import 'package:cashier_system/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_entity.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_item.dart';
import 'package:cashier_system/features/receipts/domain/entities/receipt_status.dart';
import 'package:cashier_system/features/receipts/domain/entities/refund_entity.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_bloc.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_event.dart';
import 'package:cashier_system/features/receipts/presentation/bloc/receipts_state.dart';

import '../../helpers/fake_receipts_repository.dart';
import '../../helpers/fake_refunds_repository.dart';
import '../../../../features/inventory/helpers/fake_inventory_repository.dart';
import '../../../../helpers/default_receipt.dart';
import '../../../../helpers/default_product.dart';

class FakeAuthRepository implements IAuthRepository {
  UserEntity? adminUser;
  final List<UserEntity> savedUsers = [];

  @override
  Future<Either<Failure, List<UserEntity>>> getAll() async => Right([]);
  @override
  Future<Either<Failure, UserEntity?>> getByUsername(String username) async =>
      Right(username == adminUser?.username ? adminUser : null);
  @override
  Future<Either<Failure, void>> save(UserEntity user) async {
    savedUsers.add(user);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> delete(String username) async =>
      const Right(null);
  @override
  Future<Either<Failure, bool>> isSetupCompleted() async => const Right(true);
  @override
  Future<Either<Failure, void>> completeSetup(UserEntity admin) async =>
      const Right(null);
  @override
  Future<Either<Failure, void>> retrySeeding() async => const Right(null);
}

void main() {
  group('ReceiptsBloc', () {
    late FakeReceiptsRepository receiptsRepo;
    late FakeInventoryRepository inventoryRepo;
    late FakeRefundsRepository refundsRepo;
    late FakeAuthRepository authRepo;
    late ReceiptsBloc bloc;

    setUp(() async {
      receiptsRepo = FakeReceiptsRepository();
      inventoryRepo = FakeInventoryRepository();
      refundsRepo = FakeRefundsRepository();
      authRepo = FakeAuthRepository();
      bloc = ReceiptsBloc(
        receiptsRepo: receiptsRepo,
        inventoryRepo: inventoryRepo,
        refundsRepo: refundsRepo,
        authRepo: authRepo,
        getCurrentShiftId: () => 's1',
        generateId: () => 'test-receipt-id',
      );
      await inventoryRepo.saveProduct(
        defaultProduct(barcode: '123', name: 'Pen', stock: 10),
      );
    });

    tearDown(() {
      bloc.close();
    });

    group('initial state', () {
      test('should have initial status and no receipts', () {
        expect(bloc.state.status, ReceiptBlocStatus.initial);
        expect(bloc.state.receipts, isEmpty);
        expect(bloc.state.failure, isNull);
        expect(bloc.state.receiptCreated, isFalse);
      });
    });

    group('CreateReceipt', () {
      test('should save receipt, update stock, and emit ready', () async {
        await inventoryRepo.saveProduct(
          defaultProduct(barcode: '111', name: 'Pen', stock: 10),
        );
        await inventoryRepo.saveProduct(
          defaultProduct(barcode: '222', name: 'Notebook', stock: 5),
        );

        bloc.add(
          CreateReceipt(
            shiftId: 's1',
            orderNumber: 'ORD-00001',
            items: const [
              ReceiptItem(
                name: 'Pen',
                barcode: '111',
                quantity: 2,
                unitPricePiastres: 1500,
              ),
              ReceiptItem(
                name: 'Notebook',
                barcode: '222',
                quantity: 1,
                unitPricePiastres: 3000,
              ),
            ],
            subtotalPiastres: 6000,
            discountPiastres: 500,
            taxPiastres: 0,
            totalPiastres: 5500,
            username: 'cashier1',
          ),
        );

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>(
              (s) => s.status == ReceiptBlocStatus.loading,
            ),
            predicate<ReceiptsState>(
              (s) =>
                  s.status == ReceiptBlocStatus.ready &&
                  s.receipts.length == 1 &&
                  s.receipts.first.id == 'test-receipt-id' &&
                  s.receipts.first.shiftId == 's1' &&
                  s.receipts.first.orderNumber == 'ORD-00001' &&
                  s.receipts.first.stockUpdated == true &&
                  s.receipts.first.status == ReceiptStatus.active &&
                  s.receipts.first.username == 'cashier1' &&
                  s.receipts.first.subtotalPiastres == 6000 &&
                  s.receipts.first.discountPiastres == 500 &&
                  s.receipts.first.totalPiastres == 5500 &&
                  s.receiptCreated == true,
            ),
          ]),
        );
      });

      test('should emit error when receipt save fails', () async {
        final failingRepo = FailingFakeReceiptsRepository();
        final failingBloc = ReceiptsBloc(
          receiptsRepo: failingRepo,
          inventoryRepo: inventoryRepo,
          refundsRepo: refundsRepo,
          authRepo: authRepo,
          getCurrentShiftId: () => 's1',
          generateId: () => 'test-id',
        );

        failingBloc.add(
          const CreateReceipt(
            shiftId: 's1',
            orderNumber: 'ORD-00001',
            items: [],
            subtotalPiastres: 0,
            totalPiastres: 0,
            username: 'cashier1',
          ),
        );

        await expectLater(
          failingBloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>(
              (s) => s.status == ReceiptBlocStatus.loading,
            ),
            predicate<ReceiptsState>(
              (s) =>
                  s.status == ReceiptBlocStatus.error &&
                  s.failure != null &&
                  s.failure is DatabaseFailure,
            ),
          ]),
        );

        failingBloc.close();
      });

      test('should emit error when stock update fails', () async {
        bloc.add(
          CreateReceipt(
            shiftId: 's1',
            orderNumber: 'ORD-00001',
            items: const [
              ReceiptItem(
                name: 'Pen',
                barcode: '111',
                quantity: 2,
                unitPricePiastres: 1500,
              ),
            ],
            subtotalPiastres: 3000,
            totalPiastres: 3000,
            username: 'cashier1',
          ),
        );

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>(
              (s) => s.status == ReceiptBlocStatus.loading,
            ),
            predicate<ReceiptsState>(
              (s) => s.status == ReceiptBlocStatus.error && s.failure != null,
            ),
          ]),
        );
      });
      test('should reject items with negative quantity or price', () async {
        bloc.add(
          CreateReceipt(
            shiftId: 's1',
            orderNumber: 'ORD-NEG',
            items: const [
              ReceiptItem(
                name: 'Bad',
                barcode: '999',
                quantity: -1,
                unitPricePiastres: 1500,
              ),
            ],
            subtotalPiastres: -1500,
            totalPiastres: -1500,
            username: 'cashier1',
          ),
        );

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>(
              (s) => s.status == ReceiptBlocStatus.loading,
            ),
            predicate<ReceiptsState>(
              (s) => s.status == ReceiptBlocStatus.error && s.failure != null,
            ),
          ]),
        );
        expect(bloc.state.receipts, isEmpty);
      });
    });

    group('LoadReceipts', () {
      test('should load all receipts', () async {
        await receiptsRepo.save(
          defaultReceipt(id: 'r1', shiftId: 's1', orderNumber: 'ORD-001'),
        );
        await receiptsRepo.save(
          defaultReceipt(id: 'r2', shiftId: 's1', orderNumber: 'ORD-002'),
        );

        bloc.add(const LoadReceipts());

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>(
              (s) => s.status == ReceiptBlocStatus.loading,
            ),
            predicate<ReceiptsState>(
              (s) =>
                  s.status == ReceiptBlocStatus.ready &&
                  s.receipts.length == 2 &&
                  s.receiptCreated == false,
            ),
          ]),
        );
      });

      test('should emit error when loading fails', () async {
        final failingRepo = FailingFakeReceiptsRepository();
        final failingBloc = ReceiptsBloc(
          receiptsRepo: failingRepo,
          inventoryRepo: inventoryRepo,
          refundsRepo: refundsRepo,
          authRepo: authRepo,
          getCurrentShiftId: () => 's1',
          generateId: () => 'test-id',
        );

        failingBloc.add(const LoadReceipts());

        await expectLater(
          failingBloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>(
              (s) => s.status == ReceiptBlocStatus.loading,
            ),
            predicate<ReceiptsState>(
              (s) => s.status == ReceiptBlocStatus.error && s.failure != null,
            ),
          ]),
        );

        failingBloc.close();
      });
    });

    group('LoadReceiptsByMonth', () {
      test('should filter receipts by year and month', () async {
        final janDate = DateTime(2026, 1, 15);
        final febDate = DateTime(2026, 2, 10);

        await receiptsRepo.save(
          defaultReceipt(
            id: 'r1',
            shiftId: 's1',
            orderNumber: 'ORD-001',
            createdAt: janDate,
          ),
        );
        await receiptsRepo.save(
          defaultReceipt(
            id: 'r2',
            shiftId: 's1',
            orderNumber: 'ORD-002',
            createdAt: febDate,
          ),
        );
        await receiptsRepo.save(
          defaultReceipt(
            id: 'r3',
            shiftId: 's1',
            orderNumber: 'ORD-003',
            createdAt: janDate,
          ),
        );

        bloc.add(const LoadReceiptsByMonth(year: 2026, month: 1));

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>(
              (s) => s.status == ReceiptBlocStatus.loading,
            ),
            predicate<ReceiptsState>(
              (s) =>
                  s.status == ReceiptBlocStatus.ready &&
                  s.receipts.length == 2 &&
                  s.receipts.every(
                    (r) =>
                        r.orderNumber.startsWith('ORD-00') &&
                        (r.orderNumber == 'ORD-001' ||
                            r.orderNumber == 'ORD-003'),
                  ),
            ),
          ]),
        );
      });

      test('should emit error when loading fails', () async {
        final failingRepo = FailingFakeReceiptsRepository();
        final failingBloc = ReceiptsBloc(
          receiptsRepo: failingRepo,
          inventoryRepo: inventoryRepo,
          refundsRepo: refundsRepo,
          authRepo: authRepo,
          getCurrentShiftId: () => 's1',
          generateId: () => 'test-id',
        );

        failingBloc.add(const LoadReceiptsByMonth(year: 2026, month: 1));

        await expectLater(
          failingBloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>(
              (s) => s.status == ReceiptBlocStatus.loading,
            ),
            predicate<ReceiptsState>(
              (s) => s.status == ReceiptBlocStatus.error && s.failure != null,
            ),
          ]),
        );

        failingBloc.close();
      });
    });

    group('ProcessRefund', () {
      test(
        'should save refund, update status to returned, restore stock, emit ready',
        () async {
          await inventoryRepo.saveProduct(
            defaultProduct(barcode: '111', name: 'Pen', stock: 5),
          );
          await receiptsRepo.save(
            ReceiptEntity(
              id: 'r1',
              shiftId: 's1',
              orderNumber: 'ORD-001',
              items: const [
                ReceiptItem(
                  name: 'Pen',
                  barcode: '111',
                  quantity: 2,
                  unitPricePiastres: 1500,
                ),
              ],
              subtotalPiastres: 3000,
              totalPiastres: 3000,
              createdAt: DateTime(2026, 1, 1),
              username: 'cashier1',
              status: ReceiptStatus.active,
              stockUpdated: true,
            ),
          );

          bloc.add(const LoadReceipts());
          await bloc.stream.firstWhere(
            (s) => s.status == ReceiptBlocStatus.ready,
          );
          final receipt = bloc.state.receipts.first;

          bloc.add(
            ProcessRefund(
              receipt: receipt,
              type: RefundType.full,
              amountRestored: 3000,
            ),
          );

          await expectLater(
            bloc.stream,
            emitsInOrder([
              predicate<ReceiptsState>(
                (s) => s.status == ReceiptBlocStatus.loading,
              ),
              predicate<ReceiptsState>(
                (s) =>
                    s.status == ReceiptBlocStatus.ready &&
                    s.receipts.length == 1 &&
                    s.receipts.first.status == ReceiptStatus.returned &&
                    s.receiptCreated == false,
              ),
            ]),
          );

          expect(refundsRepo.savedRefunds.length, 1);
          expect(refundsRepo.savedRefunds.first.originalReceiptId, 'r1');
          expect(refundsRepo.savedRefunds.first.type, RefundType.full);
          expect(refundsRepo.savedRefunds.first.amountRestored, 3000);
        },
      );

      test('should not mark the refunded receipt as newly created', () async {
        await inventoryRepo.saveProduct(
          defaultProduct(barcode: '111', name: 'Pen', stock: 5),
        );

        bloc.add(
          CreateReceipt(
            shiftId: 's1',
            orderNumber: 'ORD-001',
            items: const [
              ReceiptItem(
                name: 'Pen',
                barcode: '111',
                quantity: 2,
                unitPricePiastres: 1500,
              ),
            ],
            subtotalPiastres: 3000,
            totalPiastres: 3000,
            username: 'cashier1',
          ),
        );
        await bloc.stream.firstWhere(
          (s) =>
              s.status == ReceiptBlocStatus.ready && s.receiptCreated == true,
        );
        final receipt = bloc.state.receipts.first;

        bloc.add(
          ProcessRefund(
            receipt: receipt,
            type: RefundType.full,
            amountRestored: 3000,
          ),
        );

        await bloc.stream.firstWhere(
          (s) =>
              s.status == ReceiptBlocStatus.ready && s.receiptCreated == false,
        );
        expect(bloc.state.receipts.first.status, ReceiptStatus.returned);
      });

      test(
        'should emit RefundLockFailure when receipt is not active',
        () async {
          final returnedReceipt = ReceiptEntity(
            id: 'r2',
            shiftId: 's1',
            orderNumber: 'ORD-002',
            items: const [],
            subtotalPiastres: 0,
            totalPiastres: 0,
            createdAt: DateTime(2026, 1, 1),
            username: 'cashier1',
            status: ReceiptStatus.returned,
            stockUpdated: true,
          );

          bloc.add(
            ProcessRefund(
              receipt: returnedReceipt,
              type: RefundType.full,
              amountRestored: 0,
            ),
          );

          await expectLater(
            bloc.stream,
            emitsInOrder([
              predicate<ReceiptsState>(
                (s) => s.status == ReceiptBlocStatus.loading,
              ),
              predicate<ReceiptsState>(
                (s) =>
                    s.status == ReceiptBlocStatus.error &&
                    s.failure is RefundLockFailure,
              ),
            ]),
          );
        },
      );

      test('should emit error when refund save fails', () async {
        final failingRefundRepo = FakeRefundsRepository();
        failingRefundRepo.shouldFail = true;
        final failingBloc = ReceiptsBloc(
          receiptsRepo: receiptsRepo,
          inventoryRepo: inventoryRepo,
          refundsRepo: failingRefundRepo,
          authRepo: authRepo,
          getCurrentShiftId: () => 's1',
          generateId: () => 'test-id',
        );

        final activeReceipt = ReceiptEntity(
          id: 'r3',
          shiftId: 's1',
          orderNumber: 'ORD-003',
          items: const [],
          subtotalPiastres: 0,
          totalPiastres: 0,
          createdAt: DateTime(2026, 1, 1),
          username: 'cashier1',
          status: ReceiptStatus.active,
          stockUpdated: true,
        );

        failingBloc.add(
          ProcessRefund(
            receipt: activeReceipt,
            type: RefundType.full,
            amountRestored: 0,
          ),
        );

        await expectLater(
          failingBloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>(
              (s) => s.status == ReceiptBlocStatus.loading,
            ),
            predicate<ReceiptsState>(
              (s) => s.status == ReceiptBlocStatus.error && s.failure != null,
            ),
          ]),
        );

        failingBloc.close();
      });
    });

    group('ModifyReceipt', () {
      test(
        'should update items, adjust stock delta, set status to modified, emit ready',
        () async {
          await inventoryRepo.saveProduct(
            defaultProduct(barcode: '111', name: 'Pen', stock: 10),
          );
          await receiptsRepo.save(
            ReceiptEntity(
              id: 'r1',
              shiftId: 's1',
              orderNumber: 'ORD-001',
              items: const [
                ReceiptItem(
                  name: 'Pen',
                  barcode: '111',
                  quantity: 5,
                  unitPricePiastres: 1500,
                ),
              ],
              subtotalPiastres: 7500,
              totalPiastres: 7500,
              createdAt: DateTime(2026, 1, 1),
              username: 'cashier1',
              status: ReceiptStatus.active,
              stockUpdated: true,
            ),
          );
          bloc.add(const LoadReceipts());
          await bloc.stream.firstWhere(
            (s) => s.status == ReceiptBlocStatus.ready,
          );
          final receipt = bloc.state.receipts.first;

          bloc.add(
            ModifyReceipt(
              receipt: receipt,
              items: const [
                ReceiptItem(
                  name: 'Pen',
                  barcode: '111',
                  quantity: 3,
                  unitPricePiastres: 1500,
                ),
              ],
              subtotalPiastres: 4500,
              discountPiastres: 0,
              taxPiastres: 0,
              totalPiastres: 4500,
            ),
          );

          await expectLater(
            bloc.stream,
            emitsInOrder([
              predicate<ReceiptsState>(
                (s) => s.status == ReceiptBlocStatus.loading,
              ),
              predicate<ReceiptsState>(
                (s) =>
                    s.status == ReceiptBlocStatus.ready &&
                    s.receipts.first.items.length == 1 &&
                    s.receipts.first.items.first.quantity == 3 &&
                    s.receipts.first.totalPiastres == 4500 &&
                    s.receipts.first.status == ReceiptStatus.modified &&
                    s.receipts.first.modificationCount == 1 &&
                    s.receiptCreated == false,
              ),
            ]),
          );
        },
      );

      test('should not mark a modified receipt as newly created', () async {
        await inventoryRepo.saveProduct(
          defaultProduct(barcode: '111', name: 'Pen', stock: 10),
        );

        bloc.add(
          CreateReceipt(
            shiftId: 's1',
            orderNumber: 'ORD-001',
            items: const [
              ReceiptItem(
                name: 'Pen',
                barcode: '111',
                quantity: 5,
                unitPricePiastres: 1500,
              ),
            ],
            subtotalPiastres: 7500,
            totalPiastres: 7500,
            username: 'cashier1',
          ),
        );
        await bloc.stream.firstWhere(
          (s) =>
              s.status == ReceiptBlocStatus.ready && s.receiptCreated == true,
        );
        final receipt = bloc.state.receipts.first;

        bloc.add(
          ModifyReceipt(
            receipt: receipt,
            items: const [
              ReceiptItem(
                name: 'Pen',
                barcode: '111',
                quantity: 3,
                unitPricePiastres: 1500,
              ),
            ],
            subtotalPiastres: 4500,
            discountPiastres: 0,
            taxPiastres: 0,
            totalPiastres: 4500,
          ),
        );

        await bloc.stream.firstWhere(
          (s) =>
              s.status == ReceiptBlocStatus.ready && s.receiptCreated == false,
        );
        expect(bloc.state.receipts.first.status, ReceiptStatus.modified);
      });

      test('should emit error when receipt is already returned', () async {
        final returnedReceipt = ReceiptEntity(
          id: 'r2',
          shiftId: 's1',
          orderNumber: 'ORD-002',
          items: const [],
          subtotalPiastres: 0,
          totalPiastres: 0,
          createdAt: DateTime(2026, 1, 1),
          username: 'cashier1',
          status: ReceiptStatus.returned,
          stockUpdated: true,
        );

        bloc.add(
          ModifyReceipt(
            receipt: returnedReceipt,
            items: const [],
            subtotalPiastres: 0,
            discountPiastres: 0,
            taxPiastres: 0,
            totalPiastres: 0,
          ),
        );

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>(
              (s) => s.status == ReceiptBlocStatus.loading,
            ),
            predicate<ReceiptsState>(
              (s) => s.status == ReceiptBlocStatus.error && s.failure != null,
            ),
          ]),
        );
      });
    });

    group('AuthorizedModifyReceipt', () {
      final testSalt = generateSalt();

      UserEntity adminUser({
        required String username,
        required String passwordHash,
        required String passwordSalt,
      }) {
        return UserEntity(
          username: username,
          passwordHash: passwordHash,
          passwordSalt: passwordSalt,
          mustChangePassword: false,
          role: UserRole.admin,
          createdAt: DateTime(2026, 1, 1),
        );
      }

      Future<ReceiptEntity> setupReceipt() async {
        await inventoryRepo.saveProduct(
          defaultProduct(barcode: '111', name: 'Pen', stock: 10),
        );
        await receiptsRepo.save(
          ReceiptEntity(
            id: 'r1',
            shiftId: 's1',
            orderNumber: 'ORD-001',
            items: const [
              ReceiptItem(
                name: 'Pen',
                barcode: '111',
                quantity: 5,
                unitPricePiastres: 1500,
              ),
            ],
            subtotalPiastres: 7500,
            totalPiastres: 7500,
            createdAt: DateTime(2026, 1, 1),
            username: 'cashier1',
            status: ReceiptStatus.active,
            stockUpdated: true,
          ),
        );
        bloc.add(const LoadReceipts());
        await bloc.stream.firstWhere(
          (s) => s.status == ReceiptBlocStatus.ready,
        );
        return bloc.state.receipts.first;
      }

      AuthorizedModifyReceipt modifyEvent({
        required ReceiptEntity receipt,
        required String adminUsername,
        required String adminPassword,
      }) {
        return AuthorizedModifyReceipt(
          receipt: receipt,
          items: const [
            ReceiptItem(
              name: 'Pen',
              barcode: '111',
              quantity: 3,
              unitPricePiastres: 1500,
            ),
          ],
          subtotalPiastres: 4500,
          discountPiastres: 0,
          taxPiastres: 0,
          totalPiastres: 4500,
          adminUsername: adminUsername,
          adminPassword: adminPassword,
        );
      }

      test(
        'accepts correct plaintext admin password and modifies receipt',
        () async {
          authRepo.adminUser = adminUser(
            username: 'admin',
            passwordHash: hashPassword('adminpass', testSalt),
            passwordSalt: testSalt,
          );
          final receipt = await setupReceipt();

          bloc.add(
            modifyEvent(
              receipt: receipt,
              adminUsername: 'admin',
              adminPassword: 'adminpass',
            ),
          );

          await expectLater(
            bloc.stream,
            emitsInOrder([
              predicate<ReceiptsState>(
                (s) => s.status == ReceiptBlocStatus.loading,
              ),
              predicate<ReceiptsState>(
                (s) =>
                    s.status == ReceiptBlocStatus.ready &&
                    s.receipts.first.status == ReceiptStatus.modified &&
                    s.receipts.first.modificationCount == 1 &&
                    s.receipts.first.totalPiastres == 4500 &&
                    s.receiptCreated == false,
              ),
            ]),
          );
        },
      );

      test(
        'accepts legacy-scheme admin password and migrates stored hash',
        () async {
          const legacySalt = 'legacy-utf8-salt';
          authRepo.adminUser = adminUser(
            username: 'admin',
            passwordHash: hashPasswordLegacy('adminpass', legacySalt),
            passwordSalt: legacySalt,
          );
          final receipt = await setupReceipt();

          bloc.add(
            modifyEvent(
              receipt: receipt,
              adminUsername: 'admin',
              adminPassword: 'adminpass',
            ),
          );

          await expectLater(
            bloc.stream,
            emitsInOrder([
              predicate<ReceiptsState>(
                (s) => s.status == ReceiptBlocStatus.loading,
              ),
              predicate<ReceiptsState>(
                (s) =>
                    s.status == ReceiptBlocStatus.ready &&
                    s.receipts.first.status == ReceiptStatus.modified,
              ),
            ]),
          );
          expect(authRepo.savedUsers, hasLength(1));
          final migrated = authRepo.savedUsers.last;
          expect(migrated.passwordSalt, isNot(legacySalt));
          expect(
            migrated.passwordHash,
            hashPassword('adminpass', migrated.passwordSalt),
          );
        },
      );

      test('rejects wrong admin password', () async {
        authRepo.adminUser = adminUser(
          username: 'admin',
          passwordHash: hashPassword('adminpass', testSalt),
          passwordSalt: testSalt,
        );
        final receipt = await setupReceipt();

        bloc.add(
          modifyEvent(
            receipt: receipt,
            adminUsername: 'admin',
            adminPassword: 'wrongpass',
          ),
        );

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>(
              (s) => s.status == ReceiptBlocStatus.loading,
            ),
            predicate<ReceiptsState>(
              (s) =>
                  s.status == ReceiptBlocStatus.error &&
                  s.failure is AuthenticationFailure,
            ),
          ]),
        );
        expect(authRepo.savedUsers, isEmpty);
      });

      test('rejects non-admin user', () async {
        authRepo.adminUser = adminUser(
          username: 'admin',
          passwordHash: hashPassword('adminpass', testSalt),
          passwordSalt: testSalt,
        ).copyWith(role: UserRole.cashier);
        final receipt = await setupReceipt();

        bloc.add(
          modifyEvent(
            receipt: receipt,
            adminUsername: 'admin',
            adminPassword: 'adminpass',
          ),
        );

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>(
              (s) => s.status == ReceiptBlocStatus.loading,
            ),
            predicate<ReceiptsState>(
              (s) =>
                  s.status == ReceiptBlocStatus.error &&
                  s.failure is AuthenticationFailure,
            ),
          ]),
        );
      });

      test('rejects when admin user is not found', () async {
        final receipt = await setupReceipt();

        bloc.add(
          modifyEvent(
            receipt: receipt,
            adminUsername: 'ghost',
            adminPassword: 'adminpass',
          ),
        );

        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<ReceiptsState>(
              (s) => s.status == ReceiptBlocStatus.loading,
            ),
            predicate<ReceiptsState>(
              (s) =>
                  s.status == ReceiptBlocStatus.error &&
                  s.failure is AuthenticationFailure,
            ),
          ]),
        );
      });
    });

    group('retryPendingStockUpdates', () {
      test(
        'retries stock for incomplete receipts (backward compat: empty stockFailedBarcodes retries all)',
        () async {
          // Save a product so updateStock will succeed
          await inventoryRepo.saveProduct(
            defaultProduct(barcode: '123', name: 'Pen', stock: 10),
          );

          // Save a receipt with stockUpdated: false, empty stockFailedBarcodes (old format)
          final receipt = defaultReceipt(id: 'r1', stockUpdated: false);
          await receiptsRepo.save(receipt);

          await bloc.retryPendingStockUpdates();

          final updated = await receiptsRepo.getByStockNotUpdated();
          updated.fold(
            (_) => fail('Expected Right'),
            (list) => expect(list, isEmpty),
          );
        },
      );

      test(
        'only retries failed barcodes when stockFailedBarcodes is populated',
        () async {
          // Save products for all barcodes
          await inventoryRepo.saveProduct(
            defaultProduct(barcode: '111', name: 'Pen', stock: 10),
          );
          await inventoryRepo.saveProduct(
            defaultProduct(barcode: '222', name: 'Notebook', stock: 10),
          );
          await inventoryRepo.saveProduct(
            defaultProduct(barcode: '333', name: 'Eraser', stock: 10),
          );

          // Receipt where 111 and 333 failed during create, 222 succeeded
          final receipt = defaultReceipt(
            id: 'r2',
            items: const [
              ReceiptItem(
                name: 'Pen',
                barcode: '111',
                quantity: 2,
                unitPricePiastres: 1500,
              ),
              ReceiptItem(
                name: 'Notebook',
                barcode: '222',
                quantity: 1,
                unitPricePiastres: 3000,
              ),
              ReceiptItem(
                name: 'Eraser',
                barcode: '333',
                quantity: 3,
                unitPricePiastres: 500,
              ),
            ],
            stockUpdated: false,
            stockFailedBarcodes: ['111', '333'],
          );
          await receiptsRepo.save(receipt);

          // Simulate stock already deducted for 222 (successful during create)
          await inventoryRepo.updateStock('222', -1);

          await bloc.retryPendingStockUpdates();

          // All pending should be resolved
          final updated = await receiptsRepo.getByStockNotUpdated();
          updated.fold(
            (_) => fail('Expected Right'),
            (list) => expect(list, isEmpty),
          );

          // Verify stock: 111 retried (10-2=8), 222 NOT retried (10-1=9), 333 retried (10-3=7)
          final inventoryResult = await inventoryRepo.getInventory();
          inventoryResult.fold((_) => fail('Expected Right'), (inventory) {
            expect(inventory['111']!.stock, 8);
            expect(inventory['222']!.stock, 9);
            expect(inventory['333']!.stock, 7);
          });
        },
      );

      test(
        'backward compat: empty stockFailedBarcodes retries all items from receipt',
        () async {
          // Save product only for '111' — '222' is missing so its update will fail
          await inventoryRepo.saveProduct(
            defaultProduct(barcode: '111', name: 'Pen', stock: 10),
          );

          // Receipt with 2 items but empty stockFailedBarcodes (old format — don't know which failed)
          final receipt = defaultReceipt(
            id: 'r3',
            items: const [
              ReceiptItem(
                name: 'Pen',
                barcode: '111',
                quantity: 2,
                unitPricePiastres: 1500,
              ),
              ReceiptItem(
                name: 'Missing',
                barcode: '222',
                quantity: 1,
                unitPricePiastres: 1000,
              ),
            ],
            stockUpdated: false,
            stockFailedBarcodes: const [], // old format
          );
          await receiptsRepo.save(receipt);

          await bloc.retryPendingStockUpdates();

          // 222 should still be pending (backward compat retried all, 222 failed)
          final pending = await receiptsRepo.getByStockNotUpdated();
          pending.fold((_) => fail('Expected Right'), (list) {
            expect(list.length, 1);
            expect(list.first.id, 'r3');
          });

          // 111 was retried (deducted again since backward compat doesn't know it was already deducted)
          final inventoryResult = await inventoryRepo.getInventory();
          inventoryResult.fold((_) => fail('Expected Right'), (inventory) {
            expect(
              inventory['111']!.stock,
              8,
            ); // 10 - 2 (deducted again because retried all)
          });
        },
      );
    });
  });
}
