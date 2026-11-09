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
