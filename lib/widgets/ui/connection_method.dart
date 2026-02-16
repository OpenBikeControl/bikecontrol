import 'package:bike_control/gen/l10n.dart';
import 'package:bike_control/pages/button_edit.dart';
import 'package:bike_control/pages/markdown.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:bike_control/utils/keymap/buttons.dart';
import 'package:bike_control/utils/requirements/platform.dart';
import 'package:bike_control/widgets/ui/beta_pill.dart';
import 'package:bike_control/widgets/ui/colored_title.dart';
import 'package:bike_control/widgets/ui/permissions_list.dart';
import 'package:bike_control/widgets/ui/small_progress_indicator.dart';
import 'package:bike_control/widgets/ui/toast.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
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
  final List<InGameAction>? supportedActions;
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
    required this.supportedActions,
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
    if (widget.requirements.isNotEmpty && widget.isEnabled && widget.isStarted == false) {
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
    return SelectableCard(
      onPressed: () {
        if (kIsWeb) {
          buildToast(title: 'Not Supported on Web :)');
        } else if (widget.requirements.isEmpty) {
          widget.onChange(!widget.isEnabled);
        } else {
          Future.wait(widget.requirements.map((e) => e.getStatus())).then((_) async {
            final notDone = widget.requirements.filter((e) => !e.status).toList();
            if (notDone.isEmpty) {
              widget.onChange(!widget.isEnabled);
            } else {
              await openPermissionSheet(context, notDone);
              _recheckRequirements();
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
                    ? SizedBox(
                        width: 19,
                        height: 19,
                        child: SmallProgressIndicator(
                          color: Theme.of(context).colorScheme.primaryForeground,
                        ),
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
          if (widget.isEnabled && widget.additionalChild != null) widget.additionalChild!,
          if (widget.instructionLink != null || widget.showTroubleshooting) SizedBox(height: 8),
          if (widget.instructionLink != null)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Button(
                  style: widget.isEnabled && Theme.of(context).brightness == Brightness.light
                      ? ButtonStyle.outline().withBorder(border: Border.all(color: Colors.gray.shade500))
                      : ButtonStyle.outline(),
                  leading: Icon(
                    widget.instructionLink!.contains("youtube") ? Icons.ondemand_video : Icons.help_outline,
                  ),
                  onPressed: () {
                    if (widget.instructionLink!.contains("youtube")) {
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
