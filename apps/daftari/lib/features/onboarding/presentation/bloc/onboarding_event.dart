import '../../../../core/business/business_type.dart';

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

final class OnboardingSelectBusinessType extends OnboardingEvent {
  final BusinessType businessType;
  const OnboardingSelectBusinessType(this.businessType);
}
