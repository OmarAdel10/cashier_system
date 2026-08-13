import 'package:cashier_system/core/theme/expense_colors.dart';
import 'package:cashier_system/features/settings/data/services/localization_service.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../../../settings/helpers/fake_settings_repository.dart';
import 'package:cashier_system/features/settings/domain/entities/app_settings_entity.dart';

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

void main() {
  late SettingsBloc settingsBloc;

  setUp(() {
    HydratedBloc.storage = _MockStorage();
    settingsBloc = SettingsBloc(
      repository: FakeSettingsRepository(
        const AppSettingsEntity(languageCode: 'en'),
      ),
    );
    settingsBloc.add(LoadSettings());
  });

  tearDown(() {
    settingsBloc.close();
  });

  testWidgets('expense button renders with accent color', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BlocProvider.value(
            value: settingsBloc,
            child: Builder(
              builder: (context) {
                final t = LocalizationService();
                final langCode = context.select<SettingsBloc, String>(
                  (s) => s.state.settings.languageCode,
                );
                return OutlinedButton.icon(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ExpenseColors.accent,
                    side: const BorderSide(color: ExpenseColors.accent),
                  ),
                  icon: const Icon(
                    Icons.account_balance_wallet_outlined,
                    size: 18,
                  ),
                  label: Text(
                    t.translate('expense.title', languageCode: langCode),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Expenses'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.style?.foregroundColor?.resolve({}), ExpenseColors.accent);
  });
}
