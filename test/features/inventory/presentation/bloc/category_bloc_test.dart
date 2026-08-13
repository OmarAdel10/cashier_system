import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/error/failure.dart';
import 'package:flutter/foundation.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/category_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/category_event.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/category_state.dart';
import '../../helpers/fake_category_repository.dart';

void main() {
  late CategoryBloc bloc;
  late FakeCategoryRepository repository;

  setUp(() {
    repository = FakeCategoryRepository();
    bloc = CategoryBloc(repository: repository);
  });

  tearDown(() {
    bloc.close();
  });

  group('initial state', () {
    test('should have initial status with empty categories', () {
      expect(bloc.state.status, CategoryStatus.initial);
      expect(bloc.state.categories, isEmpty);
      expect(bloc.state.failure, isNull);
    });
  });

  group('LoadCategories', () {
    test('should load categories and emit ready state', () async {
      repository.names
        ..add('hot drinks')
        ..add('cold drinks');

      bloc.add(const LoadCategories());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<CategoryState>((s) => s.status == CategoryStatus.loading),
          predicate<CategoryState>((s) {
            final names = s.categories.map((c) => c.name).toList();
            return s.status == CategoryStatus.ready &&
                listEquals(names, ['hot drinks', 'cold drinks']);
          }),
        ]),
      );
    });

    test('should emit error state on failure', () async {
      repository.failOnGet = true;

      bloc.add(const LoadCategories());

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<CategoryState>((s) => s.status == CategoryStatus.loading),
          predicate<CategoryState>(
            (s) =>
                s.status == CategoryStatus.error &&
                s.failure is DatabaseFailure,
          ),
        ]),
      );
    });
  });

  group('AddCategory', () {
    test('should add category and persist it', () async {
      bloc.add(const AddCategory('soda'));

      await expectLater(
        bloc.stream,
        emits(
          predicate<CategoryState>(
            (s) =>
                s.status == CategoryStatus.ready &&
                listEquals(s.categories.map((c) => c.name).toList(), ['soda']),
          ),
        ),
      );
      expect(repository.names, ['soda']);
    });
  });

  group('RenameCategory', () {
    test('should replace old name with new keeping order', () async {
      repository = FakeCategoryRepository(['hot drinks', 'cold drinks']);
      bloc = CategoryBloc(repository: repository);

      bloc.add(
        const RenameCategory(oldName: 'hot drinks', newName: 'hot beverages'),
      );

      await expectLater(
        bloc.stream,
        emits(
          predicate<CategoryState>(
            (s) =>
                s.status == CategoryStatus.ready &&
                listEquals(s.categories.map((c) => c.name).toList(), [
                  'hot beverages',
                  'cold drinks',
                ]),
          ),
        ),
      );
      expect(repository.names, ['hot beverages', 'cold drinks']);
    });
  });

  group('DeleteCategory', () {
    test('should remove category', () async {
      repository = FakeCategoryRepository(['hot drinks', 'cold drinks']);
      bloc = CategoryBloc(repository: repository);

      bloc.add(const DeleteCategory('cold drinks'));

      await expectLater(
        bloc.stream,
        emits(
          predicate<CategoryState>(
            (s) =>
                s.status == CategoryStatus.ready &&
                listEquals(s.categories.map((c) => c.name).toList(), [
                  'hot drinks',
                ]),
          ),
        ),
      );
      expect(repository.names, ['hot drinks']);
    });
  });
}
