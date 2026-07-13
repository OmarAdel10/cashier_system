import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cashier_system/core/error/either.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:cashier_system/features/auth/domain/entities/user_entity.dart';
import 'package:cashier_system/features/auth/domain/entities/user_role.dart';
import 'package:cashier_system/features/auth/domain/entities/shift_entity.dart';
import 'package:cashier_system/features/auth/domain/repositories/i_auth_repository.dart';
import 'package:cashier_system/features/auth/domain/repositories/i_shifts_repository.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:cashier_system/features/auth/presentation/bloc/auth_event.dart';
import 'package:cashier_system/features/auth/presentation/bloc/shift_bloc.dart';
import 'package:cashier_system/features/checkout/presentation/bloc/checkout_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/inventory_event.dart';
import 'package:cashier_system/presentation/app_shell.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'features/inventory/helpers/fake_inventory_repository.dart';
import 'features/settings/helpers/fake_settings_repository.dart';

class _MockStorage extends Storage {
  final _store = <String, dynamic>{};

  @override
  Future<void> write(String key, dynamic value) async {
    _store[key] = value;
  }

  @override
  Future<dynamic> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<void> close() async {}
}

class _FakeAuthRepository implements IAuthRepository {
  @override
  Future<Either<Failure, List<UserEntity>>> getAll() async => Right([
    UserEntity(
      username: 'admin',
      passwordHash: '',
      mustChangePassword: false,
      role: UserRole.admin,
      createdAt: DateTime.now(),
    ),
  ]);

  @override
  Future<Either<Failure, UserEntity?>> getByUsername(String username) async =>
      Right(null);

  @override
  Future<Either<Failure, void>> save(UserEntity user) async =>
      const Right(null);

  @override
  Future<Either<Failure, void>> delete(String username) async =>
      const Right(null);
}

class _FakeShiftsRepository implements IShiftsRepository {
  @override
  Future<Either<Failure, ShiftEntity?>> getActiveShift(String username) async =>
      const Right(null);

  @override
  Future<Either<Failure, List<ShiftEntity>>> getByMonth(int year, int month) async =>
      Right([]);

  @override
  Future<Either<Failure, void>> save(ShiftEntity shift) async =>
      const Right(null);
}

final _testUser = UserEntity(
  username: 'admin',
  passwordHash: '',
  mustChangePassword: false,
  role: UserRole.admin,
  createdAt: DateTime.now(),
);

Widget _buildTestApp() {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) {
            final bloc = SettingsBloc(repository: FakeSettingsRepository());
            bloc.add(const LoadSettings());
            return bloc;
          },
        ),
        BlocProvider(
          create: (_) {
            final bloc = InventoryBloc(repository: FakeInventoryRepository());
            bloc.add(const LoadInventory());
            return bloc;
          },
        ),
        BlocProvider(create: (_) => CheckoutBloc()),
        BlocProvider(
          create: (_) => AuthBloc(
            repository: _FakeAuthRepository(),
          )..add(const CheckAuth()),
        ),
        BlocProvider(
          create: (_) => ShiftBloc(
            repository: _FakeShiftsRepository(),
          ),
        ),
      ],
      child: AppShell(user: _testUser),
    ),
  );
}

void main() {
  testWidgets('App renders AppShell with nav rail', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    HydratedBloc.storage = _MockStorage();

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(PhosphorIcons.shoppingCartSimple), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.package), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.chartBar), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.gearSix), findsOneWidget);
  });
}
