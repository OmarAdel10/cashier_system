enum OnboardingStep { welcome, features, adminSetup }

class OnboardingState {
  const OnboardingState({required this.step});

  final OnboardingStep step;

  OnboardingState copyWith({OnboardingStep? step}) {
    return OnboardingState(step: step ?? this.step);
  }
}
