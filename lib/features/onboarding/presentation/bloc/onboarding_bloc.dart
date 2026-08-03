import 'package:flutter_bloc/flutter_bloc.dart';

import 'onboarding_event.dart';
import 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc() : super(const OnboardingState(step: OnboardingStep.welcome)) {
    on<OnboardingNextStep>(_onNextStep);
    on<OnboardingPreviousStep>(_onPreviousStep);
    on<OnboardingSkipToSetup>(_onSkipToSetup);
  }

  void _onNextStep(OnboardingNextStep event, Emitter<OnboardingState> emit) {
    switch (state.step) {
      case OnboardingStep.welcome:
        emit(state.copyWith(step: OnboardingStep.features));
      case OnboardingStep.features:
        emit(state.copyWith(step: OnboardingStep.adminSetup));
      case OnboardingStep.adminSetup:
        break; // required step: no next
    }
  }

  void _onPreviousStep(
      OnboardingPreviousStep event, Emitter<OnboardingState> emit) {
    switch (state.step) {
      case OnboardingStep.welcome:
        break; // first screen: no back
      case OnboardingStep.features:
        emit(state.copyWith(step: OnboardingStep.welcome));
      case OnboardingStep.adminSetup:
        emit(state.copyWith(step: OnboardingStep.features));
    }
  }

  void _onSkipToSetup(
      OnboardingSkipToSetup event, Emitter<OnboardingState> emit) {
    if (state.step != OnboardingStep.adminSetup) {
      emit(state.copyWith(step: OnboardingStep.adminSetup));
    }
  }
}
