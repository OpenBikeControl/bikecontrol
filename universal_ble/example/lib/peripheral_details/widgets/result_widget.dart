import 'package:flutter/material.dart';

class ResultWidget extends StatelessWidget {
  final List<String> results;
  final bool scrollable;
  final Function(int? index) onClearTap;
  const ResultWidget({
    required this.results,
    required this.onClearTap,
    this.scrollable = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ListTile(
              tileColor: Theme.of(context).secondaryHeaderColor,
              title: const Text("Logs"),
              onTap: () {
                onClearTap(null);
              },
              trailing: const Icon(Icons.clear),
            ),
          ),
        ListView.separated(
          shrinkWrap: !scrollable,
          physics: scrollable ? null : const NeverScrollableScrollPhysics(),
          itemCount: results.length,
          reverse: true,
          itemBuilder: (BuildContext context, int index) {
            return InkWell(
              onTap: () => onClearTap(index),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 2),
                child: Text(results[index]),
              ),
            );
          },
          separatorBuilder: (_, __) => const Divider(),
        ),
      ],
    );
  }
}
