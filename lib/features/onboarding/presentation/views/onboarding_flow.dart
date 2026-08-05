import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/onboarding_bloc.dart';
import '../bloc/onboarding_state.dart';
import 'onboarding_features_screen.dart';
import 'onboarding_setup_screen.dart';
import 'onboarding_welcome_screen.dart';

class OnboardingFlow extends StatelessWidget {
  const OnboardingFlow({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<OnboardingBloc>(
      create: (_) => OnboardingBloc(),
      child: BlocBuilder<OnboardingBloc, OnboardingState>(
        builder: (context, state) {
          return switch (state.step) {
            OnboardingStep.welcome => const OnboardingWelcomeScreen(),
            OnboardingStep.features => const OnboardingFeaturesScreen(),
            OnboardingStep.businessType => const _BusinessTypePlaceholder(),
            OnboardingStep.adminSetup => const OnboardingSetupScreen(),
          };
        },
      ),
    );
  }
}

// Temporary until the business-type selection screen lands in a later task.
class _BusinessTypePlaceholder extends StatelessWidget {
  const _BusinessTypePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Business type selection')),
    );
  }
}
