import 'package:bike_control/pages/onboarding/onboarding_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('three steps, advancing linearly', () {
    expect(OnboardingStep.values, [OnboardingStep.app, OnboardingStep.gear, OnboardingStep.ride]);
    expect(onboardingNextStep(OnboardingStep.app), OnboardingStep.gear);
    expect(onboardingNextStep(OnboardingStep.gear), OnboardingStep.ride);
    expect(onboardingPreviousStep(OnboardingStep.ride), OnboardingStep.gear);
  });

  test('ride does not advance, app does not go back', () {
    expect(onboardingNextStep(OnboardingStep.ride), OnboardingStep.ride);
    expect(onboardingPreviousStep(OnboardingStep.app), OnboardingStep.app);
  });
}
