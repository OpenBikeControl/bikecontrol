import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_md/flutter_md.dart';

class ChangelogDialog extends StatelessWidget {
  final Markdown entry;

  const ChangelogDialog({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final latestVersion = Markdown(blocks: entry.blocks.skip(1).take(2).toList(), markdown: entry.markdown);
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('What\'s New'),
          SizedBox(height: 4),
          Text(
            'Version ${entry.blocks.first.text}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.normal),
          ),
        ],
      ),
      content: Container(constraints: BoxConstraints(minWidth: 460), child: MarkdownWidget(markdown: latestVersion)),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Got it!'))],
    );
  }

  static Future<void> showIfNeeded(BuildContext context, String currentVersion, String? lastSeenVersion) async {
    // Show dialog if this is a new version
    if (lastSeenVersion != currentVersion) {
      try {
        final entry = await rootBundle.loadString('CHANGELOG.md');
        if (context.mounted) {
          final markdown = Markdown.fromString(entry);
          showDialog(context: context, builder: (context) => ChangelogDialog(entry: markdown));
        }
      } catch (e) {
        print('Failed to load changelog for dialog: $e');
      }
    }
  }
}
