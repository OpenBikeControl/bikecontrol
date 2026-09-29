import 'package:bike_control/pages/onboarding/widgets/onboarding_theme.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_reveal.dart';
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/pages/onboarding/onboarding_app_guides.dart';
import 'package:bike_control/pages/onboarding/onboarding_methods.dart';
import 'package:bike_control/pages/onboarding/widgets/onboarding_group_label.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/pages/network_troubleshooting_page.dart';
import 'package:bike_control/utils/requirements/multi.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

const _success = Color(0xFF22C55E);

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
            border: Border.all(color: on ? onboardingAccent(context) : scheme.border, width: 1.5),
            borderRadius: BorderRadius.circular(12),
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
                      Icon(LucideIcons.check, size: 13, color: _success),
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
                              color: isConnected ? _success : Theme.of(context).colorScheme.mutedForeground,
                            ),
                          ),
                          Gap(7),
                          isConnected
                              ? DefaultTextStyle.merge(
                                  style: const TextStyle(color: _success),
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


Widget onboardingConnectionBody(
  BuildContext context, {
  required SupportedApp app,
  required Target target,
  required bool hasTrainer,
  required String? trainerName,
  required VoidCallback onUpdate,
  Widget? networkStatus,
}) {
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
          badge: context.i18n.onboardingMethodBluetoothBadge,
          description: context.i18n.onboardingMethodBluetoothDesc(app.name),
          enabled: enabled,
          connection: connection,
          appName: app.name,
          onToggle: toggle,
        ),
      OnboardingMethod.local => _MethodTile(
          icon: LucideIcons.keyboard,
          title: context.i18n.onboardingMethodLocal,
          badge: context.i18n.onboardingMethodLocalBadge,
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

  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: onboardingReveal([
    Text(context.i18n.onboardingConnectionTitle(app.name)).h4,
    Gap(6),
    Text(target == Target.thisDevice
            ? context.i18n.onboardingConnectionSubtitleLocal(app.name)
            // Apps that only find trainers over Bluetooth never see the network
            // advertisement, so promising them one sends riders looking for it.
            : app.virtualShiftingTransports.contains(TrainerConnectionType.wifi)
                ? context.i18n.onboardingConnectionSubtitleNetwork(app.name)
                : context.i18n.onboardingConnectionSubtitleBluetooth(app.name))
        .small
        .muted,
    Gap(18),
    // An app with no controller integration at all (Tacx Training) offers no
    // method on a second device — only the Bridge below. Drop the heading
    // rather than leave it standing over nothing.
    if (OnboardingMethod.values.any((m) => onboardingMethodVisible(m, app))) ...[
      OnboardingGroupLabel(context.i18n.onboardingConnectionMethods),
      for (final method in OnboardingMethod.values)
        if (onboardingMethodVisible(method, app))
          Padding(padding: const EdgeInsets.only(bottom: 10), child: methodTile(method)),
    ],
    // The background network check, while a network method is on.
    ?networkStatus,
    Gap(10),
    OnboardingGroupLabel(context.i18n.onboardingThenInApp(app.name)),
    OnboardingAppGuideCard(app: app),
    if (hasTrainer) ...[
      Gap(20),
      OnboardingGroupLabel(context.i18n.onboardingPairAsTrainer),
      OnboardingPairAsTrainerCard(app: app, trainerName: trainerName),
    ],
  ]));
}
