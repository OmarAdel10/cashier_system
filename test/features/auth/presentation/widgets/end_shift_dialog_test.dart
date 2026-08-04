import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/features/auth/presentation/widgets/end_shift_dialog.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import '../../../settings/helpers/fake_settings_repository.dart';

class _MockStorage extends Storage {
  final _store = <String, dynamic>{};

  @override
  Future<void> write(String key, dynamic value) async => _store[key] = value;

  @override
  Future<dynamic> read(String key) async => _store[key];

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> clear() async => _store.clear();

  @override
  Future<void> close() async {}
}

Widget _buildApp({void Function(bool? result)? onResult}) {
  final repo = FakeSettingsRepository();
  repo.saveSettings(
    const AppSettingsEntity().copyWith(languageCode: 'en'),
  );
  return BlocProvider(
    create: (_) {
      final bloc = SettingsBloc(repository: repo);
      bloc.add(const LoadSettings());
      return bloc;
    },
    child: MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async {
            final result = await showDialog<bool>(
              context: context,
              builder: (_) => const EndShiftDialog(),
            );
            onResult?.call(result);
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    HydratedBloc.storage = _MockStorage();
  });

  group('EndShiftDialog', () {
    testWidgets('shows localized title and confirmation message', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      expect(find.text('End Shift'), findsWidgets);
      expect(find.text('Are you sure you want to end your shift?'), findsOneWidget);
    });

    testWidgets('pops true on confirm', (tester) async {
      bool? result;
      await tester.pumpWidget(_buildApp(onResult: (r) => result = r));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'End Shift'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('pops false on cancel', (tester) async {
      bool? result;
      await tester.pumpWidget(_buildApp(onResult: (r) => result = r));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });
}
