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
            OnboardingStep.adminSetup => const OnboardingSetupScreen(),
          };
        },
      ),
    );
  }
}
