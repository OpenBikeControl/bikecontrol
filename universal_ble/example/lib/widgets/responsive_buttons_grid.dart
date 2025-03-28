import 'package:flutter/material.dart';

class ResponsiveButtonsGrid extends StatelessWidget {
  final List<Widget> children;
  const ResponsiveButtonsGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const tileWidth = 150;
        const tileHeight = 500;
        final count = constraints.maxWidth ~/ tileWidth;
        return GridView.count(
          crossAxisCount: count,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: tileHeight / tileWidth,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: children,
        );
      },
    );
  }
}
