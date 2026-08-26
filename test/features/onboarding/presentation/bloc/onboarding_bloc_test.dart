import 'package:flutter_test/flutter_test.dart';
import 'package:cashier_system/core/business/business_type.dart';
import 'package:cashier_system/features/onboarding/presentation/bloc/onboarding_bloc.dart';
import 'package:cashier_system/features/onboarding/presentation/bloc/onboarding_event.dart';
import 'package:cashier_system/features/onboarding/presentation/bloc/onboarding_state.dart';

void main() {
  group('OnboardingBloc', () {
    test('initial step is welcome', () {
      final bloc = OnboardingBloc();
      expect(bloc.state.step, OnboardingStep.welcome);
      bloc.close();
    });

    test('NextStep advances welcome -> features -> businessType', () async {
      final bloc = OnboardingBloc();
      bloc.add(const OnboardingNextStep());
      final features = await bloc.stream.first;
      expect(features.step, OnboardingStep.features);
      bloc.add(const OnboardingNextStep());
      final setup = await bloc.stream.first;
      expect(setup.step, OnboardingStep.businessType);
      bloc.close();
    });

    test('NextStep advances through storeInfo -> branding -> exportPath -> '
        'printing -> preferences -> adminSetup', () async {
      final bloc = OnboardingBloc();
      bloc.add(const OnboardingSelectBusinessType(BusinessType.cafe));
      await bloc.stream.first;
      bloc.add(const OnboardingNextStep());
      final storeInfo = await bloc.stream.first;
      expect(storeInfo.step, OnboardingStep.storeInfo);
      bloc.add(const OnboardingNextStep());
      final branding = await bloc.stream.first;
      expect(branding.step, OnboardingStep.branding);
      bloc.add(const OnboardingNextStep());
      final exportPath = await bloc.stream.first;
      expect(exportPath.step, OnboardingStep.exportPath);
      bloc.add(const OnboardingNextStep());
      final printing = await bloc.stream.first;
      expect(printing.step, OnboardingStep.printing);
      bloc.add(const OnboardingNextStep());
      final preferences = await bloc.stream.first;
      expect(preferences.step, OnboardingStep.preferences);
      bloc.add(const OnboardingNextStep());
      final adminSetup = await bloc.stream.first;
      expect(adminSetup.step, OnboardingStep.adminSetup);
      bloc.close();
    });

    test('NextStep is blocked on adminSetup', () async {
      final bloc = OnboardingBloc();
      bloc.add(const OnboardingSelectBusinessType(BusinessType.cafe));
      await bloc.stream.first;
      for (var i = 0; i < 6; i++) {
        bloc.add(const OnboardingNextStep());
        await bloc.stream.first;
      }
      expect(bloc.state.step, OnboardingStep.adminSetup);

      var extraEmissions = 0;
      final sub = bloc.stream.listen((_) => extraEmissions++);
      bloc.add(const OnboardingNextStep());
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(extraEmissions, 0);
      expect(bloc.state.step, OnboardingStep.adminSetup);
      await sub.cancel();
      bloc.close();
    });

    test('PreviousStep goes businessType -> features -> welcome', () async {
      final bloc = OnboardingBloc();
      bloc.add(const OnboardingSkipToSetup());
      await bloc.stream.first;
      bloc.add(const OnboardingPreviousStep());
      final features = await bloc.stream.first;
      expect(features.step, OnboardingStep.features);
      bloc.add(const OnboardingPreviousStep());
      final welcome = await bloc.stream.first;
      expect(welcome.step, OnboardingStep.welcome);
      bloc.close();
    });

    test('PreviousStep walks adminSetup back to businessType', () async {
      final bloc = OnboardingBloc();
      bloc.add(const OnboardingSelectBusinessType(BusinessType.cafe));
      await bloc.stream.first;
      for (var i = 0; i < 6; i++) {
        bloc.add(const OnboardingNextStep());
        await bloc.stream.first;
      }
      expect(bloc.state.step, OnboardingStep.adminSetup);

      bloc.add(const OnboardingPreviousStep());
      final preferences = await bloc.stream.first;
      expect(preferences.step, OnboardingStep.preferences);
      bloc.add(const OnboardingPreviousStep());
      final printing = await bloc.stream.first;
      expect(printing.step, OnboardingStep.printing);
      bloc.add(const OnboardingPreviousStep());
      final exportPath = await bloc.stream.first;
      expect(exportPath.step, OnboardingStep.exportPath);
      bloc.add(const OnboardingPreviousStep());
      final branding = await bloc.stream.first;
      expect(branding.step, OnboardingStep.branding);
      bloc.add(const OnboardingPreviousStep());
      final storeInfo = await bloc.stream.first;
      expect(storeInfo.step, OnboardingStep.storeInfo);
      bloc.add(const OnboardingPreviousStep());
      final businessType = await bloc.stream.first;
      expect(businessType.step, OnboardingStep.businessType);
      bloc.close();
    });

    test('PreviousStep is blocked on welcome', () async {
      final bloc = OnboardingBloc();
      var extraEmissions = 0;
      final sub = bloc.stream.listen((_) => extraEmissions++);
      bloc.add(const OnboardingPreviousStep());
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(extraEmissions, 0);
      expect(bloc.state.step, OnboardingStep.welcome);
      await sub.cancel();
      bloc.close();
    });

    test(
      'SkipToSetup jumps to businessType from any non-business-type step',
      () async {
        final bloc = OnboardingBloc();
        bloc.add(const OnboardingSkipToSetup());
        final state = await bloc.stream.first;
        expect(state.step, OnboardingStep.businessType);
        bloc.close();
      },
    );

    test('SkipToSetup from storeInfo lands on adminSetup', () async {
      final bloc = OnboardingBloc();
      bloc.add(const OnboardingSelectBusinessType(BusinessType.cafe));
      await bloc.stream.first;
      bloc.add(const OnboardingNextStep());
      final storeInfo = await bloc.stream.first;
      expect(storeInfo.step, OnboardingStep.storeInfo);
      bloc.add(const OnboardingSkipToSetup());
      final state = await bloc.stream.first;
      expect(state.step, OnboardingStep.adminSetup);
      bloc.close();
    });

    test('SkipToSetup from branding lands on adminSetup', () async {
      final bloc = OnboardingBloc();
      bloc.add(const OnboardingSelectBusinessType(BusinessType.cafe));
      await bloc.stream.first;
      bloc.add(const OnboardingNextStep());
      await bloc.stream.first;
      bloc.add(const OnboardingNextStep());
      final branding = await bloc.stream.first;
      expect(branding.step, OnboardingStep.branding);
      bloc.add(const OnboardingSkipToSetup());
      final state = await bloc.stream.first;
      expect(state.step, OnboardingStep.adminSetup);
      bloc.close();
    });

    test('SkipToSetup from preferences lands on adminSetup', () async {
      final bloc = OnboardingBloc();
      bloc.add(const OnboardingSelectBusinessType(BusinessType.cafe));
      await bloc.stream.first;
      for (var i = 0; i < 5; i++) {
        bloc.add(const OnboardingNextStep());
        await bloc.stream.first;
      }
      expect(bloc.state.step, OnboardingStep.preferences);
      bloc.add(const OnboardingSkipToSetup());
      final state = await bloc.stream.first;
      expect(state.step, OnboardingStep.adminSetup);
      bloc.close();
    });

    test('SkipToSetup from adminSetup returns to businessType', () async {
      final bloc = OnboardingBloc();
      bloc.add(const OnboardingSelectBusinessType(BusinessType.cafe));
      await bloc.stream.first;
      for (var i = 0; i < 6; i++) {
        bloc.add(const OnboardingNextStep());
        await bloc.stream.first;
      }
      expect(bloc.state.step, OnboardingStep.adminSetup);
      bloc.add(const OnboardingSkipToSetup());
      final state = await bloc.stream.first;
      expect(state.step, OnboardingStep.businessType);
      bloc.close();
    });
  });

  group('businessType required step', () {
    test('NextStep goes features -> businessType', () async {
      final bloc = OnboardingBloc();
      bloc.add(const OnboardingNextStep());
      await bloc.stream.first;
      bloc.add(const OnboardingNextStep());
      final state = await bloc.stream.first;
      expect(state.step, OnboardingStep.businessType);
      bloc.close();
    });

    test('NextStep is blocked on businessType without selection', () async {
      final bloc = OnboardingBloc();
      bloc.add(const OnboardingNextStep());
      await bloc.stream.first;
      bloc.add(const OnboardingNextStep());
      await bloc.stream.first;
      expect(bloc.state.step, OnboardingStep.businessType);

      var extraEmissions = 0;
      final sub = bloc.stream.listen((_) => extraEmissions++);
      bloc.add(const OnboardingNextStep());
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(extraEmissions, 0);
      expect(bloc.state.step, OnboardingStep.businessType);
      await sub.cancel();
      bloc.close();
    });

    test('selecting business type then NextStep goes to storeInfo', () async {
      final bloc = OnboardingBloc();
      bloc.add(const OnboardingSelectBusinessType(BusinessType.cafe));
      final selected = await bloc.stream.first;
      expect(selected.step, OnboardingStep.businessType);
      expect(selected.businessType, BusinessType.cafe);
      bloc.add(const OnboardingNextStep());
      final state = await bloc.stream.first;
      expect(state.step, OnboardingStep.storeInfo);
      bloc.close();
    });

    test('PreviousStep goes businessType -> features', () async {
      final bloc = OnboardingBloc();
      bloc.add(const OnboardingNextStep());
      await bloc.stream.first;
      bloc.add(const OnboardingNextStep());
      await bloc.stream.first;
      bloc.add(const OnboardingPreviousStep());
      final state = await bloc.stream.first;
      expect(state.step, OnboardingStep.features);
      bloc.close();
    });

    test('PreviousStep goes storeInfo -> businessType', () async {
      final bloc = OnboardingBloc();
      bloc.add(const OnboardingSelectBusinessType(BusinessType.cafe));
      await bloc.stream.first;
      bloc.add(const OnboardingNextStep());
      final storeInfo = await bloc.stream.first;
      expect(storeInfo.step, OnboardingStep.storeInfo);
      bloc.add(const OnboardingPreviousStep());
      final state = await bloc.stream.first;
      expect(state.step, OnboardingStep.businessType);
      bloc.close();
    });

    test(
      'SkipToSetup from features lands on businessType, not adminSetup',
      () async {
        final bloc = OnboardingBloc();
        bloc.add(const OnboardingNextStep());
        await bloc.stream.first;
        bloc.add(const OnboardingSkipToSetup());
        final state = await bloc.stream.first;
        expect(state.step, OnboardingStep.businessType);
        bloc.close();
      },
    );

    test('SkipToSetup stays on businessType when already there', () async {
      final bloc = OnboardingBloc();
      bloc.add(const OnboardingNextStep());
      await bloc.stream.first;
      bloc.add(const OnboardingNextStep());
      await bloc.stream.first;
      expect(bloc.state.step, OnboardingStep.businessType);

      var extraEmissions = 0;
      final sub = bloc.stream.listen((_) => extraEmissions++);
      bloc.add(const OnboardingSkipToSetup());
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(extraEmissions, 0);
      expect(bloc.state.step, OnboardingStep.businessType);
      await sub.cancel();
      bloc.close();
    });
  });
}
