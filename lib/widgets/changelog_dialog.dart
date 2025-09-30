import 'package:flutter/material.dart';
import 'package:swift_control/utils/changelog.dart';

class ChangelogDialog extends StatelessWidget {
  final ChangelogEntry entry;

  const ChangelogDialog({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('What\'s New'),
          SizedBox(height: 4),
          Text(
            'Version ${entry.version}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.normal),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children:
              entry.changes
                  .map(
                    (change) => Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(fontSize: 16)),
                        Expanded(child: Text(change, style: Theme.of(context).textTheme.bodyMedium)),
                      ],
                    ),
                  )
                  .toList(),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text('Got it!'))],
    );
  }

  static Future<void> showIfNeeded(BuildContext context, String currentVersion, String? lastSeenVersion) async {
    // Show dialog if this is a new version
    if (lastSeenVersion != currentVersion) {
      try {
        final entry = await ChangelogParser.getLatestEntry();
        if (entry != null && context.mounted) {
          showDialog(context: context, builder: (context) => ChangelogDialog(entry: entry));
        }
      } catch (e) {
        print('Failed to load changelog for dialog: $e');
      }
    }
  }
}
