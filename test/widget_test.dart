import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:cashier_system/app.dart';
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

void main() {
  testWidgets('App renders AppShell with nav rail', (tester) async {
    HydratedBloc.storage = _MockStorage();

    final repo = FakeSettingsRepository();
    await tester.pumpWidget(App(repository: repo));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.shoppingCartSimple), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.package), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.chartBar), findsOneWidget);
    expect(find.byIcon(PhosphorIcons.gearSix), findsOneWidget);
  });
}
