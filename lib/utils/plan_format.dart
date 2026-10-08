import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/models/subscription_term.dart';
import 'package:intl/intl.dart';

/// A plan date ("4.11.2026") in the app's language.
String formatPlanDate(DateTime date) => DateFormat.yMd(Intl.getCurrentLocale()).format(date.toLocal());

/// How long ago [time] was, in the app's language: "Just now", "5 min ago",
/// "3 h ago", "2 days ago".
String formatRelativeTime(AppLocalizations l10n, DateTime time, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(time);
  if (diff.inMinutes < 1) return l10n.justNow;
  if (diff.inMinutes < 60) return l10n.relativeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.relativeHoursAgo(diff.inHours);
  return l10n.relativeDaysAgo(diff.inDays);
}

/// The one line about the subscription's end: "Renews on …" only when the
/// store says so, else "Active until …", "Trial until …" or the payment
/// problem. Null when there is no date to state.
String? subscriptionTermLine(AppLocalizations l10n, SubscriptionTerm term) {
  if (term.renewal == SubscriptionRenewal.billingIssue) return l10n.subscriptionBillingIssue;
  final until = term.until;
  if (until == null) return null;
  final date = formatPlanDate(until);
  return switch (term.renewal) {
    SubscriptionRenewal.renews => l10n.subscriptionRenewsOn(date),
    SubscriptionRenewal.trial => l10n.subscriptionTrialUntil(date),
    _ => l10n.subscriptionActiveUntil(date),
  };
}
