import 'package:shadcn_flutter/shadcn_flutter.dart';

class Warning extends StatelessWidget {
  final bool important;
  final List<Widget> children;
  const Warning({super.key, required this.children, this.important = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (important
            ? Theme.of(context).colorScheme.destructive.withAlpha(30)
            : Theme.of(context).colorScheme.secondary.withAlpha(80)),
        border: Border.all(
          color: important ? Theme.of(context).colorScheme.destructive : Theme.of(context).colorScheme.secondary,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          if (important)
            Icon(
              Icons.warning_amber_rounded,
              color: Theme.of(context).colorScheme.destructive,
            ),
          Expanded(
            child: Column(
              spacing: 8,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
