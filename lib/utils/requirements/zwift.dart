import 'package:flutter/material.dart' hide ConnectionState;
import 'package:swift_control/bluetooth/devices/zwift/zwift_emulator.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/pages/markdown.dart';
import 'package:swift_control/utils/requirements/platform.dart';
import 'package:swift_control/widgets/small_progress_indicator.dart';

class ZwiftRequirement extends PlatformRequirement {
  ZwiftRequirement()
    : super(
        'Pair SwiftControl with Zwift',
      );

  @override
  Future<void> call(BuildContext context, VoidCallback onUpdate) async {}

  @override
  Widget? buildDescription() {
    return settings.getLastTarget() == null
        ? null
        : Text(
            'In Zwift on your ${settings.getLastTarget()?.title} go into the Pairing settings and select SwiftControl from the list of available controllers.',
          );
  }

  @override
  Widget? build(BuildContext context, VoidCallback onUpdate) {
    return _PairWidget(onUpdate: onUpdate, requirement: this);
  }

  @override
  Future<void> getStatus() async {
    status = zwiftEmulator.isConnected.value || screenshotMode;
  }
}

class _PairWidget extends StatefulWidget {
  final ZwiftRequirement requirement;
  final VoidCallback onUpdate;
  const _PairWidget({super.key, required this.onUpdate, required this.requirement});

  @override
  State<_PairWidget> createState() => _PairWidgetState();
}

class _PairWidgetState extends State<_PairWidget> {
  @override
  void initState() {
    super.initState();
    // after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      toggle().catchError((e) {
        print('Error starting advertising: $e');
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 10,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          spacing: 10,
          children: [
            ElevatedButton(
              onPressed: () async {
                try {
                  await toggle();
                } catch (e) {
                  print('Error toggling advertising: $e');
                }
              },
              child: Text(zwiftEmulator.isAdvertising ? 'Stop Pairing' : 'Start Pairing'),
            ),
            if (zwiftEmulator.isAdvertising || zwiftEmulator.isLoading)
              SizedBox(height: 20, width: 20, child: SmallProgressIndicator()),
          ],
        ),
        if (zwiftEmulator.isAdvertising) ...[
          TextButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => MarkdownPage(assetPath: 'TROUBLESHOOTING.md')));
            },
            child: Text('Check the troubleshooting guide'),
          ),
        ],
      ],
    );
  }

  Future<void> toggle() async {
    if (zwiftEmulator.isAdvertising) {
      await zwiftEmulator.stopAdvertising();
      widget.onUpdate();
      setState(() {});
    } else {
      await zwiftEmulator.startAdvertising(widget.onUpdate);
      if (mounted) setState(() {});
    }
  }
}
