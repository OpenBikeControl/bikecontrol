import 'package:bike_control/gen/l10n.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Dismissible "Need help?" pointer on the trainer page.
///
/// Replaces the old three-button feedback box: "Works" never told support
/// anything actionable, and "No difference"/"Not working" were two doors into
/// the same Help Center route — so this is one CTA into that route plus a
/// close button. Purely presentational: the page owns both the route (it has
/// the device to build the telemetry payload from) and the persisted
/// dismissal, so a dismissed card is simply never built.
class NeedHelpCard extends StatelessWidget {
  /// Wired by the page to its Help Center route, same pattern as
  /// [SelfTestCard.onShowOverlaySettings].
  final Future<void> Function() onOpenHelp;

  final VoidCallback onDismiss;

  const NeedHelpCard({super.key, required this.onOpenHelp, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    // Mirrors SelfTestCard's frame so the two read as siblings on the page.
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            spacing: 8,
            children: [
              const Icon(LucideIcons.lifeBuoy, size: 18),
              Expanded(
                child: Text(l10n.needHelpTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
              IconButton.ghost(
                key: const ValueKey('need-help-dismiss'),
                // Compact so the 18px glyph doesn't inflate the header row
                // above the self-test card's.
                density: ButtonDensity.compact,
                icon: Icon(LucideIcons.x, size: 18, color: cs.mutedForeground),
                onPressed: onDismiss,
              ),
            ],
          ),
          Text(l10n.needHelpBody, style: TextStyle(fontSize: 13, color: cs.mutedForeground)),
          Button.primary(
            key: const ValueKey('need-help-open'),
            onPressed: onOpenHelp,
            child: Text(l10n.needHelpOpen),
          ),
        ],
      ),
    );
  }
}
