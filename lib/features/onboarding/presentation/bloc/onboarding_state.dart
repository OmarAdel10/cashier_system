import '../../../../core/business/business_type.dart';

enum OnboardingStep { welcome, features, businessType, adminSetup }

class OnboardingState {
  const OnboardingState({required this.step, this.businessType});

  final OnboardingStep step;
  final BusinessType? businessType;

  OnboardingState copyWith({
    OnboardingStep? step,
    BusinessType? businessType,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      businessType: businessType ?? this.businessType,
    );
  }
}