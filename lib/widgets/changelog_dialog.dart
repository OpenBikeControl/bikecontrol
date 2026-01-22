import 'package:bike_control/main.dart';
import 'package:bike_control/utils/i18n_extension.dart';
import 'package:flutter/services.dart';
import 'package:flutter_md/flutter_md.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class ChangelogDialog extends StatelessWidget {
  final Markdown entry;

  const ChangelogDialog({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final latestVersion = Markdown(
      blocks: entry.blocks.skip(1).takeWhile((b) => b.type != 'heading').toList(),
      markdown: entry.markdown,
    );
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.i18n.whatsNew),
          SizedBox(height: 4),
          Text(context.i18n.version(entry.blocks.first.text)).small,
        ],
      ),
      content: Container(
        constraints: BoxConstraints(minWidth: 460, maxHeight: 500),
        child: Scrollbar(
          child: SingleChildScrollView(
            child: MarkdownWidget(
              markdown: latestVersion,
              theme: MarkdownThemeData(
                textStyle: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.i18n.gotIt),
        ),
      ],
    );
  }

  static Future<void> showIfNeeded(BuildContext context, String currentVersion, String? lastSeenVersion) async {
    // Show dialog if this is a new version
    if (lastSeenVersion != currentVersion && lastSeenVersion != null && !screenshotMode) {
      try {
        final entry = await rootBundle.loadString('CHANGELOG.md');
        if (context.mounted) {
          final markdown = Markdown.fromString(entry);
          showDialog(
            context: context,
            useRootNavigator: true,
            routeSettings: RouteSettings(name: '/changelog'),
            builder: (context) => ChangelogDialog(entry: markdown),
          );
        }
      } catch (e) {
        print('Failed to load changelog for dialog: $e');
      }
    }
  }
}
