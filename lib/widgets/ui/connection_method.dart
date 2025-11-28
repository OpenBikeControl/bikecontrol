import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:swift_control/pages/markdown.dart';
import 'package:swift_control/widgets/ui/small_progress_indicator.dart';
import 'package:url_launcher/url_launcher_string.dart';

class ConnectionMethod extends StatefulWidget {
  final String title;
  final String description;
  final String? instructionLink;
  final bool isConnected;
  final bool isStarted;
  final Function(bool) onChange;

  const ConnectionMethod({
    super.key,
    required this.title,
    required this.description,
    this.instructionLink,
    required this.onChange,
    required this.isConnected,
    required this.isStarted,
  });

  @override
  State<ConnectionMethod> createState() => _ConnectionMethodState();
}

class _ConnectionMethodState extends State<ConnectionMethod> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 16,
      children: [
        Checkbox(
          state: widget.isStarted ? CheckboxState.checked : CheckboxState.unchecked,
          onChanged: (value) {
            widget.onChange(value == CheckboxState.checked);

            setState(() {});
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
                      if (widget.isStarted) ...[
                        Text(
                          widget.isConnected ? "Connected" : "Connecting...",

                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                      if (!widget.isStarted)
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
                if (widget.isStarted) SmallProgressIndicator(),
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
