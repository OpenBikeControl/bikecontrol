import 'package:bike_control/utils/requirements/platform.dart';
import 'package:dartx/dartx.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../utils/i18n_extension.dart';

class PermissionList extends StatefulWidget {
  final List<PlatformRequirement> requirements;
  const PermissionList({super.key, required this.requirements});

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
