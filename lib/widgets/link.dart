import 'package:flutter/material.dart';
import 'package:swift_control/main.dart';
import 'package:swift_control/pages/markdown.dart';
import 'package:swift_control/widgets/small_progress_indicator.dart';

class LinkWidget extends StatefulWidget {
  final VoidCallback onUpdate;
  const LinkWidget({super.key, required this.onUpdate});

  @override
  State<LinkWidget> createState() => _LinkWidgetState();
}

class _LinkWidgetState extends State<LinkWidget> {
  @override
  void initState() {
    super.initState();
    whooshLink.startServer();
    whooshLink.isConnected.addListener(() {
      widget.onUpdate();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        ValueListenableBuilder(
          valueListenable: whooshLink.isStarted,
          builder: (BuildContext context, value, Widget? child) {
            return Row(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: value
                      ? null
                      : () async {
                          await whooshLink.startServer();
                        },
                  child: Text(value ? 'Waiting for MyWhoosh...' : 'Start Listening for MyWhoosh'),
                ),
                if (value) SmallProgressIndicator(),
              ],
            );
          },
        ),
        Text('Verify with the MyWhoosh Link app if connection is possible.'),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (c) => MarkdownPage(assetPath: 'TROUBLESHOOTING.md')),
            );
          },
          child: const Text("Show Troubleshooting Guide"),
        ),
      ],
    );
  }
}
