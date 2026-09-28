import 'package:bike_control/pages/click_v2_onboarding.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/widgets/status_icon.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Placeholder for a discovered-but-not-yet-connected Zwift Click V2.
///
/// The header is faded to signal "not live yet"; the call to action keeps full
/// strength so it does not read as a disabled card. One card stands in for the
/// whole controller, however many of its two sides are in range — the unlock
/// mode is a single decision about a single device.
class ClickV2OnboardingCard extends StatelessWidget {
  /// Invoked after the onboarding page is popped, so the caller can refresh
  /// the device list even on a path that never fires a connectionStream event
  /// (e.g. the CTA's connect attempt throws, or there was nothing pending by
  /// the time the rider chose) — otherwise this stale card would persist.
  final VoidCallback? onCompleted;
  const ClickV2OnboardingCard({super.key, this.onCompleted});

  @override
  Widget build(BuildContext context) {
    final l10n = context.i18n;
    // No Card here: the enclosing "Controller" panel already provides the
    // card, and sibling device entries (_buildDeviceCard in
    // lib/pages/device.dart) render flush against it too, via Button.ghost's
    // own padding. Match that padding by hand since there is no whole-card
    // button here (only the CTA below is tappable).
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          Opacity(
            key: const ValueKey('click-onboarding-card-header'),
            opacity: 0.45,
            child: Row(
              spacing: 12,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // The same 38x38 status badge every other device entry uses
                // -- a 64x40 contour thumbnail read as broken scratchy
                // outlines at this scale (that art is authored for a 180px
                // hero). `LucideIcons.gamepad` mirrors BluetoothDevice's
                // default `icon`, which neither ZwiftClickV2 nor its
                // left/right side subclasses override, so this matches
                // whatever glyph the real entry will show once connected.
                const StatusIcon(status: false, icon: LucideIcons.gamepad, started: false),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      const Text('Zwift Click V2').semiBold,
                      Text(l10n.clickV2Onboarding_cardSubtitle).xSmall.muted,
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: Button.primary(
              trailing: const Icon(LucideIcons.arrowRight, size: 16),
              onPressed: () async {
                await context.push(const ClickV2OnboardingPage());
                onCompleted?.call();
              },
              child: Text(l10n.clickV2Onboarding_cardTitle),
            ),
          ),
        ],
      ),
    );
  }
}
