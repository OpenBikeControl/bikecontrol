import 'package:flutter/material.dart';

class Warning extends StatelessWidget {
  final bool important;
  final List<Widget> children;
  const Warning({super.key, required this.children, this.important = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 6),
      width: double.infinity,
      decoration: BoxDecoration(
        color: important
            ? Theme.of(context).colorScheme.errorContainer
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: children,
      ),
    );
  }
}
