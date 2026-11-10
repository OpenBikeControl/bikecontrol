// Feedback-routing round: the trainer-feedback buttons on the smart-trainer
// details page ("No difference"/"Not working") used to open a support chat
// directly, prefilled with the tapped label — see proxy_device_details.dart.
// They now route through HelpCenterPage's "Your setup" section instead, but
// the rich diagnostic payload the chat used to get (a
// trainer-specific TelemetrySnapshot builder) must still reach
// SupportChatPage if the rider continues from there into "Tell us what's
// wrong" — ContactCommunitySection uses this value object for that handoff
// instead of gathering its own generic payload from scratch.
//
// Review round: dropped `feedbackKey` — it was threaded through three
// widgets and never read by any production code (the key already reaches
// support inside [telemetryBuilder]'s freetext) — and `diagnosticPreviewFuture`
// as a stored field, since deriving it from [telemetryBuilder] at the point
// [ContactCommunitySection] actually opens the chat is what lets that first
// call be the one and only trigger for the (slow, mDNS-scanning) gather —
// see [telemetryBuilder]'s own doc and `memoizeAsync`.
import 'package:bike_control/pages/support_chat/support_chat_page.dart' show TelemetryBuilder;

/// Bundles the trainer-specific support payload a Help Center entry point
/// (currently only the trainer-feedback buttons) gathered before pushing
/// [HelpCenterPage], so [ContactCommunitySection] can hand the exact same
/// payload to [SupportChatPage] instead of collecting a fresh, generic one.
class HelpCenterSupportContext {
  /// Lazily gathers this trainer's [TelemetrySnapshot] — wrapped in
  /// `memoizeAsync` by the caller, so nothing runs until the first call
  /// (typically [ContactCommunitySection] opening the chat, not the tap that
  /// pushed the Help Center — the rider may never continue that far) and
  /// every call after that shares the same in-flight/completed gather
  /// instead of repeating it, so the composer's diagnostic preview and
  /// whatever telemetry rides along with the first send are the same
  /// snapshot.
  final TelemetryBuilder telemetryBuilder;

  const HelpCenterSupportContext({required this.telemetryBuilder});
}
