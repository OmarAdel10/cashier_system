sealed class OnboardingEvent {
  const OnboardingEvent();
}

final class OnboardingNextStep extends OnboardingEvent {
  const OnboardingNextStep();
}

final class OnboardingPreviousStep extends OnboardingEvent {
  const OnboardingPreviousStep();
}

final class OnboardingSkipToSetup extends OnboardingEvent {
  const OnboardingSkipToSetup();
}
