import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_theme.dart';
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/pages/onboarding/onboarding_methods.dart';
import 'package:bike_control/utils/host_platform.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/utils/core.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';


/// One design-language method tile: icon square, title + badge, description,
/// optional feature checks, radio check-dot on the right. Selection state is
/// the method's real enabled state — toggling writes the same settings the
/// Trainer Connections tiles do (see onboarding_methods.dart).
class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.enabled,
    required this.onToggle,
    this.connection,
    this.appName = '',
    this.badge,
    this.badgeIsPrimary = false,
    this.features = const [],
    this.disabled = false,
    this.footNote,
    this.onTroubleshoot,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final VoidCallback onToggle;
  final TrainerConnection? connection;
  final String appName;
  final String? badge;
  final bool badgeIsPrimary;
  final List<String> features;
  final bool disabled;
  final String? footNote;

  /// Offered while this method is switched on but the trainer app has not
  /// arrived. That wait is exactly when a rider needs the network self-test,
  /// and step 5 was previously silent about it — the only route in was the
  /// wizard's help button, which nobody presses while they still believe it is
  /// working.
  final VoidCallback? onTroubleshoot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final on = enabled && !disabled;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: Button.ghost(
        style: ButtonStyle.ghost().withPadding(padding: EdgeInsets.zero),
        onPressed: disabled ? null : onToggle,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: on ? onboardingAccent(context) : const Color(0x00000000), width: 2),
            borderRadius: BorderRadius.circular(16),
            color: scheme.card,
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                color: on ? onboardingAccent(context) : scheme.muted,
              ),
              child: Icon(icon, size: 20, color: on ? onboardingOnAccent(context) : null),
            ),
            Gap(12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Text(title).small.semiBold,
                  if (badge != null) ...[
                    Gap(7),
                    if (badgeIsPrimary) PrimaryBadge(child: Text(badge!)) else SecondaryBadge(child: Text(badge!)),
                  ],
                ]),
                Gap(4),
                Text(description).xSmall.muted,
                for (final f in features)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      Icon(LucideIcons.check, size: 13, color: BkStatusColors.of(context).success),
                      Gap(7),
                      Text(f).xSmall,
                    ]),
                  ),
                if (footNote != null) ...[
                  Gap(8),
                  Row(children: [
                    Icon(LucideIcons.info, size: 14, color: scheme.mutedForeground),
                    Gap(7),
                    Expanded(child: Text(footNote!).xSmall.muted),
                  ]),
                ],
                // Live status: enabled is just the pref — show whether the
                // trainer app is actually connected through this method.
                if (on && connection != null)
                  AnimatedBuilder(
                    animation: Listenable.merge([connection!.isConnected, connection!.isStarted]),
                    builder: (context, _) {
                      final isConnected = connection!.isConnected.value;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isConnected ? BkStatusColors.of(context).success : Theme.of(context).colorScheme.mutedForeground,
                            ),
                          ),
                          Gap(7),
                          isConnected
                              ? DefaultTextStyle.merge(
                                  style: TextStyle(color: BkStatusColors.of(context).success),
                                  child: Text(context.i18n.onboardingDeviceConnected).xSmall.semiBold,
                                )
                              : Text(context.i18n.onboardingSummaryWaitingFor(appName)).xSmall.muted,
                        ]),
                      );
                    },
                  ),
                if (on && connection != null && onTroubleshoot != null)
                  AnimatedBuilder(
                    animation: connection!.isConnected,
                    builder: (context, _) {
                      if (connection!.isConnected.value) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Button.outline(
                          style: ButtonStyle.outline(size: ButtonSize.small),
                          onPressed: onTroubleshoot,
                          child: Text(context.i18n.networkTroubleshootTroubleshoot),
                        ),
                      );
                    },
                  ),
              ]),
            ),
            Gap(10),
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: on ? onboardingAccent(context) : null,
                border: on ? null : Border.all(color: scheme.border, width: 2),
              ),
              child: on ? Icon(LucideIcons.check, size: 12, color: onboardingOnAccent(context)) : null,
            ),
          ]),
        ),
      ),
    );
  }
}


/// The connection methods [app] can use, as toggle tiles. Toggling writes the
/// same settings the Trainer Connections tiles do (see onboarding_methods.dart).
List<Widget> onboardingMethodTiles(BuildContext context, {required SupportedApp app, required VoidCallback onUpdate}) {
  Widget methodTile(OnboardingMethod method) {
    final enabled = onboardingMethodEnabled(method, app);
    final available = onboardingMethodAvailable(method);
    final connection = onboardingMethodConnection(method, app);
    void toggle() => setOnboardingMethodEnabled(context, method, app, !enabled, onUpdate: onUpdate);
    return switch (method) {
      OnboardingMethod.network => _MethodTile(
          onTroubleshoot: () => context.push(const NetworkTroubleshootingPage()),
          icon: LucideIcons.wifi,
          title: context.i18n.onboardingMethodNetwork,
          badge: context.i18n.recommended,
          badgeIsPrimary: true,
          description: context.i18n.onboardingMethodNetworkDesc(app.name),
          enabled: enabled,
          connection: connection,
          appName: app.name,
          onToggle: toggle,
        ),
      OnboardingMethod.bluetooth => _MethodTile(
          icon: LucideIcons.bluetooth,
          title: context.i18n.onboardingMethodBluetooth,
          // Platform badges only where they apply.
          badge: HostPlatform.isIOS ? context.i18n.onboardingMethodBluetoothBadge : null,
          description: context.i18n.onboardingMethodBluetoothDesc(app.name),
          // Paired as a BC2 shifter, BikeControl sits in the app's steering
          // devices — not where a rider looks for a controller.
          footNote: onboardingBluetoothIsBc2(app) ? context.i18n.addBikeControlAsSteeringDevice(app.name) : null,
          enabled: enabled,
          connection: connection,
          appName: app.name,
          onToggle: toggle,
        ),
      OnboardingMethod.local => _MethodTile(
          icon: LucideIcons.keyboard,
          title: context.i18n.onboardingMethodLocal,
          badge: available ? context.i18n.onboardingMethodLocalBadge : null,
          description: context.i18n.onboardingMethodLocalDesc,
          features: [
            context.i18n.onboardingMethodLocalFeature1,
            context.i18n.onboardingMethodLocalFeature2,
            context.i18n.onboardingMethodLocalFeature3,
          ],
          enabled: enabled,
          connection: connection,
          appName: app.name,
          disabled: !available,
          footNote: available ? null : context.i18n.onboardingMethodLocalIosNote,
          onToggle: toggle,
        ),
    };
  }

  return [
    for (final method in OnboardingMethod.values)
      if (onboardingMethodVisible(method, app))
        Padding(padding: const EdgeInsets.only(bottom: 10), child: methodTile(method)),
  ];
}

/// The ride step's connection methods, folded away behind their heading: the
/// app step already turned on the right one. Unfolded while none is on —
/// then picking one is the thing to do.
class OnboardingMethodsDisclosure extends StatefulWidget {
  const OnboardingMethodsDisclosure({super.key, required this.app, required this.onUpdate});

  final SupportedApp app;
  final VoidCallback onUpdate;

  @override
  State<OnboardingMethodsDisclosure> createState() => _OnboardingMethodsDisclosureState();
}

class _OnboardingMethodsDisclosureState extends State<OnboardingMethodsDisclosure> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final tiles = onboardingMethodTiles(context, app: widget.app, onUpdate: widget.onUpdate);
    // An app with no controller integration at all (Tacx Training) offers no
    // method — nothing to fold.
    if (tiles.isEmpty) return const SizedBox.shrink();
    final open = _open || core.logic.hasNoConnectionMethod;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Button.ghost(
          key: const ValueKey('onboarding-methods-toggle'),
          style: ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(vertical: 10)),
          onPressed: () => setState(() => _open = !_open),
          child: Row(
            children: [
              Icon(LucideIcons.settings2, size: 15, color: Theme.of(context).colorScheme.mutedForeground),
              Gap(8),
              Expanded(child: Text(context.i18n.onboardingConnectionMethods).small.semiBold),
              Icon(open ? LucideIcons.chevronUp : LucideIcons.chevronDown, size: 15),
            ],
          ),
        ),
        if (open) ...[Gap(6), ...tiles],
      ],
    );
  }
}
