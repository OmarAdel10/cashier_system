import 'package:flutter_bloc/flutter_bloc.dart';

import 'onboarding_event.dart';
import 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc() : super(const OnboardingState(step: OnboardingStep.welcome)) {
    on<OnboardingNextStep>(_onNextStep);
    on<OnboardingPreviousStep>(_onPreviousStep);
    on<OnboardingSkipToSetup>(_onSkipToSetup);
    on<OnboardingSelectBusinessType>(_onSelectBusinessType);
  }

  void _onNextStep(OnboardingNextStep event, Emitter<OnboardingState> emit) {
    switch (state.step) {
      case OnboardingStep.welcome:
        emit(state.copyWith(step: OnboardingStep.features));
      case OnboardingStep.features:
        emit(state.copyWith(step: OnboardingStep.businessType));
      case OnboardingStep.businessType:
        if (state.businessType != null) {
          emit(state.copyWith(step: OnboardingStep.adminSetup));
        }
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
      case OnboardingStep.businessType:
        emit(state.copyWith(step: OnboardingStep.features));
      case OnboardingStep.adminSetup:
        emit(state.copyWith(step: OnboardingStep.businessType));
    }
  }

  void _onSkipToSetup(
      OnboardingSkipToSetup event, Emitter<OnboardingState> emit) {
    // Skip must land on the required business-type step, never past it.
    if (state.step != OnboardingStep.businessType) {
      emit(state.copyWith(step: OnboardingStep.businessType));
    }
  }

  void _onSelectBusinessType(
      OnboardingSelectBusinessType event, Emitter<OnboardingState> emit) {
    emit(state.copyWith(
      step: OnboardingStep.businessType,
      businessType: event.businessType,
    ));
  }
}
