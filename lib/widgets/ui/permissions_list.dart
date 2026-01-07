import 'dart:io';

import 'package:bike_control/utils/requirements/android.dart';
import 'package:bike_control/utils/requirements/platform.dart';
import 'package:dartx/dartx.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../utils/i18n_extension.dart';

class PermissionList extends StatefulWidget {
  final VoidCallback onDone;
  final List<PlatformRequirement> requirements;
  const PermissionList({super.key, required this.requirements, required this.onDone});

  @override
  State<PermissionList> createState() => _PermissionListState();
}

class _PermissionListState extends State<PermissionList> with WidgetsBindingObserver {
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
          if (allDone && mounted) {
            closeSheet(context);
          } else if (mounted) {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: 18,
      children: [
        SizedBox(),
        Center(
          child: Text(
            context.i18n.theFollowingPermissionsRequired,
            textAlign: TextAlign.center,
          ).muted.small,
        ),
        ...widget.requirements.map(
          (e) {
            final onPressed = e.status
                ? null
                : () {
                    e
                        .call(context, () {
                          setState(() {});
                        })
                        .then((_) {
                          setState(() {});
                          if (widget.requirements.all((e) => e.status)) {
                            widget.onDone();
                          }
                        });
                  };
            final optional = e is NotificationRequirement && (Platform.isMacOS || Platform.isIOS);
            return SizedBox(
              width: double.infinity,
              child: Button(
                onPressed: onPressed,
                style: ButtonStyle.card().withBackgroundColor(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Theme.of(context).colorScheme.card
                      : Theme.of(context).colorScheme.card.withLuminance(0.95),
                ),
                child: Basic(
                  leading: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).colorScheme.primaryForeground,
                    ),
                    padding: EdgeInsets.all(8),
                    child: Icon(e.icon),
                  ),
                  title: Row(
                    spacing: 8,
                    children: [
                      Expanded(child: Text(e.name)),
                      Button(
                        style: e.status
                            ? ButtonStyle.secondary(size: ButtonSize.small)
                            : ButtonStyle.primary(size: ButtonSize.small),
                        onPressed: onPressed,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            e.status ? Text(context.i18n.granted) : Text(context.i18n.grant),
                            if (optional) Text('Optional', style: TextStyle(fontSize: 10)).muted,
                          ],
                        ),
                      ),
                    ],
                  ),
                  subtitle: e.description != null ? Text(e.description!) : null,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
