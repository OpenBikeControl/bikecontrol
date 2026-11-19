/// The wizard's three screens: which app (and where it runs), the controller
/// and trainer, then linking the app and riding.
enum OnboardingStep { app, gear, ride }

/// Sub-phases of the controller part of the gear step. "Connected" is not a
/// phase — it is derived live from `core.connection.controllerDevices` so
/// auto-connect can flip the UI at any moment.
enum ControllerPhase { permission, scanning, empty, list }

OnboardingStep onboardingNextStep(OnboardingStep step) =>
    step == OnboardingStep.ride ? OnboardingStep.ride : OnboardingStep.values[step.index + 1];

OnboardingStep onboardingPreviousStep(OnboardingStep step) =>
    step == OnboardingStep.app ? OnboardingStep.app : OnboardingStep.values[step.index - 1];
