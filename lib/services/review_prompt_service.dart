import 'package:bike_control/utils/settings/settings.dart';
import 'package:flutter/foundation.dart';

class ReviewPromptService {
  static const int sessionThreshold = 3;
  static const int snoozeSessions = 10;

  final Settings settings;
  final List<ValueListenable<bool>> trainerConnections;
  final bool isMobilePlatform;

  final ValueNotifier<bool> shouldShowBanner = ValueNotifier(false);

  bool _countedThisLaunch = false;
  final List<VoidCallback> _disposers = [];

  ReviewPromptService({
    required this.settings,
    required this.trainerConnections,
    required this.isMobilePlatform,
  });

  void start() {
    for (final notifier in trainerConnections) {
      void listener() => _onConnectionChanged(notifier);
      notifier.addListener(listener);
      _disposers.add(() => notifier.removeListener(listener));
    }
    _refreshBannerState();
  }

  void _onConnectionChanged(ValueListenable<bool> notifier) {
    if (_countedThisLaunch) return;
    if (notifier.value != true) return;
    _countedThisLaunch = true;
    final next = settings.getReviewSessionCount() + 1;
    settings.setReviewSessionCount(next).then((_) => _refreshBannerState());
  }

  void _refreshBannerState() {
    shouldShowBanner.value = _isEligible();
  }

  bool _isEligible() {
    if (!isMobilePlatform) return false;
    if (settings.getReviewCompleted()) return false;
    final count = settings.getReviewSessionCount();
    if (count < sessionThreshold) return false;
    final dismissedAt = settings.getReviewDismissedAtSessionCount();
    if (dismissedAt != null && count - dismissedAt < snoozeSessions) {
      return false;
    }
    return true;
  }

  Future<void> markCompleted() async {
    await settings.setReviewCompleted(true);
    _refreshBannerState();
  }

  Future<void> dismiss() async {
    await settings.setReviewDismissedAtSessionCount(settings.getReviewSessionCount());
    _refreshBannerState();
  }

  void dispose() {
    for (final d in _disposers) {
      d();
    }
    _disposers.clear();
    shouldShowBanner.dispose();
  }
}
