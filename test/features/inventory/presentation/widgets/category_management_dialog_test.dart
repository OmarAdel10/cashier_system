import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/category_bloc.dart';
import 'package:cashier_system/features/inventory/presentation/bloc/category_event.dart';
import 'package:cashier_system/features/inventory/presentation/widgets/category_management_dialog.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import '../../helpers/fake_category_repository.dart';
import '../../../settings/helpers/fake_settings_repository.dart';

const _manageLabel = 'إدارة الفئات';
const _addLabel = 'إضافة فئة';
const _addHint = 'اسم الفئة الجديدة';
const _renameLabel = 'إعادة التسمية';
const _saveLabel = 'حفظ';
const _deleteConfirm = 'حذف هذه الفئة؟';
const _cancelLabel = 'إلغاء';

void main() {
  late FakeCategoryRepository repository;
  late CategoryBloc bloc;

  setUp(() {
    repository = FakeCategoryRepository(['hot drinks', 'cold drinks']);
    bloc = CategoryBloc(repository: repository)..add(const LoadCategories());
  });

  tearDown(() {
    bloc.close();
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: MultiBlocProvider(
        providers: [
          BlocProvider<CategoryBloc>.value(value: bloc),
          BlocProvider<SettingsBloc>(
            create: (_) {
              final sBloc = SettingsBloc(repository: FakeSettingsRepository());
              sBloc.add(const LoadSettings());
              return sBloc;
            },
          ),
        ],
        child: const Scaffold(body: Center(child: CategoryManagementDialog())),
      ),
    );
  }

  testWidgets('renders all categories', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text(_manageLabel), findsOneWidget);
    expect(find.text('hot drinks'), findsOneWidget);
    expect(find.text('cold drinks'), findsOneWidget);
  });

  testWidgets('adds a category and shows it in the list', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, _addHint), 'soda');
    await tester.tap(find.text(_addLabel));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(repository.names, contains('soda'));
    expect(find.text('soda'), findsOneWidget);
  });

  testWidgets('renames a category inline', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(_renameLabel).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'hot beverages');
    await tester.tap(find.byTooltip(_saveLabel).first);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(repository.names, contains('hot beverages'));
    expect(repository.names, isNot(contains('hot drinks')));
    expect(find.text('hot beverages'), findsOneWidget);
  });

  testWidgets('deletes a category after inline confirmation', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text(_deleteConfirm), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'حذف'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(repository.names, isNot(contains('hot drinks')));
    expect(find.text('hot drinks'), findsNothing);
  });

  testWidgets('cancel keeps the category', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, _cancelLabel));
    await tester.pumpAndSettle();

    expect(repository.names, contains('hot drinks'));
    expect(find.text(_deleteConfirm), findsNothing);
  });
}
