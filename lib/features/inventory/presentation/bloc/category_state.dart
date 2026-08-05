import '../../../../core/error/failure.dart';
import '../../domain/entities/product_category_entity.dart';

enum CategoryStatus { initial, loading, ready, error }

class CategoryState {
  final CategoryStatus status;
  final List<ProductCategory> categories;
  final Failure? failure;

  const CategoryState({
    this.status = CategoryStatus.initial,
    this.categories = const [],
    this.failure,
  });

  CategoryState copyWith({
    CategoryStatus? status,
    List<ProductCategory>? categories,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return CategoryState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      failure: clearFailure ? null : failure ?? this.failure,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CategoryState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          categories == other.categories &&
          failure == other.failure;

  @override
  int get hashCode => status.hashCode ^ categories.hashCode ^ failure.hashCode;
}