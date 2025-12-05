import 'package:dartx/dartx.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/pages/button_edit.dart';
import 'package:swift_control/pages/markdown.dart';
import 'package:swift_control/utils/i18n_extension.dart';
import 'package:swift_control/utils/requirements/platform.dart';
import 'package:swift_control/widgets/ui/beta_pill.dart';
import 'package:swift_control/widgets/ui/small_progress_indicator.dart';
import 'package:url_launcher/url_launcher_string.dart';

enum ConnectionMethodType {
  bluetooth,
  network,
  openBikeControl,
  local,
}

class ConnectionMethod extends StatefulWidget {
  final String title;
  final String description;
  final String? instructionLink;
  final ConnectionMethodType type;
  final Widget? additionalChild;
  final bool? isConnected;
  final bool? isStarted;
  final bool isEnabled;
  final bool showTroubleshooting;
  final List<PlatformRequirement> requirements;
  final Function(bool) onChange;

  const ConnectionMethod({
    super.key,
    required this.title,
    required this.type,
    required this.isEnabled,
    this.additionalChild,
    required this.description,
    this.instructionLink,
    this.showTroubleshooting = false,
    required this.onChange,
    required this.requirements,
    this.isConnected,
    this.isStarted,
  });

  @override
  State<ConnectionMethod> createState() => _ConnectionMethodState();
}

class _ConnectionMethodState extends State<ConnectionMethod> with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.requirements.isNotEmpty && !widget.isEnabled) {
      if (state == AppLifecycleState.resumed) {
        Future.wait(widget.requirements.map((e) => e.getStatus())).then((_) {
          final allDone = widget.requirements.every((e) => e.status);

          if (context.mounted) {
            widget.onChange(allDone);
          }
        });
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
    if (widget.requirements.isNotEmpty && widget.isEnabled && widget.isStarted == false) {
      Future.wait(widget.requirements.map((e) => e.getStatus())).then((_) {
        final allDone = widget.requirements.every((e) => e.status);
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
    return SelectableCard(
      onPressed: () {
        if (widget.requirements.isEmpty) {
          widget.onChange(!widget.isEnabled);
        } else {
          Future.wait(widget.requirements.map((e) => e.getStatus())).then((_) async {
            final notDone = widget.requirements.filter((e) => !e.status).toList();
            if (notDone.isEmpty) {
              widget.onChange(!widget.isEnabled);
            } else {
              await openPermissionSheet(context, notDone);
              setState(() {});
            }
          });
        }
      },
      isActive: widget.isEnabled,
      icon: widget.isEnabled ? Icons.check_box : Icons.check_box_outline_blank,
      title: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            spacing: 8,
            children: [
              PrimaryBadge(
                trailing: widget.isStarted == true && (widget.isConnected == false)
                    ? SmallProgressIndicator(
                        color: Theme.of(context).colorScheme.primaryForeground,
                      )
                    : switch (widget.type) {
                        ConnectionMethodType.bluetooth => Icon(Icons.bluetooth),
                        ConnectionMethodType.network => Icon(Icons.wifi),
                        ConnectionMethodType.openBikeControl => Icon(Icons.directions_bike),
                        ConnectionMethodType.local => Icon(Icons.keyboard),
                      },
                child: Text(widget.type.name.capitalize()),
              ),
              if (widget.title == context.i18n.enablePairingProcess ||
                  widget.title == context.i18n.enableZwiftControllerBluetooth)
                Padding(
                  padding: const EdgeInsets.only(top: 1.0),
                  child: BetaPill(),
                ),
            ],
          ),
          Text(widget.title),
          Text(
            widget.description,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
            ),
          ),
          if (widget.isEnabled) ?widget.additionalChild,
          if (widget.instructionLink != null || widget.showTroubleshooting) SizedBox(height: 8),
          if (widget.instructionLink != null)
            OutlineButton(
              leading: Icon(Icons.play_circle_outline_outlined),
              onPressed: () {
                launchUrlString(widget.instructionLink!);
              },
              child: Text(context.i18n.videoInstructions),
            ),
          if (widget.showTroubleshooting)
            OutlineButton(
              leading: Icon(Icons.help_outline),

              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MarkdownPage(assetPath: 'TROUBLESHOOTING.md'),
                  ),
                );
              },
              child: Text(context.i18n.troubleshootingGuide),
            ),
        ],
      ),
    );
  }
}

Future openPermissionSheet(BuildContext context, List<PlatformRequirement> notDone) {
  return openSheet(
    context: context,
    draggable: true,
    builder: (context) => _PermissionList(requirements: notDone),
    position: OverlayPosition.bottom,
  );
}

class _PermissionList extends StatefulWidget {
  final List<PlatformRequirement> requirements;
  const _PermissionList({super.key, required this.requirements});

  @override
  State<_PermissionList> createState() => _PermissionListState();
}

class _PermissionListState extends State<_PermissionList> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.requirements.isNotEmpty) {
      if (state == AppLifecycleState.resumed) {
        Future.wait(widget.requirements.map((e) => e.getStatus())).then((_) {
          final allDone = widget.requirements.every((e) => e.status);
          if (allDone && context.mounted) {
            closeSheet(context);
          } else if (context.mounted) {
            setState(() {});
          }
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      height: 120 + widget.requirements.length * 70,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 18,
        children: [
          Text(
            context.i18n.theFollowingPermissionsRequired,
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ...widget.requirements.map(
            (e) => Row(
              children: [
                Expanded(
                  child: Basic(
                    title: Text(e.name),
                    subtitle: e.description != null ? Text(e.description!) : null,
                    trailing: Button(
                      style: e.status ? ButtonStyle.secondary() : ButtonStyle.primary(),
                      onPressed: e.status
                          ? null
                          : () {
                              e
                                  .call(context, () {
                                    setState(() {});
                                  })
                                  .then((_) {
                                    setState(() {});
                                    if (widget.requirements.all((e) => e.status)) {
                                      closeSheet(context);
                                    }
                                  });
                            },
                      child: e.status ? Text(context.i18n.granted) : Text(context.i18n.grant),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
