import 'package:dartx/dartx.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/pages/markdown.dart';
import 'package:swift_control/utils/requirements/platform.dart';
import 'package:swift_control/widgets/ui/small_progress_indicator.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ConnectionMethod extends StatefulWidget {
  final String title;
  final String description;
  final String? instructionLink;
  final bool? isConnected;
  final bool? isStarted;
  final List<PlatformRequirement> requirements;
  final Function(bool) onChange;

  const ConnectionMethod({
    super.key,
    required this.title,
    required this.description,
    this.instructionLink,
    required this.onChange,
    required this.requirements,
    this.isConnected,
    this.isStarted,
  });

  @override
  State<ConnectionMethod> createState() => _ConnectionMethodState();
}

class _ConnectionMethodState extends State<ConnectionMethod> {
  bool _isStarted = false;

  @override
  initState() {
    super.initState();
    if (widget.isStarted != null) {
      _isStarted = widget.isStarted!;
    } else if (widget.requirements.isNotEmpty) {
      Future.wait(widget.requirements.map((e) => e.getStatus())).then((_) {
        final allDone = widget.requirements.every((e) => e.status);
        if (allDone) {
          widget.onChange(true);
          setState(() {
            _isStarted = true;
          });
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant ConnectionMethod oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isStarted != widget.isStarted && widget.isStarted != null) {
      _isStarted = widget.isStarted!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        Checkbox(
          state: _isStarted ? CheckboxState.checked : CheckboxState.unchecked,
          onChanged: _isStarted && widget.isStarted == null
              ? null
              : (value) {
                  Future.wait(widget.requirements.map((e) => e.getStatus())).then((_) async {
                    final notDone = widget.requirements.filter((e) => !e.status).toList();
                    if (notDone.isEmpty) {
                      widget.onChange(value == CheckboxState.checked);
                      setState(() {
                        _isStarted = true;
                      });
                    } else {
                      await openPermissionSheet(context, notDone);
                      setState(() {});
                    }
                  });
                },
          trailing: Expanded(
            child: Row(
              spacing: 8,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title),
                      if (_isStarted && widget.isConnected != null)
                        Text(
                          (widget.isConnected ?? false) ? "Connected" : "Connecting...",

                          style: TextStyle(fontSize: 12),
                        )
                      else
                        Text(
                          widget.description,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                    ],
                  ),
                ),
                if (_isStarted && (widget.isConnected ?? false)) SmallProgressIndicator(),
              ],
            ),
          ),
        ),
        if (widget.instructionLink != null)
          OutlineButton(
            leading: Icon(Icons.play_circle_outline_outlined),
            onPressed: () {
              launchUrlString(widget.instructionLink!);
            },
            child: Text('Video Instructions'),
          ),
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
          child: Text('Troubleshooting Guide'),
        ),
      ],
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
            'Please complete the following requirements before enabling this connection method:',
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
                      child: e.status ? Text('Granted') : Text('Grant'),
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
