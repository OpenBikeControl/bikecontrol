class Trial {
  final bool isTrial;
  final int remainingDays;
  final bool isActive;
  final bool isTrialOwnedByThisUser;

  Trial({required this.isTrial, required this.remainingDays, required this.isActive, required this.isTrialOwnedByThisUser});
}
