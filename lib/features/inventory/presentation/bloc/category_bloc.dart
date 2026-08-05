import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/error/failure.dart';
import '../../domain/repositories/i_category_repository.dart';
import 'category_event.dart';
import 'category_state.dart';

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  final ICategoryRepository _repository;

  CategoryBloc({required ICategoryRepository repository})
    : _repository = repository,
      super(const CategoryState()) {
    on<LoadCategories>(_onLoadCategories);
    on<AddCategory>(_onAddCategory);
    on<RenameCategory>(_onRenameCategory);
    on<DeleteCategory>(_onDeleteCategory);
  }

  Future<void> _onLoadCategories(
    LoadCategories event,
    Emitter<CategoryState> emit,
  ) async {
    emit(state.copyWith(status: CategoryStatus.loading, clearFailure: true));
    try {
      final list = await _repository.getCategories();
      emit(
        state.copyWith(
          status: CategoryStatus.ready,
          categories: list,
          clearFailure: true,
        ),
      );
    } catch (cause) {
      emit(
        state.copyWith(
          status: CategoryStatus.error,
          failure: DatabaseFailure('Failed to load categories', cause: cause),
        ),
      );
    }
  }

  Future<void> _onAddCategory(
    AddCategory event,
    Emitter<CategoryState> emit,
  ) async {
    try {
      await _repository.addCategory(event.name);
      final list = await _repository.getCategories();
      emit(
        state.copyWith(
          status: CategoryStatus.ready,
          categories: list,
          clearFailure: true,
        ),
      );
    } catch (cause) {
      emit(
        state.copyWith(
          status: CategoryStatus.error,
          failure: DatabaseFailure('Failed to add category', cause: cause),
        ),
      );
    }
  }

  Future<void> _onRenameCategory(
    RenameCategory event,
    Emitter<CategoryState> emit,
  ) async {
    try {
      await _repository.renameCategory(event.oldName, event.newName);
      final list = await _repository.getCategories();
      emit(
        state.copyWith(
          status: CategoryStatus.ready,
          categories: list,
          clearFailure: true,
        ),
      );
    } catch (cause) {
      emit(
        state.copyWith(
          status: CategoryStatus.error,
          failure: DatabaseFailure('Failed to rename category', cause: cause),
        ),
      );
    }
  }

  Future<void> _onDeleteCategory(
    DeleteCategory event,
    Emitter<CategoryState> emit,
  ) async {
    try {
      await _repository.deleteCategory(event.name);
      final list = await _repository.getCategories();
      emit(
        state.copyWith(
          status: CategoryStatus.ready,
          categories: list,
          clearFailure: true,
        ),
      );
    } catch (cause) {
      emit(
        state.copyWith(
          status: CategoryStatus.error,
          failure: DatabaseFailure('Failed to delete category', cause: cause),
        ),
      );
    }
  }
}
