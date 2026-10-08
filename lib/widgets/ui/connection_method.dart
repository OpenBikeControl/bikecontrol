import 'package:bike_control/widgets/ui/bk_bottom_sheet.dart';
import 'package:bike_control/utils/window_size.dart';
import 'package:bike_control/widgets/ui/colors.dart';
import 'package:bike_control/bluetooth/devices/trainer_connection.dart';
import 'package:bike_control/bluetooth/messages/notification.dart';
import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/main.dart';
import 'package:bike_control/pages/markdown.dart';
import 'package:bike_control/utils/core.dart';
import 'package:bike_control/utils/keymap/apps/supported_app.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/requirements/local_network.dart';
import 'package:bike_control/utils/requirements/platform.dart';
import 'package:bike_control/widgets/status_icon.dart';
import 'package:bike_control/widgets/ui/app_theme.dart';
import 'package:bike_control/widgets/ui/beta_pill.dart';
import 'package:bike_control/widgets/ui/bk_grouped_section.dart';
import 'package:bike_control/widgets/ui/bk_status_dot.dart';
import 'package:bike_control/widgets/ui/bk_tappable.dart';
import 'package:bike_control/widgets/ui/type_scale.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:bike_control/widgets/ui/permissions_list.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

enum ConnectionMethodType {
  bluetooth(icon: LucideIcons.bluetooth),
  network(icon: LucideIcons.wifi),
  openBikeControl(icon: null),
  local(icon: LucideIcons.keyboard);

  final IconData? icon;
  const ConnectionMethodType({required this.icon});
}

extension ConnectionMethodTypeActivityIcon on ConnectionMethodType {
  /// Lucide icon shown in the activity log for an alert tied to this transport,
  /// so a connect/disconnect entry reflects how the trainer app is attached
  /// (WiFi vs Bluetooth) rather than always showing Bluetooth.
  IconData get activityIcon => switch (this) {
    ConnectionMethodType.network => LucideIcons.wifi,
    _ => LucideIcons.bluetooth,
  };
}

/// Marks the connection methods listed under the "Recommended connection
/// methods" header, so a method there doesn't repeat "Recommended" as a pill.
class RecommendedConnectionMethods extends InheritedWidget {
  const RecommendedConnectionMethods({super.key, required super.child});

  static bool contains(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RecommendedConnectionMethods>() != null;

  @override
  bool updateShouldNotify(RecommendedConnectionMethods oldWidget) => false;
}

class ConnectionMethod extends StatefulWidget {
  final TrainerConnection trainerConnection;
  final String title;
  final String description;
  final String? instructionLink;
  final Widget? additionalChild;
  final bool isRecommended;
  final bool isEnabled;
  final bool small;
  final bool showTroubleshooting;
  final ConnectionSupport? supportLevel;
  final List<PlatformRequirement> requirements;
  final List<InGameAction>? supportedActions;
  final Function(bool) onChange;
  final VoidCallback? onTroubleshoot;

  const ConnectionMethod({
    super.key,
    required this.trainerConnection,
    required this.title,
    required this.isRecommended,
    required this.isEnabled,
    required this.small,
    this.additionalChild,
    required this.description,
    this.instructionLink,
    this.showTroubleshooting = false,
    this.supportLevel,
    required this.onChange,
    this.supportedActions,
    required this.requirements,
    this.onTroubleshoot,
  });

  @override
  State<ConnectionMethod> createState() => _ConnectionMethodState();
}

class _ConnectionMethodState extends State<ConnectionMethod> with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.requirements.isNotEmpty && widget.isEnabled) {
      if (state == AppLifecycleState.resumed) {
        _recheckRequirements();
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.requirements.isNotEmpty && widget.isEnabled && !widget.trainerConnection.isStarted.value) {
      Future.wait(widget.requirements.map((e) => e.getStatus())).then((states) {
        final allDone = states.all((e) => e);
        if (allDone && widget.isEnabled) {
          widget.onChange(true);
        } else if (!allDone && widget.isEnabled) {
          widget.onChange(false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    void callback() {
      if (kIsWeb) {
        buildToast(title: AppLocalizations.of(context).notSupportedOnWeb);
      } else if (widget.requirements.isEmpty) {
        widget.onChange(!widget.isEnabled);
      } else {
        // Captured, not re-read after the await: `requirements` is rebuilt from
        // scratch on every build (see the tiles), so `widget.requirements` on
        // the far side of the gap can be a different, never-probed list whose
        // `status` is all false — which used to open the permission sheet for a
        // permission that was actually granted.
        final requirements = widget.requirements;
        Future.wait(requirements.map((e) => e.getStatus())).then((_) async {
          // The widget can be disposed across these async gaps; using a defunct
          // context (openPermissionSheet) or setState then throws "Null check
          // operator used on a null value".
          if (!context.mounted) return;
          final notDone = requirements.filter((e) => !e.status).toList();
          if (notDone.isEmpty) {
            widget.onChange(!widget.isEnabled);
          } else {
            await openPermissionSheet(context, notDone);
            if (!context.mounted) return;
            _recheckRequirements();
            setState(() {});
          }
        });
      }
    }

    if (widget.small) {
      final isSmallWidth = MediaQuery.sizeOf(context).width < Breakpoints.twoPane;
      final icon = Icon(
        widget.instructionLink?.contains("youtube") == true ? LucideIcons.monitorPlay : LucideIcons.circleHelp,
      );
      return SizedBox(
        width: double.infinity,
        child: Basic(
          leading: StatusIcon(
            status: widget.trainerConnection.isConnected.value,
            started: widget.trainerConnection.isStarted.value,
            icon: widget.trainerConnection.type.icon,
          ),
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              Expanded(
                child: widget.trainerConnection.isConnected.value ? Text(widget.title) : Text(widget.title).muted,
              ),
              if (widget.supportLevel == ConnectionSupport.beta)
                Padding(
                  padding: const EdgeInsets.only(top: 1.0),
                  child: BetaPill(),
                )
              else if (widget.supportLevel == ConnectionSupport.experimental)
                Padding(
                  padding: const EdgeInsets.only(top: 1.0),
                  child: BetaPill(text: 'EXPER.'),
                ),
            ],
          ),
          subtitle: Text(widget.description).xSmall.textMuted,
          trailing: widget.instructionLink != null && !widget.trainerConnection.isConnected.value
              ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Button(
                      style: isSmallWidth ? ButtonStyle.outlineIcon() : ButtonStyle.outline(),
                      leading: isSmallWidth ? null : icon,
                      onPressed: () {
                        if (widget.instructionLink!.contains("youtube") || widget.instructionLink!.contains("http")) {
                          launchUrlString(widget.instructionLink!);
                        } else {
                          openDrawer(
                            context: context,
                            position: OverlayPosition.bottom,
                            builder: (c) => MarkdownPage(assetPath: widget.instructionLink!),
                          );
                        }
                      },
                      child: isSmallWidth ? icon : Text(AppLocalizations.of(context).instructions),
                    ),
                  ],
                )
              : null,
        ),
      );
    }

    return _card(context, callback);
  }

  /// A method as a card (no outline): its icon tile, name and switch; a
  /// status line while it runs; what it does; and its links — instructions,
  /// the network check, the actions it supports. The whole card flips the
  /// switch, as before.
  Widget _card(BuildContext context, VoidCallback callback) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final connection = widget.trainerConnection;
    final connected = connection.isConnected.value;
    final started = connection.isStarted.value;
    final realAppName = core.settings.getTrainerApp()?.name;
    final appName = realAppName == null ? null : shownTrainerAppName(realAppName);
    final accent = bkAccentText(context);
    final linkStyle = context.typography.small.copyWith(color: accent, fontWeight: FontWeight.w600);
    const textInset = BkIconTile.size + BkGroupedRow.gap;

    Widget link(String label, VoidCallback onPressed, {Widget? leading}) => Button.ghost(
      style: const ButtonStyle.ghost().withPadding(padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8)),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          ?leading,
          Text(label, style: linkStyle),
        ],
      ),
    );

    final links = <Widget>[
      if (widget.instructionLink != null)
        link(l10n.instructions, () {
          if (widget.instructionLink!.contains("youtube") || widget.instructionLink!.contains("http")) {
            launchUrlString(widget.instructionLink!);
          } else {
            openDrawer(
              context: context,
              position: OverlayPosition.bottom,
              builder: (c) => MarkdownPage(assetPath: widget.instructionLink!),
            );
          }
        }),
      if (widget.supportedActions != null)
        link(
          l10n.supportedActions,
          () => _showSupportedActions(context),
          leading: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(12)),
            child: Text(
              widget.supportedActions!.length.toString(),
              style: context.typography.xSmall.copyWith(color: cs.primaryForeground, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      if (widget.onTroubleshoot != null)
        Button(
          key: const ValueKey('connection-troubleshoot'),
          style: started && !connected ? ButtonStyle.outline() : ButtonStyle.ghost(),
          leading: const Icon(LucideIcons.wrench, size: 16),
          onPressed: widget.onTroubleshoot,
          child: Text(l10n.networkTroubleshootTroubleshoot),
        ),
    ];

    return BkTappable(
      onPressed: callback,
      borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: cs.card,
          borderRadius: BorderRadius.circular(BkComponentThemes.cardRadius),
          boxShadow: bkCardShadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 6,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                BkIconTile(
                  icon:
                      connection.type.icon ??
                      (identical(connection, core.obpBluetoothEmulator) ? LucideIcons.bluetooth : LucideIcons.wifi),
                ),
                const Gap(BkGroupedRow.gap),
                Expanded(
                  child: Text(
                    widget.title,
                    style: context.typography.base.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (widget.supportLevel == ConnectionSupport.beta)
                  const BetaPill()
                else if (widget.supportLevel == ConnectionSupport.experimental)
                  const BetaPill(text: 'EXPER.')
                else if (widget.isRecommended && !screenshotMode && !RecommendedConnectionMethods.contains(context))
                  SecondaryBadge(child: Text(l10n.recommended)),
                const Gap(8),
                Semantics(
                  container: true,
                  label: widget.title,
                  toggled: widget.isEnabled,
                  child: Switch(value: widget.isEnabled, onChanged: (_) => callback()),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: textInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 6,
                children: [
                  if (connected)
                    BkStatusDot(label: appName != null ? l10n.chainStepAppConnected(appName) : l10n.statusConnected)
                  else if (started && widget.isEnabled)
                    BkStatusDot(label: l10n.waitingForConnection, tone: BkStatusTone.warning),
                  Text(
                    widget.description,
                    style: context.typography.small.copyWith(color: cs.mutedForeground, height: 1.4),
                  ),
                  if (widget.isEnabled && widget.additionalChild != null) widget.additionalChild!,
                  if (links.isNotEmpty) Wrap(spacing: 20, runSpacing: 4, children: links),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSupportedActions(BuildContext context) {
    openDrawer(
      context: context,
      position: OverlayPosition.right,
      builder: (c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        width: 230,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            ColoredTitle(text: AppLocalizations.of(context).supportedActions),
            const Gap(12),
            ...widget.supportedActions!.map(
              (e) => Basic(
                leading: e.icon != null ? Icon(e.icon) : null,
                title: Text(e.title),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _recheckRequirements() {
    Future.wait(widget.requirements.map((e) => e.getStatus())).then((result) {
      final allDone = result.every((e) => e);

      if (context.mounted && widget.isEnabled != allDone) {
        widget.onChange(allDone);
      }
    });
  }
}

Future openPermissionSheet(BuildContext context, List<PlatformRequirement> notDone) {
  return openBottomSheet(
    context: context,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(16.0),
      child: PermissionList(
        requirements: notDone,
        onDone: () {
          closeSheet(context);
        },
      ),
    ),
  );
}

/// Reports whether [requirements] are satisfied, prompting for whichever are
/// missing.
///
/// A status check that throws counts as not granted: a permission state we
/// could not read is not one to act on.
Future<bool> satisfyRequirements(BuildContext context, List<PlatformRequirement> requirements) async {
  Future<bool> liveStatus(PlatformRequirement r) async {
    try {
      return await r.getStatus();
    } catch (e, s) {
      recordError(e, s, context: 'requirement status');
      return false;
    }
  }

  var states = await Future.wait(requirements.map(liveStatus));
  final missing = [
    for (var i = 0; i < requirements.length; i++)
      if (!states[i]) requirements[i],
  ];
  if (missing.isEmpty) return true;
  if (context.mounted) {
    await openPermissionSheet(context, missing);
  }
  states = await Future.wait(missing.map(liveStatus));
  return states.every((granted) => granted);
}

/// Prompts for Local Network when it is missing, and brings the enabled network
/// methods up once it is granted.
///
/// The network-side mirror of [enableLocalControl]. Starting on success is the
/// point: the launch-time start is skipped while onboarding holds the screen,
/// and a rider who grants the permission later would otherwise be left with a
/// method that reads as enabled while advertising nothing.
Future<bool> ensureLocalNetworkAccess(BuildContext context) async {
  final requirements = localNetworkRequirements();
  if (requirements.isEmpty) return true;
  if (!await satisfyRequirements(context, requirements)) return false;
  core.logic.startEnabledConnectionMethod(userInitiated: true);
  return true;
}

/// Prompts for any missing local-control permissions, enables the Local
/// connection method, and returns whether Local is enabled afterwards.
///
/// Mirrors the enable path in [LocalTile]'s `onChange` + [ConnectionMethod]'s
/// requirement flow so a caller (e.g. the ButtonEditor) can enable Local
/// inline instead of sending the user to the connection settings.
Future<bool> enableLocalControl(BuildContext context) async {
  final requirements = core.permissions.getLocalControlRequirements();
  final notDone = <PlatformRequirement>[];
  for (final requirement in requirements) {
    if (!await requirement.getStatus()) {
      notDone.add(requirement);
    }
  }
  if (notDone.isNotEmpty) {
    if (!context.mounted) return false;
    await openPermissionSheet(context, notDone);
    for (final requirement in notDone) {
      if (!await requirement.getStatus()) {
        return false;
      }
    }
  }

  core.settings.setLocalEnabled(true);
  if (core.logic.canRunAndroidService) {
    final running = await core.logic.isAndroidServiceRunning();
    core.local.isStarted.value = running;
    core.local.isConnected.value = running;
  } else {
    core.local.isStarted.value = true;
    core.local.isConnected.value = true;
  }
  core.connection.signalNotification(LogNotification('Local Control: true'));
  return core.settings.getLocalEnabled();
}

/// The trainer app's connection in a word or two ("Network", "Bluetooth,
/// Local"): the methods carrying it right now, else the ones switched on.
/// Null while none is switched on.
String? connectionMethodSummary(BuildContext context) {
  final l = AppLocalizations.of(context);
  final connected = core.logic.appFacingConnections;
  final methods = connected.isNotEmpty ? connected : core.logic.enabledTrainerConnections;
  final labels = <String>[];
  for (final method in methods) {
    final label = switch (method) {
      _ when identical(method, core.local) => l.onboardingMethodLocal,
      _ when identical(method, core.obpBluetoothEmulator) || identical(method, core.zwiftEmulator) =>
        l.onboardingMethodBluetooth,
      _ => l.onboardingMethodNetwork,
    };
    if (!labels.contains(label)) labels.add(label);
  }
  return labels.isEmpty ? null : labels.join(', ');
}
