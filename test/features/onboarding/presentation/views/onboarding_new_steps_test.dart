import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:cashier_system/core/business/business_type.dart';
import 'package:cashier_system/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:cashier_system/features/onboarding/presentation/bloc/onboarding_event.dart';
import 'package:cashier_system/features/onboarding/presentation/bloc/onboarding_state.dart';
import 'package:cashier_system/features/onboarding/presentation/views/onboarding_export_path_screen.dart';
import 'package:cashier_system/features/onboarding/presentation/views/onboarding_printing_screen.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_bloc.dart';
import 'package:cashier_system/features/settings/presentation/bloc/settings_event.dart';
import 'package:cashier_system/features/settings/presentation/widgets/printing_section.dart';
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

Widget _wrap({
  required SettingsBloc settingsBloc,
  required OnboardingBloc onboardingBloc,
  required Widget child,
}) {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider.value(value: settingsBloc),
        BlocProvider.value(value: onboardingBloc),
      ],
      child: child,
    ),
  );
}

SettingsBloc _settingsBloc({String exportPath = r'C:\Exports'}) {
  final bloc = SettingsBloc(repository: FakeSettingsRepository());
  bloc.add(const LoadSettings());
  bloc.add(const LanguageToggled('en'));
  bloc.add(SetExportDirectoryPath(exportPath));
  return bloc;
}

/// Advances a fresh bloc to [step] by dispatching real events.
Future<OnboardingBloc> _blocAt(OnboardingStep step) async {
  final bloc = OnboardingBloc();
  if (step == OnboardingStep.exportPath ||
      step == OnboardingStep.printing ||
      step == OnboardingStep.preferences) {
    bloc.add(const OnboardingSelectBusinessType(BusinessType.cafe));
    await bloc.stream.first;
  }
  if (step == OnboardingStep.exportPath) {
    bloc.add(const OnboardingNextStep());
    await bloc.stream.first;
    bloc.add(const OnboardingNextStep());
    await bloc.stream.first;
    bloc.add(const OnboardingNextStep());
    await bloc.stream.first;
  } else if (step == OnboardingStep.printing) {
    bloc.add(const OnboardingNextStep());
    await bloc.stream.first;
    bloc.add(const OnboardingNextStep());
    await bloc.stream.first;
    bloc.add(const OnboardingNextStep());
    await bloc.stream.first;
    bloc.add(const OnboardingNextStep());
    await bloc.stream.first;
  }
  return bloc;
}

void main() {
  setUp(() {
    HydratedBloc.storage = _MockStorage();
  });

  Future<void> pumpDesktop(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(child);
    await tester.pumpAndSettle();
  }

  Future<void> tapInScroll(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  group('OnboardingExportPathScreen', () {
    testWidgets('prefills current export path', (tester) async {
      final settingsBloc = _settingsBloc(exportPath: r'C:\My\Exports');
      final onboardingBloc = OnboardingBloc();
      addTearDown(settingsBloc.close);
      addTearDown(onboardingBloc.close);

      await pumpDesktop(
        tester,
        _wrap(
          settingsBloc: settingsBloc,
          onboardingBloc: onboardingBloc,
          child: const OnboardingExportPathScreen(),
        ),
      );

      expect(find.widgetWithText(TextField, r'C:\My\Exports'), findsOneWidget);
    });

    testWidgets('Next with unchanged path advances', (tester) async {
      final settingsBloc = _settingsBloc(exportPath: r'C:\Exports');
      final onboardingBloc = await _blocAt(OnboardingStep.exportPath);
      addTearDown(settingsBloc.close);
      addTearDown(onboardingBloc.close);

      await pumpDesktop(
        tester,
        _wrap(
          settingsBloc: settingsBloc,
          onboardingBloc: onboardingBloc,
          child: const OnboardingExportPathScreen(),
        ),
      );

      await tapInScroll(tester, find.text('Next'));
      expect(onboardingBloc.state.step, OnboardingStep.printing);
    });

    testWidgets('Next with valid typed path persists and advances', (
      tester,
    ) async {
      final settingsBloc = _settingsBloc();
      final onboardingBloc = await _blocAt(OnboardingStep.exportPath);
      addTearDown(settingsBloc.close);
      addTearDown(onboardingBloc.close);

      await pumpDesktop(
        tester,
        _wrap(
          settingsBloc: settingsBloc,
          onboardingBloc: onboardingBloc,
          child: const OnboardingExportPathScreen(),
        ),
      );

      final typedPath = Platform.isLinux ? '/home/New/Path' : r'D:\New\Path';
      await tester.enterText(find.byType(TextField), typedPath);
      await tapInScroll(tester, find.text('Next'));

      expect(settingsBloc.state.settings.exportDirectoryPath, typedPath);
      expect(onboardingBloc.state.step, OnboardingStep.printing);
    });

    testWidgets('Next with invalid typed path blocks advance', (tester) async {
      final settingsBloc = _settingsBloc();
      final onboardingBloc = await _blocAt(OnboardingStep.exportPath);
      addTearDown(settingsBloc.close);
      addTearDown(onboardingBloc.close);

      await pumpDesktop(
        tester,
        _wrap(
          settingsBloc: settingsBloc,
          onboardingBloc: onboardingBloc,
          child: const OnboardingExportPathScreen(),
        ),
      );

      await tester.enterText(find.byType(TextField), 'relative/folder');
      await tapInScroll(tester, find.text('Next'));

      expect(onboardingBloc.state.step, OnboardingStep.exportPath);
      expect(find.text('Enter a valid absolute folder path'), findsOneWidget);
    });

    testWidgets('invalid path shows inline error while typing', (tester) async {
      final settingsBloc = _settingsBloc();
      final onboardingBloc = OnboardingBloc();
      addTearDown(settingsBloc.close);
      addTearDown(onboardingBloc.close);

      await pumpDesktop(
        tester,
        _wrap(
          settingsBloc: settingsBloc,
          onboardingBloc: onboardingBloc,
          child: const OnboardingExportPathScreen(),
        ),
      );

      await tester.enterText(find.byType(TextField), 'not-a-path');
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid absolute folder path'), findsOneWidget);
    });

    testWidgets('Back goes to branding, Skip goes to admin setup', (
      tester,
    ) async {
      final settingsBloc = _settingsBloc();
      final onboardingBloc = await _blocAt(OnboardingStep.exportPath);
      addTearDown(settingsBloc.close);
      addTearDown(onboardingBloc.close);

      await pumpDesktop(
        tester,
        _wrap(
          settingsBloc: settingsBloc,
          onboardingBloc: onboardingBloc,
          child: const OnboardingExportPathScreen(),
        ),
      );

      await tapInScroll(tester, find.text('Back'));
      expect(onboardingBloc.state.step, OnboardingStep.branding);

      await tapInScroll(tester, find.text('Skip'));
      expect(onboardingBloc.state.step, OnboardingStep.adminSetup);
    });
  });

  group('OnboardingPrintingScreen', () {
    testWidgets('shows printing section controls', (tester) async {
      final settingsBloc = _settingsBloc();
      final onboardingBloc = OnboardingBloc();
      addTearDown(settingsBloc.close);
      addTearDown(onboardingBloc.close);

      await pumpDesktop(
        tester,
        _wrap(
          settingsBloc: settingsBloc,
          onboardingBloc: onboardingBloc,
          child: const OnboardingPrintingScreen(),
        ),
      );

      expect(find.byType(PrintingSection), findsOneWidget);
      expect(find.text('Printing setup'), findsOneWidget);
    });

    testWidgets('Back returns to exportPath, Next advances to preferences', (
      tester,
    ) async {
      final settingsBloc = _settingsBloc();
      final onboardingBloc = await _blocAt(OnboardingStep.printing);
      addTearDown(settingsBloc.close);
      addTearDown(onboardingBloc.close);

      await pumpDesktop(
        tester,
        _wrap(
          settingsBloc: settingsBloc,
          onboardingBloc: onboardingBloc,
          child: const OnboardingPrintingScreen(),
        ),
      );

      await tapInScroll(tester, find.text('Back'));
      expect(onboardingBloc.state.step, OnboardingStep.exportPath);

      await tapInScroll(tester, find.text('Next'));
      expect(onboardingBloc.state.step, OnboardingStep.printing);

      await tapInScroll(tester, find.text('Next'));
      expect(onboardingBloc.state.step, OnboardingStep.preferences);
    });

    testWidgets('playstation hides barcode printer dropdown', (tester) async {
      final settingsBloc = _settingsBloc();
      settingsBloc.add(const BusinessTypeChanged('playstation'));
      final onboardingBloc = await _blocAt(OnboardingStep.printing);
      addTearDown(settingsBloc.close);
      addTearDown(onboardingBloc.close);

      await pumpDesktop(
        tester,
        _wrap(
          settingsBloc: settingsBloc,
          onboardingBloc: onboardingBloc,
          child: const OnboardingPrintingScreen(),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(PrintingSection),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
        findsNothing,
      );
    });

    testWidgets('retail shows both printer dropdowns', (tester) async {
      final settingsBloc = _settingsBloc();
      final onboardingBloc = await _blocAt(OnboardingStep.printing);
      addTearDown(settingsBloc.close);
      addTearDown(onboardingBloc.close);

      await pumpDesktop(
        tester,
        _wrap(
          settingsBloc: settingsBloc,
          onboardingBloc: onboardingBloc,
          child: const OnboardingPrintingScreen(),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(PrintingSection),
          matching: find.byType(DropdownButtonFormField<String>),
        ),
        findsNWidgets(2),
      );
    });
  });
}
