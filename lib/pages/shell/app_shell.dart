import 'dart:async';

import 'package:bike_control/bluetooth/devices/base_device.dart';
import 'package:bike_control/bluetooth/devices/bluetooth_device.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/activity/activity_log.dart';
import 'package:bike_control/pages/home/home_page.dart' show chainProxy;
import 'package:bike_control/pages/subscription.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/iap/iap_manager.dart';
import 'package:bike_control/widgets/menu.dart';
import 'package:bike_control/widgets/plan/vs_trial_meter.dart';
import 'package:bike_control/widgets/title.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/bk_page_header.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/widgets/ui/help_button.dart';
import 'package:bike_control/widgets/ui/pro_badge.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// The app's four top-level sections.
enum AppSection {
  ride,
  devices,
  activity,
  settings;

  IconData get icon => switch (this) {
    AppSection.ride => LucideIcons.bike,
    AppSection.devices => LucideIcons.bluetooth,
    AppSection.activity => LucideIcons.activity,
    AppSection.settings => LucideIcons.settings,
  };

  String label(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return switch (this) {
      AppSection.ride => l10n.navRide,
      AppSection.devices => l10n.navDevices,
      AppSection.activity => l10n.activity,
      AppSection.settings => l10n.navSettings,
    };
  }
}

/// What the shell's chrome and its content share: the selected section and
/// the session's activity log.
class ShellController {
  final ValueNotifier<AppSection> section = ValueNotifier(AppSection.ride);
  final ActivityLogController activity = ActivityLogController();

  void select(AppSection value) => section.value = value;

  void dispose() {
    section.dispose();
    activity.dispose();
  }
}

/// Opens the plan and subscription drawer (the old Pro crown's target).
void openSubscription(BuildContext context) {
  openDrawer(
    context: context,
    builder: (c) => SubscriptionPage(),
    position: OverlayPosition.end,
  );
}

enum _NavLayout { bottom, top, side }

/// One section entry of the tab bar, the top tabs or the sidebar: a labelled
/// button that reports whether it is selected. The Activity entry carries a
/// red dot while the log holds an error, and says so to a screen reader.
class ShellNavItem extends StatefulWidget {
  const ShellNavItem._({required this.section, required this.controller, required _NavLayout layout})
    : _layout = layout;

  final AppSection section;
  final ShellController controller;
  final _NavLayout _layout;

  @override
  State<ShellNavItem> createState() => _ShellNavItemState();
}

class _ShellNavItemState extends State<ShellNavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final hasErrors = widget.controller.activity.hasErrors;
    return ValueListenableBuilder<AppSection>(
      valueListenable: widget.controller.section,
      builder: (context, selectedSection, _) {
        final selected = selectedSection == section;
        return ValueListenableBuilder<bool>(
          valueListenable: hasErrors,
          builder: (context, errors, _) {
            final showDot = section == AppSection.activity && errors;
            final label = section.label(context);
            return BkTappable(
              onPressed: () => widget.controller.select(section),
              label: showDot ? AppLocalizations.of(context).a11yTabHasErrors(label) : label,
              selected: selected,
              excludeChildSemantics: true,
              borderRadius: BorderRadius.circular(widget._layout == _NavLayout.bottom ? 12 : 999),
              onHover: (hovered) => setState(() => _hovered = hovered),
              child: _build(context, label, selected, showDot),
            );
          },
        );
      },
    );
  }

  Widget _icon(BuildContext context, Color color, bool showDot, double size) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(widget.section.icon, size: size, color: color),
        if (showDot)
          Positioned(
            key: const ValueKey('activity-error-dot'),
            right: -3,
            top: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: BkStatusColors.of(context).danger,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).colorScheme.background, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }

  Widget _build(BuildContext context, String label, bool selected, bool showDot) {
    final cs = Theme.of(context).colorScheme;
    switch (widget._layout) {
      case _NavLayout.bottom:
        final color = selected ? bkAccentText(context) : cs.mutedForeground;
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            spacing: 3,
            children: [
              _icon(context, color, showDot, 22),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.typography.caption.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      case _NavLayout.top:
        final color = selected ? cs.primaryForeground : cs.foreground;
        return Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? cs.primary : (_hovered ? bkCardHover(context) : null),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 7,
            children: [
              _icon(context, color, showDot, 16),
              Text(
                label,
                style: context.typography.small.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        );
      case _NavLayout.side:
        final color = selected ? cs.primaryForeground : cs.foreground;
        return Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? cs.primary : (_hovered ? bkCardHover(context) : null),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            spacing: 12,
            children: [
              _icon(context, selected ? color : cs.mutedForeground, showDot, 18),
              Expanded(
                child: Text(
                  label,
                  style: context.typography.small.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }
}

/// The phone's bottom tab bar: four sections, icons over labels.
class ShellTabBar extends StatelessWidget {
  const ShellTabBar({super.key, required this.controller});

  final ShellController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.background,
        border: Border(top: BorderSide(color: cs.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              for (final section in AppSection.values)
                Expanded(
                  child: ShellNavItem._(section: section, controller: controller, layout: _NavLayout.bottom),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The medium window's floating tab bar: a pill group above the page.
class ShellTopTabs extends StatelessWidget {
  const ShellTopTabs({super.key, required this.controller});

  final ShellController controller;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(999)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 2,
              children: [
                for (final section in AppSection.values)
                  ShellNavItem._(section: section, controller: controller, layout: _NavLayout.top),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The expanded window's permanent sidebar: the wordmark, the sections, and
/// at its foot the current plan and Help & Support.
class ShellSidebar extends StatelessWidget {
  const ShellSidebar({super.key, required this.controller});

  final ShellController controller;

  static const double width = 232;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: bkSunkenSurface(context),
        border: Border(right: BorderSide(color: cs.border, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 16),
            child: Semantics(
              header: true,
              child: Text(
                'BikeControl',
                style: context.typography.large.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
              ),
            ),
          ),
          for (final section in AppSection.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: ShellNavItem._(section: section, controller: controller, layout: _NavLayout.side),
            ),
          const Spacer(),
          const SidebarPlanCard(),
          const Gap(8),
          const HelpButton(style: HelpButtonStyle.sidebar),
        ],
      ),
    );
  }
}

/// The page's top bar: the title ("BikeControl" on the phone's Ride, the
/// section's name elsewhere) and the page's actions.
class ShellTopBar extends StatelessWidget {
  const ShellTopBar({
    super.key,
    required this.section,
    required this.compact,
    this.showPlanAndHelp = false,
    this.activity,
    this.shell,
  });

  /// The shell, for the expanded window's device chips (a tap opens
  /// Devices). The chips show only when it is given.
  final ShellController? shell;

  final AppSection section;

  /// The session's log, for Activity's Clear.
  final ActivityLogController? activity;

  /// The phone's large title and icon-only update action.
  final bool compact;

  /// The plan badge and the (?) Help icon — for the phone and medium windows,
  /// where there is no sidebar to carry them.
  final bool showPlanAndHelp;

  @override
  Widget build(BuildContext context) {
    final title = compact && section == AppSection.ride ? 'BikeControl' : section.label(context);
    final style = compact
        ? context.typography.x2Large.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4)
        : BkPageHeader.titleStyle(context);
    return AppBar(
      padding: EdgeInsets.fromLTRB(compact ? 16 : 24, compact ? 10 : 16, compact ? 8 : 20, 8),
      backgroundColor: Theme.of(context).colorScheme.background,
      title: Semantics(
        header: true,
        child: Text(title, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      trailingGap: 4,
      trailing: [
        if (shell != null) ShellDeviceChips(shell: shell!),
        if (section == AppSection.activity && activity != null) ActivityClearButton(controller: activity!),
        AppUpdateButton(compact: compact),
        if (showPlanAndHelp) const PlanBadge(),
        if (showPlanAndHelp) const HelpButton(),
        // Developer tools; renders nothing outside debug builds.
        const DebugMenuButton(),
      ],
    );
  }
}

enum PlanTier { pro, base, trial }

PlanTier currentPlanTier() {
  final iap = IAPManager.instance;
  if (iap.isProEnabled) return PlanTier.pro;
  if (iap.isPurchased.value) return PlanTier.base;
  return PlanTier.trial;
}

String planName(BuildContext context, PlanTier tier) => switch (tier) {
  PlanTier.pro => 'Pro',
  PlanTier.base => AppLocalizations.of(context).fullVersion,
  PlanTier.trial => AppLocalizations.of(context).chainTrialTitle,
};

/// Rebuilds [builder] whenever the purchase state changes.
class _PlanListener extends StatelessWidget {
  const _PlanListener({required this.builder});

  final Widget Function(BuildContext context, PlanTier tier) builder;

  @override
  Widget build(BuildContext context) {
    final iap = IAPManager.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([iap.entitlements, iap.isPurchased]),
      builder: (context, _) => builder(context, currentPlanTier()),
    );
  }
}

/// The plan as a small badge ("Base", "Trial", PRO) that opens the plans.
class PlanBadge extends StatelessWidget {
  const PlanBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return _PlanListener(
      builder: (context, tier) {
        final cs = Theme.of(context).colorScheme;
        final badge = tier == PlanTier.pro
            ? const ProBadge()
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: cs.muted, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  planName(context, tier),
                  style: context.typography.xSmall.copyWith(color: cs.foreground, fontWeight: FontWeight.w600),
                ),
              );
        return BkTappable(
          key: const ValueKey('plan-badge'),
          onPressed: () => openSubscription(context),
          label: '${AppLocalizations.of(context).currentPlan}: ${planName(context, tier)}',
          excludeChildSemantics: true,
          borderRadius: BorderRadius.circular(999),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Center(child: badge),
          ),
        );
      },
    );
  }
}

/// The sidebar's plan card: "Current plan", the plan's name, its status line,
/// — below Pro — a Go Pro link and, without Pro on this device, what is left
/// of today's virtual shifting trial. The whole card opens the plans.
class SidebarPlanCard extends StatelessWidget {
  const SidebarPlanCard({super.key});

  @override
  Widget build(BuildContext context) {
    return _PlanListener(
      builder: (context, tier) {
        final cs = Theme.of(context).colorScheme;
        final l10n = AppLocalizations.of(context);
        final status = IAPManager.instance.getStatusMessage();
        return BkTappable(
          key: const ValueKey('plan-card'),
          onPressed: () => openSubscription(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.currentPlan,
                        style: context.typography.caption.copyWith(color: cs.mutedForeground),
                      ),
                    ),
                    if (tier != PlanTier.pro)
                      Text(
                        l10n.goPro,
                        style: context.typography.xSmall.copyWith(
                          color: bkAccentText(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                Text(
                  planName(context, tier).toUpperCase(),
                  style: BkDisplay.title(context),
                ),
                if (status.isNotEmpty && status != planName(context, tier))
                  Text(
                    status,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.typography.caption.copyWith(color: cs.mutedForeground),
                  ),
                // Today's virtual shifting trial, as on Settings' plan card.
                if (vsTrialMeterShown()) ...[
                  const Gap(6),
                  const VsTrialMeter(compact: true),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The expanded window's header chips: the connected controller with its
/// battery, and the bridged trainer with the app it sends to. Each opens
/// Devices. Nothing while no device is connected.
class ShellDeviceChips extends StatefulWidget {
  const ShellDeviceChips({super.key, required this.shell});

  final ShellController shell;

  @override
  State<ShellDeviceChips> createState() => _ShellDeviceChipsState();
}

class _ShellDeviceChipsState extends State<ShellDeviceChips> {
  late final StreamSubscription<BaseDevice> _connections;

  @override
  void initState() {
    super.initState();
    _connections = core.connection.connectionStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _connections.cancel();
    super.dispose();
  }

  void _openDevices() => widget.shell.select(AppSection.devices);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: core.connection.hasDevices,
      builder: (context, _, _) {
        final controller = core.connection.controllerDevices.where((d) => d.isConnected).firstOrNull;
        final proxy = chainProxy();
        final trainer = proxy != null && proxy.isConnected ? proxy : null;
        if (controller == null && trainer == null) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final muted = context.typography.xSmall.copyWith(color: cs.mutedForeground);
        final strong = context.typography.xSmall.copyWith(color: cs.foreground, fontWeight: FontWeight.w500);
        final battery = controller is BluetoothDevice ? controller.batteryLevel : null;
        final appName = core.settings.getTrainerApp()?.name;
        return Row(
          key: const ValueKey('shell-device-chips'),
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          children: [
            if (controller != null)
              _chip(
                key: const ValueKey('shell-device-chip-controller'),
                label: [controller.displayName(context), if (battery != null) '$battery%'].join(', '),
                children: [
                  Icon(controller.icon, size: 14, color: cs.foreground),
                  Flexible(
                    child: Text(
                      controller.displayName(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: strong,
                    ),
                  ),
                  if (battery != null)
                    Text(
                      '$battery%',
                      style: muted.copyWith(color: battery < 20 ? cs.destructive : null),
                    ),
                ],
              ),
            if (trainer != null)
              _chip(
                key: const ValueKey('shell-device-chip-trainer'),
                label: appName == null
                    ? trainer.displayName(context)
                    : AppLocalizations.of(context).shellTrainerChipLabel(trainer.displayName(context), appName),
                children: [
                  Icon(trainer.icon, size: 14, color: cs.foreground),
                  Flexible(
                    child: Text(
                      trainer.displayName(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: strong,
                    ),
                  ),
                  if (appName != null) ...[
                    Icon(LucideIcons.arrowRight, size: 12, color: cs.mutedForeground),
                    Text(appName, maxLines: 1, style: muted),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _chip({required Key key, required String label, required List<Widget> children}) {
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: BkTappable(
        key: key,
        onPressed: _openDevices,
        label: label,
        excludeChildSemantics: true,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: cs.card, borderRadius: BorderRadius.circular(999)),
          child: Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: children),
        ),
      ),
    );
  }
}
