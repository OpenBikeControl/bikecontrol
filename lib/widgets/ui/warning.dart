import 'package:shadcn_flutter/shadcn_flutter.dart';

class Warning extends StatelessWidget {
  final bool important;
  final List<Widget> children;
  const Warning({super.key, required this.children, this.important = true});

  @override
  Widget build(BuildContext context) {
    return Card(
      filled: true,
      fillColor: important ? Theme.of(context).colorScheme.destructive : Theme.of(context).colorScheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: children.map((e) => e.small).toList(),
      ),
    );
  }
}
