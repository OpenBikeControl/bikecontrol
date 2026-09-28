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
import 'package:bike_control/widgets/ui/beta_pill.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:bike_control/widgets/ui/permissions_list.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';

enum ConnectionMethodType {
  bluetooth(icon: Icons.bluetooth),
  network(icon: Icons.wifi),
  openBikeControl(icon: null),
  local(icon: Icons.keyboard);

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
      final isSmallWidth = MediaQuery.sizeOf(context).width < 800;
      final icon = Icon(
        widget.instructionLink?.contains("youtube") == true ? Icons.ondemand_video : Icons.help_outline,
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

    return SizedBox(
      width: double.infinity,
      child: Button.card(
        onPressed: callback,
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
              Expanded(child: Text(widget.title)),
              if (widget.supportLevel == ConnectionSupport.beta)
                Padding(
                  padding: const EdgeInsets.only(top: 1.0),
                  child: BetaPill(),
                )
              else if (widget.supportLevel == ConnectionSupport.experimental)
                Padding(
                  padding: const EdgeInsets.only(top: 1.0),
                  child: BetaPill(text: 'EXPER.'),
                )
              else if (widget.isRecommended && !screenshotMode)
                SecondaryBadge(child: Text(AppLocalizations.of(context).recommended)),
              Switch(
                value: widget.isEnabled,
                onChanged: (value) {
                  callback();
                },
              ),
            ],
          ),
          subtitle: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 6,
            children: [
              Text(widget.description).xSmall.textMuted,
              if (widget.isEnabled && widget.additionalChild != null) widget.additionalChild!,
              if (widget.instructionLink != null || widget.showTroubleshooting) SizedBox(),
              if (widget.instructionLink != null || widget.onTroubleshoot != null)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (widget.instructionLink != null) ...[
                      Button(
                        style: widget.isEnabled
                            ? ButtonStyle.outline().withBorder(border: Border.all(color: bkStrongBorder(context)))
                            : ButtonStyle.outline(),
                        leading: Icon(
                          widget.instructionLink!.contains("youtube") ? Icons.ondemand_video : Icons.help_outline,
                        ),
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
                        child: Text(AppLocalizations.of(context).instructions),
                      ),
                    ],
                    if (widget.onTroubleshoot != null)
                      Button(
                        key: const ValueKey('connection-troubleshoot'),
                        style: widget.trainerConnection.isStarted.value && !widget.trainerConnection.isConnected.value
                            ? ButtonStyle.outline()
                            : ButtonStyle.ghost(),
                        leading: const Icon(LucideIcons.wrench, size: 16),
                        onPressed: widget.onTroubleshoot,
                        child: Text(AppLocalizations.of(context).networkTroubleshootTroubleshoot),
                      ),
                    if (widget.supportedActions != null)
                      Button.outline(
                        leading: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          margin: EdgeInsets.only(right: 4),
                          child: Text(
                            widget.supportedActions!.length.toString(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primaryForeground,
                            ),
                          ),
                        ),
                        onPressed: () {
                          openDrawer(
                            context: context,
                            position: OverlayPosition.right,
                            builder: (c) => Container(
                              padding: EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                              width: 230,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                spacing: 12,
                                children: [
                                  ColoredTitle(
                                    text: AppLocalizations.of(context).supportedActions,
                                  ),
                                  Gap(12),
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
                        },
                        child: Text(AppLocalizations.of(context).supportedActions),
                      ),
                  ],
                ),
            ],
          ),
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
  return openSheet(
    context: context,
    draggable: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.all(16.0),
      child: PermissionList(
        requirements: notDone,
        onDone: () {
          closeSheet(context);
        },
      ),
    ),
    position: OverlayPosition.bottom,
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
