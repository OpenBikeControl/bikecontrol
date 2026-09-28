// A small, reusable "help answer" bottom sheet for Your Setup's explainer
// entries — "Shifting works but the gear doesn't move", "My controller keeps
// disconnecting" and "My controller isn't found" (see your_setup_section.dart)
// all open one of these rather than growing three bespoke sheets.
//
// Follows the same visual language as onboarding_sheets.dart's help sheet: a
// StageBadge icon, an h4 title, a muted body, and 0-2 follow-up actions
// rendered as Button.card rows — an external-link icon trailing a URL action,
// a chevron trailing an in-app navigation. Opening a URL leaves the sheet
// open behind it (matches onboarding_sheets.dart's `_channel`); an in-app
// navigation closes the sheet first so the destination page never opens
// underneath a still-visible sheet (matches the same file's "Dismiss the
// sheet first ... the page must not open underneath a still-visible sheet"
// idiom for `NetworkTroubleshootingPage`/support chat).
import 'package:bike_control/pages/help_center/help_checks.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/guided_operation_sheet.dart' show StageBadge;
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// One follow-up action inside a [HelpAnswerSheet]. [id] is a stable,
/// non-localized identifier used only to key the rendered row for tests —
/// never shown to the rider. Supply exactly one of [HelpAnswerAction.link]
/// (opened externally) or [HelpAnswerAction.navigate] (an in-app push).
class HelpAnswerAction {
  final String id;
  final String label;
  final IconData icon;
  final String? url;
  final VoidCallback? onPressed;

  const HelpAnswerAction.link({required this.id, required this.label, required this.icon, required this.url})
    : onPressed = null;

  const HelpAnswerAction.navigate({
    required this.id,
    required this.label,
    required this.icon,
    required this.onPressed,
  }) : url = null;
}

/// Opens a [HelpAnswerSheet] as a bottom sheet.
Future<void> openHelpAnswerSheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String body,
  List<HelpCheck> checks = const [],
  List<HelpAnswerAction> actions = const [],
}) {
  return openSheet<void>(
    context: context,
    position: OverlayPosition.bottom,
    builder: (sheetContext) => HelpAnswerSheet(icon: icon, title: title, body: body, checks: checks, actions: actions),
  );
}

class HelpAnswerSheet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  /// Numbered checks shown under [body], for answers that are a sequence of
  /// things to try.
  final List<HelpCheck> checks;
  final List<HelpAnswerAction> actions;

  const HelpAnswerSheet({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.checks = const [],
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StageBadge(
                  icon: icon,
                  tone: Theme.of(context).colorScheme.primary,
                  wash: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  reduceMotion: reduceMotion,
                ),
                const Gap(14),
                Text(title).h4,
                const Gap(8),
                Text(body).small.muted,
                if (checks.isNotEmpty) ...[const Gap(12), HelpCheckList(checks: _closingFirst(context, checks))],
                if (actions.isNotEmpty) ...[
                  const Gap(16),
                  for (final action in actions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Button.card(
                        key: ValueKey('help-answer-action-${action.id}'),
                        onPressed: () => _run(context, action),
                        child: Row(
                          children: [
                            Icon(action.icon, size: 18),
                            const Gap(12),
                            Expanded(child: Text(action.label).small.semiBold),
                            Icon(action.url != null ? LucideIcons.externalLink : LucideIcons.chevronRight, size: 14),
                          ],
                        ),
                      ),
                    ),
                ],
                const Gap(8),
                Align(
                  alignment: Alignment.centerRight,
                  child: Button.ghost(
                    key: const ValueKey('help-answer-close'),
                    onPressed: () => closeSheet(context),
                    child: Text(context.i18n.close),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// A check's in-app action closes the sheet before it navigates, like
  /// [HelpAnswerAction.navigate].
  static List<HelpCheck> _closingFirst(BuildContext context, List<HelpCheck> checks) => [
    for (final check in checks)
      if (check.onAction case final onAction? when check.actionLabel != null && check.actionIcon != null)
        check.withAction(
          key: check.actionKey,
          label: check.actionLabel!,
          icon: check.actionIcon!,
          onPressed: () {
            closeSheet(context);
            onAction();
          },
        )
      else
        check,
  ];

  void _run(BuildContext context, HelpAnswerAction action) {
    final url = action.url;
    if (url != null) {
      launchUrlString(url, mode: LaunchMode.externalApplication);
      return;
    }
    // In-app navigation: close the sheet first so the destination never
    // opens underneath a still-visible sheet.
    closeSheet(context);
    action.onPressed?.call();
  }
}
