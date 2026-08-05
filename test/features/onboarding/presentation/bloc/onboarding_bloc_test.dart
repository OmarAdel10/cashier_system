import 'package:flutter_test/flutter_test.dart';
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

    test('NextStep advances welcome -> features -> adminSetup', () async {
      final bloc = OnboardingBloc();
      bloc.add(const OnboardingNextStep());
      final features = await bloc.stream.first;
      expect(features.step, OnboardingStep.features);
      bloc.add(const OnboardingNextStep());
      final setup = await bloc.stream.first;
      expect(setup.step, OnboardingStep.adminSetup);
      bloc.close();
    });

    test('NextStep is blocked on adminSetup', () async {
      final bloc = OnboardingBloc();
      bloc.add(const OnboardingSkipToSetup());
      final state = await bloc.stream.first;
      expect(state.step, OnboardingStep.adminSetup);

      var extraEmissions = 0;
      final sub = bloc.stream.listen((_) => extraEmissions++);
      bloc.add(const OnboardingNextStep());
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(extraEmissions, 0);
      expect(bloc.state.step, OnboardingStep.adminSetup);
      await sub.cancel();
      bloc.close();
    });

    test('PreviousStep goes adminSetup -> features -> welcome', () async {
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

    test('SkipToSetup jumps to adminSetup from any non-setup step', () async {
      final bloc = OnboardingBloc();
      bloc.add(const OnboardingSkipToSetup());
      final state = await bloc.stream.first;
      expect(state.step, OnboardingStep.adminSetup);
      bloc.close();
    });

    test('SkipToSetup is a no-op on adminSetup', () async {
      final bloc = OnboardingBloc();
      bloc.add(const OnboardingSkipToSetup());
      final state = await bloc.stream.first;
      expect(state.step, OnboardingStep.adminSetup);

      var extraEmissions = 0;
      final sub = bloc.stream.listen((_) => extraEmissions++);
      bloc.add(const OnboardingSkipToSetup());
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(extraEmissions, 0);
      expect(bloc.state.step, OnboardingStep.adminSetup);
      await sub.cancel();
      bloc.close();
    });
  });
}
