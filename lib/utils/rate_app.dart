import 'package:bike_control/main.dart' show recordError;
import 'package:bike_control/services/feedback_prompt_service.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

/// Asks for a store rating after the user tapped a "rate" / "leave a review"
/// action.
///
/// On Android this opens the Play Store listing directly: Play's in-app review
/// sheet is quota-limited and reports success even when it shows nothing, so a
/// tap would silently do nothing. Elsewhere the in-app sheet is requested,
/// falling back to the store listing when it isn't available.
Future<void> requestAppRating() async {
  final review = InAppReview.instance;
  if (defaultTargetPlatform != TargetPlatform.android && await review.isAvailable()) {
    await review.requestReview();
  } else {
    await review.openStoreListing(appStoreId: 'id6753721284', microsoftStoreId: '9NP42GS03Z26');
  }
}

/// Asks for the native rating sheet without anybody having tapped anything —
/// the automatic prompt [FeedbackPromptService] decides the timing of.
///
/// Unlike [requestAppRating], this never falls back to opening the store
/// listing: a rider who tapped "rate" must see *something*, but throwing a
/// rider who tapped nothing out of the app and into the store is worse than
/// not asking at all. On Android that means the quota-limited in-app sheet
/// may silently show nothing — an acceptable no-op for a prompt nobody
/// asked for; the ask simply comes round again in a later launch.
///
/// Returns whether the sheet was actually requested.
Future<bool> requestAppRatingSheet() async {
  final review = InAppReview.instance;
  if (!await review.isAvailable()) return false;
  await review.requestReview();
  return true;
}

/// The automatic prompt's whole action: the native rating sheet, straight
/// up, with no in-app dialog of ours in front of it.
///
/// [FeedbackPromptService.markCompleted] only runs when the sheet was really
/// requested ([requestAppRatingSheet] returning true). The store never tells
/// us whether the rider went through with a rating — "we asked" is the most
/// we can know — but it does tell us when it showed nothing at all, and
/// burning the one-and-only ask on that would be a silent loss.
Future<void> showAutomaticRatingPrompt(
  FeedbackPromptService service, {
  Future<bool> Function() requestSheet = requestAppRatingSheet,
}) async {
  try {
    if (!await requestSheet()) return;
    await service.markCompleted();
  } catch (e, s) {
    await recordError(e, s, context: 'showAutomaticRatingPrompt');
  }
}
