class Trial {
  final bool isTrial;
  final String remainingDays;
  final bool isActive;
  final bool isTrialOwnedByThisUser;

  Trial({
    required this.isTrial,
    required this.remainingDays,
    required this.isActive,
    required this.isTrialOwnedByThisUser,
  });

  @override
  String toString() {
    return 'Trial{isTrial: $isTrial, remainingDays: $remainingDays, isActive: $isActive, isTrialOwnedByThisUser: $isTrialOwnedByThisUser}';
  }
}
